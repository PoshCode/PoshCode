# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Installation" # Just the Copy-Stream function
#!Requires -Version 2 -Modules "Metadata" 
###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Packaging.psm1 defines the core Compress-Module command for creating Module packages:
## Install-Module and Expand-ZipFile and Expand-Package
## It depends on the Installation module for the Copy-Stream function
## It depends on the ModuleInfo module for the Get-ModuleInfo command


# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1
# FULL # END FULL

function Compress-Module {
    #.Synopsis
    #   Create a new package for a module
    #.Description
    #   Create a module package based on a .psd1 metadata module. 
    #.Notes
    #   If the FileList is set in the psd1, only those files are packed
    #   If present, a ${Module}.png image will be used as a thumbnail
    #   HelpInfoUri will be parsed for urls
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium", DefaultParameterSetName="SimplePackage")]
    param(
        # The name of the module to package
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({if($_ -is [array]) { throw "Compress-Module can only handle one module at a time. If you want to compress more than one, please pipe them in (see examples in help)."} else { return $true }})]
        $Module,
      
      
        # If set, Compress-Module will first call Set-ModuleManifest with -IncrementVersionNumber to bump the version number
        [Parameter(ParameterSetName="AutomaticVersionNumber", Mandatory=$true)]
        [switch]$IncrementVersionNumber,
      
        # If set, Compress-Module will also call Set-ModuleManifest to update the version number
        [Parameter(ParameterSetName="ManualVersionNumber", Mandatory=$true)]
        [Alias("Version")]
        [Version]$ModuleVersion,

        # Release notes for this specific version
        [Parameter(Position=1)]
        [String]${ReleaseNotes},

        # The folder where packages should be placed (defaults to the current FileSystem working directory)
        [Parameter()]
        [string]$OutputPath = $(Get-Location -PSProvider FileSystem),

        # Choose one category from the list.
        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData category
        [ValidateSet("Active Directory", "Applications", "App-V", "Backup and System Restore", "Databases", "Desktop Management", "Exchange", "Group Policy", "Hardware", "Interoperability and Migration", "Local Account Management", "Logs and monitoring", "Lync", "Messaging & Communication", "Microsoft Dynamics", "Multimedia", "Networking", "Office", "Office 365", "Operating System", "Other Directory Services", "Printing", "Remote Desktop Services", "Scripting Techniques", "Security", "Servers", "SharePoint", "Storage", "System Center", "UE-V", "Using the Internet", "Windows Azure", "Windows Update")]
        [String]$Category,

        # a URL or relative path to an icon for the module in gif/jpg/png form
        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData IconUrl
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$IconUrl,

        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData flag
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$IsPrerelease,

        # The url to a license
        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData licenseUrl
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$LicenseUrl,

        # a URL or relative path to a web page about this module
        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData projectUrl
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$ProjectUrl,
      
        # TODO: If set, require the license to be accepted during installation (not supported yet)
        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData flag
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$RequireLicenseAcceptance,

        # An array of keyword tags for search
        # If set, Compress-Module will also call Set-ModuleManifest to update the Private PSData tags
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String[]]$Tags,

        # If set, overwrite existing packages without prompting
        [switch]$Force
    )
    begin {
        # If Module isn't set in Begin, we'll get it from the pipeline (or fail)
        $Piped = !$PsBoundParameters.ContainsKey("Module")
      
        $RejectAllOverwrite = $false;
        $ConfirmAllOverwrite = $false;

        function GetModuleOrElse {
            param([String]$Name,[Switch]$Force,[Switch]$Verbose,[hashtable]$ListAvailable)
            if(!$ListAvailable.ListAvailable) {
                if($result = Get-ModuleInfo $Name -Force) { return $result }
            }
            
            if($result = Get-ModuleInfo $Name -Force:$Force -ListAvailable) {
                $ListAvailable.ListAvailable = $true 
                return $result
            }
        }
    }
    process {
        Write-Verbose "Compress-Module $Module to $OutputPath"
        $ListAvailable = @{ListAvailable=$false}

        if($Module -isnot [System.Management.Automation.PSModuleInfo]) {
            # Hypothetically, could it be faster to select -first, now that pipelines are interruptable?
            [String]$ModuleName = $Module
            ## Workaround PowerShell Bug https://connect.microsoft.com/PowerShell/feedback/details/802030
            Push-Location $Script:EmptyPath
            $ModuleList = @(Get-Module $ModuleName)
            if($ModuleList.Length -eq 0) {
                $ModuleList = @(Get-Module $ModuleName -ListAvailable)
            }
            if($ModuleList.Length -gt 1) {
                $PSCmdlet.ThrowTerminatingError(
                 (New-Object System.Management.Automation.ErrorRecord (
                    New-Object System.ArgumentException "Multiple modules with the name '$ModuleName' are available. Try again specifying a full path, or import the version you want to compress first.", "Module"),
                        "AmbiguousModuleNameToPublish", "InvalidArgument", $ModuleName) )
            } elseif($ModuleList.Length -eq 0) {
                $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (
                    New-Object System.ArgumentException "Module not found ($($PsBoundParameters["Module"]))", "Module"), 
                        "ModuleNotAvailableLocallyToPublish", "InvalidArgument", $ModuleInfo) )
            }

            if($PSVersionTable.PSVersion -lt "3.0") {
                $ModuleInfo = Import-Module $ModuleName -Global -PassThru | Get-ModuleInfo -Force
            } else {
                $ModuleInfo = GetModuleOrElse $ModuleName -ListAvailable $ListAvailable 
            }
            Pop-Location
        }
        $PackageName = $ModuleInfo.Name

        # If there's no module manifest, we'll need to create one ..
        $ModuleInfoPath = Join-Path $ModuleInfo.ModuleBase ($PackageName + $ModuleManifestExtension)

        $ManifestProperties = "IncrementVersionNumber", "ModuleVersion", "Category", "IconUrl", "IsPrerelease", "LicenseUrl", "ProjectUrl", "RequireLicenseAcceptance", "Tags"
        $ManifestParameters = @{} + $PSBoundParameters
        foreach($key in $($ManifestParameters.Keys | Where { $ManifestProperties -notcontains $_ })) {
            $ManifestParameters.Remove($key)
        }
        $ManifestParameters.Name = $PackageName
        $ManifestMissing = !(Test-Path $ModuleInfoPath)
        if($ManifestMissing -or $ManifestParameters.Count -gt 1) 
        {
            Write-Verbose "Updating Manifest with $($ManifestParameters.Keys -join ',')"
            Set-ModuleManifest @ManifestParameters
            $ModuleInfo = GetModuleOrElse $PackageName -ListAvailable $ListAvailable -Force
            if($ManifestMissing -and (Test-Path $ModuleInfoPath)) { 
                Write-Warning "Generated $ModuleInfoPath in $PackageName"
            }
        }

        Test-ModuleManifest $ModuleInfoPath

        Write-Debug "$($ModuleInfo  | % { $_.FileList } | Out-String)"
        Write-Progress -Activity "Packaging Module '$($ModuleInfo.Name)'" -Status "Validating Inputs" -Id 0    

        # If the Module.Path isn't a PSD1, then there is none, so we will refuse to package this module
        if( $ModuleInfo -isnot [System.Management.Automation.PSModuleInfo] -and [IO.Path]::GetExtension($ModuleInfo.Path) -ne ".psd1" ) {
            $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.InvalidDataException "Module metadata file (${ModuleManifestExtension}) not found for $($PsBoundParameters["Module"])"), "Unexpected Exception", "InvalidResult", $_) )
        }

        # Our packages are ModuleName.nupkg (for now, $ModulePackageExtension = .nupkg)
        if($ModuleInfo.Version -gt "0.0") {
            $PackageVersion = $ModuleInfo.Version
        } else {
            Write-Warning "Module Version not specified properly, using 1.0"
            $PackageVersion = "1.0"
        }
   
        if($OutputPath.EndsWith($ModulePackageExtension)) {
            Write-Verbose "Specified OutputPath include the Module name (ends with $ModulePackageExtension)"
            $OutputPath = Split-Path $OutputPath
        }

        if(Test-Path $OutputPath -ErrorAction Stop) {
            $OutputPackagePath = Join-Path $OutputPath "${PackageName}.${PackageVersion}${ModulePackageExtension}"
            #$OutputPackageFeedPath = Join-Path $OutputPath "${PackageName}.xml"
        } else {
            throw "Specified OutputPath doesn't exist: $OutputPath"
        }

        Write-Verbose "Packing Module to: $OutputPath"
        Write-Verbose "Package File Path: $OutputPackagePath"
        # Write-Verbose "Package Feed : $OutputPackageFeedPath"

        if($PSCmdlet.ShouldProcess("Package the module '$($ModuleInfo.ModuleBase)' to '$OutputPackagePath'", "Package '$($ModuleInfo.ModuleBase)' to '$OutputPackagePath'?", "Packaging $($ModuleInfo.Name)" )) {
            if($Force -Or !(Test-Path $OutputPackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$OutputPackagePath' already exists, do you want to replace it?", "Packaging $($ModuleInfo.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

            #### TODO: We should generate the feed XML ...
            #Get-Item $OutputPackageFeedPath

            Write-Progress -Activity "Packaging Module '$($ModuleInfo.Name)'" -Status "Preparing File List" -Id 0    
            
            [String[]]$FileList = Get-ChildItem $ModuleInfo.ModuleBase -Recurse | 
                Where-Object {-not $_.PSIsContainer} | 
                Select-Object -Expand FullName

            # Warn about discrepacies between the Module.FileList and actual files
            $ModuleFileList = @($ModuleInfo.FileList)
            Write-Verbose "`nFILELIST: $FileList  `n`nMODULELIST: $ModuleFileList"
            # $ModuleInfo.FileList | Resolve-Path 
            if($ModuleFileList.Length -gt 0) {
                foreach($mf in $ModuleFileList){
                    if($FileList -notcontains $mf) {
                        Write-Warning "Missing File (specified in Module FileList): $mf"
                    }
                }
                foreach($f in $FileList){
                    if($ModuleFileList -notcontains $f) {
                        if($f -like "*\${PackageName}${PackageInfoExtension}") {
                            Write-Warning "Manifest not specified in Module FileList (but included anyway): $f"
                            $ModuleFileList += $f
                        } else {
                            Write-Warning "File in module folder not specified in Module FileList: $f"
                        }
                    }
                }
                # Now that we've warned you about missing files, let's not try to pack them:
                $FileList = Get-ChildItem $ModuleFileList | 
                    Where-Object {-not $_.PSIsContainer} | 
                    Select-Object -Expand FullName -Unique
                if(($FileList -notcontains $ModuleInfoPath) -and (Test-Path $ModuleInfoPath)) {
                    $FileList += $ModuleInfoPath
                }
            } else {
                Write-Warning "FileList not set in module metadata (${ModuleManifestExtension}) file. Packing all files from path: $($ModuleInfo.ModuleBase)"
            }

            # Create the package
            $Package = [System.IO.Packaging.Package]::Open( $OutputPackagePath, [IO.FileMode]::Create )

            try {
                if($ReleaseNotes) {
                    $ModuleInfo.PrivateData.$PackageDataKey.ReleaseNotes = $ReleaseNotes
                }
                Set-PackageProperties $Package $ModuleInfo

                # Now pack up all the files we've found:
                $Target = $FileList.Count
                $Count = 0
                foreach($file in $FileList) {
                    $Count += 1
                    Write-Progress -Activity "Packaging Module '$($ModuleInfo.Name)'" -Status "Packing File $Count of $Target" -Id 0 -PercentComplete ((($count-1)/$target)*100)
                    AddFile $Package $File $ModuleInfo.ModuleBase
                }

                if($ModuleInfo.HelpInfoUri) {
                    $null = $Package.CreateRelationship( $ModuleInfo.HelpInfoUri, "External", $ModuleHelpInfoType )
                }
                if($ModuleInfo.PackageInfoUrl) {
                    $null = $Package.CreateRelationship( $ModuleInfo.PackageInfoUrl, "External", $PackageInfoType )
                }
                if($ModuleInfo.LicenseUrl) {
                    $null = $Package.CreateRelationship( $ModuleInfo.LicenseUrl, "External", $ModuleLicenseType )
                }
                if($ModuleInfo.DownloadUrl) {
                    $null = $Package.CreateRelationship( $ModuleInfo.DownloadUrl, "External", $PackageDownloadType )
                }
                if($ModuleInfo.ProjectUrl) {
                    $null = $Package.CreateRelationship( $ModuleInfo.ProjectUrl, "External", $ModuleProjectType )
                }

               

            } catch [Exception] {
                $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
                if($Package) { 
                    Write-Progress -Activity "Packaging Module '$($ModuleInfo.Name)'" -Status "Writing Package" -Id 0            
                    $Package.Close()
                }
            }

            Write-Progress -Activity "Packaging Module '$($ModuleInfo.Name)'" -Status "Complete" -Id 0 -Complete

            # Write out the FileInfo for the package
            Get-Item $OutputPackagePath

            }
        }
   }
}

function AddFile {
   [CmdletBinding(DefaultParameterSetName="FilePath")]
   param(
      [Parameter(Mandatory=$true, Position=1)]
      $Package,

      [Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath")]
      $Path,

      [Parameter(Mandatory=$true, Position=3)]
      $ModuleBase = $ModuleInfo.ModuleBase,

      [Parameter(ParameterSetName="FakeFile",Mandatory=$true)]
      $Content
   )
   begin {
      $ModuleRootRex = $([regex]::Escape($ModuleBase))
      $PackageName = $Package.PackageProperties.Title
      $MetadataName = "${PackageName}${ModuleManifestExtension}"
   }
   process {
      $FileRelativePath = $Path -replace $ModuleRootRex, ""
      try {
          $FileUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( $FileRelativePath )
      } catch {
          $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.FileNotFoundException "Can't create Part URI '${Path}' relative to '$ModuleBase'"), "Unexpected Exception", "InvalidResult", $_) )
      }

      Write-Verbose "Packing $Path to ${PackageName}$ModulePackageExtension::$FileUri"

      # TODO: add MimeTypes for specific powershell types (would let us extract just one type of file)
      switch -regex ([IO.Path]::GetExtension($Path)) {
         "\.(?:psd1|psm1|ps1|cs|txt|md|nuspec|packageInfo)" {
            # Add a text file part to the Package ( [System.Net.Mime.MediaTypeNames+Text]::Xml )
            $part = $Package.CreatePart( $FileUri, "text/plain", "Maximum" ); 
            Write-Verbose "    as text/plain"
            break;
         }
         "\.ps1xml|\.xml" {
            $part = $Package.CreatePart( $FileUri, "text/xml", "Maximum" ); 
            Write-Verbose "    as text/xml"
            break
         } 
         "\.xaml" {
            $part = $Package.CreatePart( $FileUri, "text/xaml", "Maximum" ); 
            Write-Verbose "    as text/xaml"
            break
         } 
         default {
            $part = $Package.CreatePart( $FileUri, "application/octet-stream", "Maximum" ); 
            Write-Verbose "    as application/octet-stream"
         }
      }

      # Copy the data to the Document Part 
      try {
         if($Content) {
            $reader = New-Object System.IO.MemoryStream (,[Text.Encoding]::UTF8.GetBytes($Content))
         } else {
            $reader = [IO.File]::Open($Path, "Open", "Read", "Read")
         }
         $writer = $part.GetStream()
         Copy-Stream $reader $writer -Length $reader.Length -Activity "Packing $Path"
      } catch [Exception]{
         $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
      } finally {
         if($writer) {
            $writer.Close()
         }
         if($reader) {
            $reader.Close()
         }
      }


      # Add a Package Relationship to the Document Part
      switch -regex ($Path) {
         ([regex]::Escape($PackageName + $NuSpecManifestExtension) + '$') {
            $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ManifestType)
            Write-Verbose "    Added Relationship: ManifestType - $ManifestType"
            break
         }

         #([regex]::Escape($PackageName + $PackageInfoExtension) + '$') {
         #   $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $PackageMetadataType)
         #   Write-Verbose "    Added Relationship: PackageMetadata - $PackageMetadataType"
         #   break
         #}

         ([regex]::Escape($MetadataName) + '$') {
            $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleMetadataType)
            Write-Verbose "    Added Relationship: ModuleMetadata - $ModuleMetadataType"
            break
         } 

         ([regex]::Escape($PackageName + "\.(png|gif|jpg)") + '$') {
            $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $PackageThumbnailType)
            Write-Verbose "    Added Relationship: PackageThumbnail - $PackageThumbnailType"
            break
         }
      }
   }
}

# internal function for setting the PackageProperties of a package file
function Set-PackageProperties {
  #.Synopsis
  #   Sets PackageProperties from a PSModuleInfo
  param(
    # The PackageProperties object to set
    [Parameter(Mandatory=$true, Position=0)]
    $Package,

    # The ModuleInfo to get values from
    [Parameter(Mandatory=$true, Position=1)]
    $ModuleInfo
  )
  process {
    $PrivatePackageProperties = $Package.PackageProperties

    $PackageData = @{} + $ModuleInfo.PrivateData
    $PackageData = @{} + $PackageData.$PackageDataKey
    # Sanity check: you can't require license acceptance unless you specify the license...
    if(!$PackageData.LicenseUrl) {
        $PackageData.RequireLicenseAcceptance = $false 
    }

    AddFile -Package $Package -Path ($ModuleInfo.Name + $NuSpecManifestExtension) -ModuleBase $ModuleInfo.ModuleBase -Content ($ModuleInfo | ConvertTo-Nuspec)

    ## NuGet does the WRONG thing here, assuming the package name is unique
    ## And  pretending there's only one repo, and no need for unique identifiers
    #$PrivatePackageProperties.Identifier = $ModuleInfo.GUID
    $PrivatePackageProperties.Title = $ModuleInfo.Name
    $PrivatePackageProperties.Identifier = $ModuleInfo.Name

    $PrivatePackageProperties.Version = $ModuleInfo.Version
    $PrivatePackageProperties.Creator = $ModuleInfo.Author
    $PrivatePackageProperties.Description = $ModuleInfo.Description
    $PrivatePackageProperties.ContentStatus = "PowerShell " + $ModuleInfo.PowerShellVersion
    $PrivatePackageProperties.Created = Get-Date
    $PrivatePackageProperties.LastModifiedBy = $UserAgent
    $PrivatePackageProperties.Category = $PackageData.Category

    $PrivatePackageProperties.Keywords = if(!$PackageData.Tags) { $ModulePackageKeyword -join ' ' } else { @($PackageData.Tags) -join ' ' }
    if($PackageData.ProjectUrl) {
        $PrivatePackageProperties.Subject = $PackageData.ProjectUrl
    } elseif($ModuleInfo.HelpInfoUri) { 
        $PrivatePackageProperties.Subject = $ModuleInfo.HelpInfoUri 
    }
  }
}

