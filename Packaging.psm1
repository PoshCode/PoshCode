# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Installation" # Just the Copy-Stream function
#!Requires -Version 2 -Modules "ModuleInfo" 
###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Packaging.psm1 defines the core Compress-Module command for creating Module packages:
## Install-Module and Expand-ZipFile and Expand-Package
## It depends on the Installation module for the Copy-Stream function
## It depends on the ModuleInfo module for the Update-ModuleInfo command


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
   [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
   param(
      # The name of the module to package
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $Module,
      
      # The folder where packages should be placed (defaults to the current FileSystem working directory)
      [Parameter()]
      [string]$OutputPath = $(Get-Location -PSProvider FileSystem),
      
      # If set, overwrite existing packages without prompting
      [switch]$Force
   )
   begin {
      # If Module isn't set in Begin, we'll get it from the pipeline (or fail)
      $Piped = !$PsBoundParameters.ContainsKey("Module")
      
      $RejectAllOverwrite = $false;
      $ConfirmAllOverwrite = $false;
   }
   process {
      Write-Verbose "Compress-Module $Module to $OutputPath"
      if($Module -isnot [System.Management.Automation.PSModuleInfo]) {
         # Hypothetically, could it be faster to select -first, now that pipelines are interruptable?
         [String]$ModuleName = $Module
         ## Workaround PowerShell Bug https://connect.microsoft.com/PowerShell/feedback/details/802030
         Push-Location $Script:EmptyPath
         if($PSVersionTable.PSVersion -lt "3.0") {
            $Module = Import-Module $ModuleName -PassThru  | Update-ModuleInfo
         } else {
            if(Get-Module $ModuleName) {
               $Module = Get-Module $ModuleName
            } else {   
               $Module = Get-Module $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            }
            Write-Verbose "$($Module  | % FileList | Out-String)"
            $Module = $Module | Update-ModuleInfo
         }

         Pop-Location
      }
      Write-Verbose "$($Module  | % { $_.FileList } | Out-String)"
      Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Validating Inputs" -Id 0    

      # If the Module.Path isn't a PSD1, then there is none, so we will refuse to package this module
      if( $Module -isnot [System.Management.Automation.PSModuleInfo] -and [IO.Path]::GetExtension($Module.Path) -ne ".psd1" ) {
         $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.InvalidDataException "Module metadata file (${ModuleManifestExtension}) not found for $($PsBoundParameters["Module"])"), "Unexpected Exception", "InvalidResult", $_) )
      }

      # Our packages are ModuleName.nupkg (for now, $ModulePackageExtension = .nupkg)
      $PackageName = $Module.Name
      if($Module.Version -gt "0.0") {
         $PackageVersion = $Module.Version
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
         $OutputPackageInfoPath = Join-Path $OutputPath "${PackageName}${PackageInfoExtension}"
      }

      Write-Verbose "Creating Module in $OutputPath"
      Write-Verbose "Package File Path: $OutputPackagePath"
      Write-Verbose "Package Manifest : $OutputPackageInfoPath"

      if($PSCmdlet.ShouldProcess("Package the module '$($Module.ModuleBase)' to '$OutputPackagePath'", "Package '$($Module.ModuleBase)' to '$OutputPackagePath'?", "Packaging $($Module.Name)" )) {
         if($Force -Or !(Test-Path $OutputPackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$OutputPackagePath' already exists, do you want to replace it?", "Packaging $($Module.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

            # If there's no packageInfo file, we ought *create* one with urls in it -- but we don't know the URLs
            $packageInfoPath = Join-Path (Split-Path $Module.Path) ($PackageName + $PackageInfoExtension)
            $NuSpecPath = Join-Path (Split-Path $Module.Path) ($PackageName + $NuSpecManifestExtension)
            $ModuleInfoPath = Join-Path (Split-Path $Module.Path) ($PackageName + $ModuleManifestExtension)

            if(!(Test-Path $packageInfoPath) -and !(Test-Path $NuSpecPath))
            {
               $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.FileNotFoundException "Can't find the a package manifest: ${PackageInfoExtension} or ${NuSpecManifestExtension}"), "Manifest Not Found", "ObjectNotFound", $_) )
            } else {
               Copy-Item $packageInfoPath $OutputPackageInfoPath -ErrorVariable CantWrite
               if($CantWrite) {
                  $PSCmdlet.ThrowTerminatingError( $CantWrite[0] )
               }
            }
            Get-Item $OutputPackageInfoPath

            Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Preparing File List" -Id 0    
            
            [String[]]$FileList = Get-ChildItem $Module.ModuleBase -Recurse | 
               Where-Object {-not $_.PSIsContainer} | 
               Select-Object -Expand FullName

            # Warn about discrepacies between the Module.FileList and actual files
            # $Module.FileList | Resolve-Path 
            if($Module.FileList.Count -gt 0) {
               foreach($mf in $Module.FileList){
                  if($FileList -notcontains $mf) {
                     Write-Warning "Missing File (specified in Module FileList): $mf"
                  }
               }
               foreach($f in $FileList){
                  if($Module.FileList -notcontains $mf) {
                     Write-Warning "File in module folder not specified in Module FileList: $mf"
                  }
               }
               # Now that we've warned you about missing files, let's not try to pack them:
               $FileList = Get-ChildItem $Module.FileList | 
                  Where-Object {-not $_.PSIsContainer} | 
                  Select-Object -Expand FullName
               if(($FileList -notcontains $ModuleInfoPath) -and (Test-Path $ModuleInfoPath)) {
                  $FileList += $ModuleInfoPath
               }

            } else {
               Write-Warning "FileList not set in module metadata (${ModuleManifestExtension}) file. Packing all files from path: $($Module.ModuleBase)"
            }

            # Create the package
            $Package = [System.IO.Packaging.Package]::Open( $OutputPackagePath, [IO.FileMode]::Create )
            Set-PackageProperties $Package $Module

            try {
               # Now pack up all the files we've found:
               $Target = $FileList.Count
               $Count = 0
               foreach($file in $FileList) {
                  $Count += 1
                  Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Packing File $Count of $Target" -Id 0 -PercentComplete ((($count-1)/$target)*100)
                  Add-File $Package $File
               }

               if($Module.HelpInfoUri) {
                  $null = $Package.CreateRelationship( $Module.HelpInfoUri, "External", $ModuleHelpInfoType )
               }
               if($Module.PackageInfoUri) {
                  $null = $Package.CreateRelationship( $Module.PackageInfoUri, "External", $PackageInfoType )
               }
               if($Module.LicenseUri) {
                  $null = $Package.CreateRelationship( $Module.LicenseUri, "External", $ModuleLicenseType )
               }
               if($Module.DownloadUri) {
                  $null = $Package.CreateRelationship( $Module.DownloadUri, "External", $PackageDownloadType )
               }
               if($Module.ModuleInfoUri) {
                  $null = $Package.CreateRelationship( $Module.ModuleInfoUri, "External", $ModuleProjectType )
               }

               

            } catch [Exception] {
               $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
               if($Package) { 
                  Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Writing Package" -Id 0            
                  $Package.Close()
               }
            }

            Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Complete" -Id 0 -Complete

            # Write out the FileInfo for the package
            Get-Item $OutputPackagePath

            # TODO: once the URLs are mandatory, print the full URL here
            Write-Host "You should now copy the $PackageInfoExtension and $ModulePackageExtension files to the locations specified by the PackageInfoUri and DownloadUri"  
         }
      }
   }
}


function Add-File {
   [CmdletBinding(DefaultParameterSetName="FilePath")]
   param(
      [Parameter(Mandatory=$true, Position=1)]
      $Package,

      [Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath")]
      $Path,

      [Parameter(ParameterSetName="FakeFile",Mandatory=$true)]
      $Content
   )
   begin {
      $ModuleRootRex = [regex]::Escape($Module.ModuleBase)
      $PackageName = $Package.PackageProperties.Title
      $MetadataName = "${PackageName}${ModuleManifestExtension}"
   }
   process {
      $FileRelativePath = $Path -replace $ModuleRootRex, ""
      $FileUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( $FileRelativePath )

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

         ([regex]::Escape($PackageName + $PackageInfoExtension) + '$') {
            $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $PackageMetadataType)
            Write-Verbose "    Added Relationship: PackageMetadata - $PackageMetadataType"
            break
         }

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
    $PackageProperties = $Package.PackageProperties

    # Sanity check: you can't require license acceptance unless you specify the license...
    if(!$ModuleInfo.LicenseUri) {
       Add-Member NoteProperty -InputObject $ModuleInfo -Name RequireLicenseAcceptance -Value $false 
    }

    $NuSpecF = Join-Path $ModuleInfo.ModuleBase ($ModuleInfo.Name + $NuSpecManifestExtension)
    if(Test-Path $NuSpecF) {
       Set-Content $NuSpecF -Value ($ModuleInfo | Get-NuspecContent)
    } else {
    Add-File $Package ($ModuleInfo.Name + $NuSpecManifestExtension) -Content ($ModuleInfo | Get-NuspecContent)
    }

    ## NuGet does the WRONG thing here, assuming the package name is unique
    ## And  pretending there's only one repo, and no need for unique identifiers
    #$PackageProperties.Identifier = $ModuleInfo.GUID
    $PackageProperties.Title = $ModuleInfo.Name
    $PackageProperties.Identifier = $ModuleInfo.Name

    $PackageProperties.Version = $ModuleInfo.Version
    $PackageProperties.Creator = $ModuleInfo.Author
    $PackageProperties.Description = $ModuleInfo.Description
    $PackageProperties.ContentStatus = "PowerShell " + $ModuleInfo.PowerShellVersion
    $PackageProperties.Created = Get-Date
    $PackageProperties.LastModifiedBy = $UserAgent
    $PackageProperties.Category = $ModuleInfo.Category

    if($ModuleInfo.Keywords) {
      $PackageProperties.Keywords = @(@($ModuleInfo.Keywords) + $ModulePackageKeyword | Sort-Object -Unique) -join ' '
    }
    if($anyUrl = if($ModuleInfo.HelpInfoUri) { $ModuleInfo.HelpInfoUri } elseif($ModuleInfo.ModuleInfoUri) { $ModuleInfo.ModuleInfoUri } elseif($ModuleInfo.DownloadUri) { $ModuleInfo.DownloadUri }) {
      $PackageProperties.Subject = $anyUrl
    }
  }
}


function Get-NuspecContent {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("id")]
        [String]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Version]$Version,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("Authors")]
        [String]$Author,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("Owners")]
        [String]$CompanyName,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("LicenseUrl")]
        [String]$LicenseUri,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("ProjectUrl")]
        [String]$ModuleInfoUri,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("IconUrl")]
        [String]$ModuleIconUri,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [String]$RequireLicenseAcceptance,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [String]$Description,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [String]$ReleaseNotes,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [String]$Copyright,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias("tags")]
        [String[]]$Keywords,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Array]$RequiredModules
    )

    # Add a nuget manifest
    [xml]$doc = "<?xml version='1.0'?>
    <package xmlns='$NuGetNamespace'>
      <metadata>
        <id>$([System.Security.SecurityElement]::Escape($Name))</id>
        <version>$([System.Security.SecurityElement]::Escape($Version))</version>
        <authors>$([System.Security.SecurityElement]::Escape($Author))</authors>
        <owners>$([System.Security.SecurityElement]::Escape($CompanyName))</owners>
        <licenseUrl>$([System.Security.SecurityElement]::Escape($LicenseUri))</licenseUrl>
        <projectUrl>$([System.Security.SecurityElement]::Escape($ModuleInfoUri))</projectUrl>
        <iconUrl>$([System.Security.SecurityElement]::Escape($ModuleIconUri))</iconUrl>
        <requireLicenseAcceptance>$(([bool]$RequireLicenseAcceptance).ToString().ToLower())</requireLicenseAcceptance>
        <description>$([System.Security.SecurityElement]::Escape($Description))</description>
        <releaseNotes>$([System.Security.SecurityElement]::Escape($ReleaseNotes))</releaseNotes>
        <copyright>$([System.Security.SecurityElement]::Escape($Copyright))</copyright>
        <tags>$([System.Security.SecurityElement]::Escape($Keywords -join ' '))</tags>
      </metadata>
    </package>"

    # Remove nodes without values (this is to clean up the "Url" nodes that aren't set)
    $($doc.package.metadata.GetElementsByTagName("*")) | 
       Where-Object { $_."#text" -eq $null } | 
       ForEach-Object { $null = $doc.package.metadata.RemoveChild( $_ ) }
    
    if( $ModuleInfo.RequiredModules ) {
       $dependencies = $doc.package.metadata.AppendChild( $doc.CreateElement("dependencies", $NuGetNamespace) )
       foreach($req in $RequiredModules) {
          $dependency = $dependencies.AppendChild( $doc.CreateElement("dependency", $NuGetNamespace) )
          if($req.Name) { $dependency.SetAttribute("id", $req.Name) }
          if($req.ModuleName) { $dependency.SetAttribute("id", $req.ModuleName) }
          if($req.Version) { $dependency.SetAttribute("version", $req.Version) }
          if($req.ModuleVersion) { $dependency.SetAttribute("version", $req.ModuleVersion) }
       }
    }

    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xmlWriter.IndentChar = $Character
    $doc.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}


function Set-ModuleInfo {
    <#
      .Synopsis
         Creates or updates Module manifest (.psd1), package manifest (.nuspec) and data files (.packageInfo) for a module.
      .Description
         Creates a package manifest with the mandatory and optional properties
    #>   
    [CmdletBinding()]
    param(
        # The name of the module to create a new package manifest(s) for
        [Parameter(Mandatory=$true, Position=0)]
        [String]$Name,

        [AllowEmptyCollection()]
        [System.Object[]]
        ${NestedModules},

        [guid]
        ${Guid},

        [AllowEmptyString()]
        [string[]]
        ${Author},

        [AllowEmptyString()]
        [Alias("Owner")]
        [string]
        ${CompanyName},

        [AllowEmptyString()]
        [string]
        ${Copyright},

        [Alias('ModuleToProcess')]
        [AllowEmptyString()]
        [string]
        ${RootModule},

        [Alias("Version")]
        [ValidateNotNull()]
        [version]
        ${ModuleVersion},

        [AllowEmptyString()]
        [string]
        ${Description},

        [System.Reflection.ProcessorArchitecture]
        ${ProcessorArchitecture},

        [version]
        ${PowerShellVersion},

        [version]
        ${ClrVersion},

        [version]
        ${DotNetFrameworkVersion},

        [string]
        ${PowerShellHostName},

        [version]
        ${PowerShellHostVersion},

        # The Required modules is a hashtable of ModuleName=PackageInfoUri, or an array of module names, etc
        [System.Object[]]
        ${RequiredModules},

        [AllowEmptyCollection()]
        [string[]]
        ${TypesToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${FormatsToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${ScriptsToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${RequiredAssemblies},

        [AllowEmptyCollection()]
        [string[]]
        ${FileList},

        [AllowEmptyCollection()]
        [System.Object[]]
        ${ModuleList},

        [AllowEmptyCollection()]
        [string[]]
        ${FunctionsToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${AliasesToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${VariablesToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${CmdletsToExport},

        [AllowNull()]
        [System.Object]
        ${PrivateData},

        [AllowNull()]
        [string]
        ${HelpInfoUri},

        [switch]
        ${PassThru},

        [AllowNull()]
        [string]
        ${DefaultCommandPrefix},

        # The url where the module package will be uploaded
        [String]$DownloadUri,
      
        # The url where the module's package manifest will be uploaded (defaults to the download URI modified to ModuleName.psd1)
        [String]$PackageInfoUri,

        # The url to a license
        [String]$LicenseUri,

        # If set, require the license to be accepted during installation (not supported yet)
        [Switch]$RequireLicenseAcceptance,

        # Choose one category from the list:
        [ValidateSet("Active Directory", "Applications", "App-V", "Backup and System Restore", "Databases", "Desktop Management", "Exchange", "Group Policy", "Hardware", "Interoperability and Migration", "Local Account Management", "Logs and monitoring", "Lync", "Messaging & Communication", "Microsoft Dynamics", "Multimedia", "Networking", "Office", "Office 365", "Operating System", "Other Directory Services", "Printing", "Remote Desktop Services", "Scripting Techniques", "Security", "Servers", "SharePoint", "Storage", "System Center", "UE-V", "Using the Internet", "Windows Azure", "Windows Update")]
        [String]$Category,

        # An array of keyword tags for search
        [String[]]$Keywords,

        # a URL or relative path to your personal avatar in gif/jpg/png form
        [String]$AuthorAvatarUri,
        
        # the address for your your company website
        [String]$CompanyUri,

        # a URL or relative path to your corporate logo in gif/jpg/png form
        [String]$CompanyIconUri,

        # a URL or relative path to a web page about this module
        [String]$ModuleInfoUri,

        # a URL or relative path to an icon for the module in gif/jpg/png form
        [String]$ModuleIconUri,

        # a web URL for a bug tracker or support forum, or a mailto: address for the author/support team.
        [String]$SupportUri,

        [Switch]$AutoIncrementBuildNumber
    )
    begin {
        $ModuleManifestProperties = 'AliasesToExport', 'Author', 'ClrVersion', 'CmdletsToExport', 'CompanyName', 'Copyright', 'DefaultCommandPrefix', 'Description', 'DotNetFrameworkVersion', 'FileList', 'FormatsToProcess', 'FunctionsToExport', 'Guid', 'HelpInfoUri', 'ModuleList', 'ModuleVersion', 'NestedModules', 'PowerShellHostName', 'PowerShellHostVersion', 'PowerShellVersion', 'PrivateData', 'ProcessorArchitecture', 'RequiredAssemblies', 'RequiredModules', 'ModuleToProcess', 'ScriptsToProcess', 'TypesToProcess', 'VariablesToExport'
        $PoshCodeProperties = 'ModuleName','ModuleVersion','DownloadUri','PackageInfoUri','LicenseUri','RequireLicenseAcceptance','Category','Keywords','AuthorAvatarUri','CompanyUri','CompanyIconUri','ModuleInfoUri','ModuleIconUri','SupportUri','AutoIncrementBuildNumber','RequiredModules'
        $NuGetProperties = 'Name','Version','Author','CompanyName','LicenseUri','ModuleInfoUri','ModuleIconUri','RequireLicenseAcceptance','Description','ReleaseNotes','Copyright','Keywords','RequiredModules'
    }
    end {
        $ErrorActionPreference = "Stop"
        $Manifest = Read-Module $Name | Select-Object *
        if(!$Manifest) {
            $Manifest = Read-Module $Name -ListAvailable | Select-Object *
        }

        $Path = "$($Manifest.ModuleManifestPath)"
        if(!$Path.EndsWith($ModuleManifestExtension) -or !(Test-Path $Path)){ 
            Write-Debug "Manifest file not found: $Path"
            $Path = "$($Manifest.Path)"
            if(!$Path.EndsWith($ModuleManifestExtension) -or !(Test-Path $Path)){ 
                Write-Debug "Manifest file not found: $Path"
                $Path = Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $ModuleManifestExtension)
                if(!(Test-Path $Path)){ 
                     Write-WarningDebug "Manifest file not found: $Path"
                     $Path = [IO.Path]::ChangeExtension($Manifest.Path, $ModuleManifestExtension)
                }
            }
        }

        if(Test-Path $Path) {
            $Manifest = Update-ModuleInfo $Path

            ## NOTE: this is here to preserve "extra" metadata to the moduleInfo file
            $ErrorActionPreference = "SilentlyContinue"
            $PInfoPath = [IO.Path]::ChangeExtension($Path, $PackageInfoExtension)
            if(Test-Path $PInfoPath) {
                $Info = Import-Metadata $PInfoPath
                $PoshCodeProperties = ($PoshCodeProperties + $Info.Keys) | Select -Unique
            }
            $ErrorActionPreference = "Stop"
        } else {
            Write-Warning "No Manifest file: $Path"

            # When loading a module without an existing manifest, punt
            $ModuleManifestProperties = @('Copyright')
        }

        Write-Debug ("Loaded $Name " + (($Manifest | Format-List * | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n"))

        if(@($Manifest).Count -gt 1) {
            Write-Error "Found more than one module matching '$Name', please Import-Module the one you want to work with and try again"
            $Manifest
        }

        if(!$Manifest) {
            throw "Couldn't find module $Name"
        }

        if($ModuleVersion) {
            Write-Debug "Setting Module Version from parameter $ModuleVersion"
            [Version]$PackageVersion = $ModuleVersion 
        } elseif($Manifest.Version -gt "0.0") {
            [Version]$PackageVersion = $Manifest.Version
        } else {
            Write-Warning "Module Version not specified properly, using 1.0"
            [Version]$PackageVersion = "1.0"
        }

        if($AutoIncrementBuildNumber) {
            $PackageVersion.Build = $PackageVersion.Build + 1
        }
        # TODO: Figure out a way to get rid of one of these throughout PoshCode stuff
        $PSBoundParameters["ModuleVersion"] = $PackageVersion
        $PSBoundParameters["Version"] = $PackageVersion

        # Normalize RequiredModules to an array of hashtables
        if(!$RequiredModules -and @($Manifest.RequiredModules).Count -gt 0) {
            $RequiredModules = @($Manifest.RequiredModules)
        }
        if($RequiredModules){
            # Required modules can be specified like any of the following:
            # -RequiredModules "ModuleOne"
            # -RequiredModules @{ModuleName="PowerBot"; ModuleVersion="1.0" }
            # -RequiredModules "ModuleOne", "ModuleTwo", "ModuleThree"
            # -RequiredModules @( @{ModuleName="PowerBot"; ModuleVersion="1.0"; PackageInfoUrl="https://raw.github.com/Jaykul/PowerBot/master/PowerBot.packageInfo"}, ... )
            # But it's always treated as an array, so the question is: did they pass in module names, or hashtables?
            $RequiredModules = foreach($Module in $RequiredModules) {
                if($Module -is [String]) { 
                    @{ModuleName=$Module} 
                } 
                else {
                    $M = @{}
                    if($Module.ModuleName) {
                        $M.ModuleName = $Module.ModuleName
                    } elseif( $Module.Name ) {
                        $M.ModuleName = $Module.Name
                    } else {
                        Write-Warning ("RequiredModules is a " + $RequiredModules.GetType().FullName + " and this Module is a " + $Module.GetType().FullName)
                        Write-Debug (($Module | Format-List * -Force | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n")
                        Write-Debug (($Module | Get-Member | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n")
                        throw "The RequiredModules must be an array of module names or an array of ModuleInfo hashtables or objects (which must have a ModuleName key and optionally a ModuleVersion and PackageInfoUrl)"
                    }

                    if($Module.ModuleVersion) {
                        $M.ModuleVersion = $Module.ModuleVersion
                    } elseif( $Module.Version ) {
                        $M.ModuleVersion = $Module.Version
                    }

                    if($Module.ModuleGuid) {
                        $M.ModuleGuid = $Module.ModuleGuid
                    } elseif( $Module.Guid ) {
                        $M.ModuleGuid = $Module.Guid
                    }

                    if($Module.PackageInfoUrl) {
                        $M.PackageInfoUrl = $Module.PackageInfoUrl
                    } elseif($Prop = $Module | Get-Member *Url -Type Property | Select-Object -First 1) {
                        $M.PackageInfoUrl = $Module.($Prop.Name)
                    }

                    $M 
                }
            }
            $PSBoundParameters["RequiredModules"] = $RequiredModules
        }

        foreach($Key in $PSBoundParameters.Keys) {
            if($Manifest.$Key -ne $PSBoundParameters.$Key) {
               $Manifest = Add-Member -InputObject $Manifest -Name $Key -MemberType NoteProperty -Value $PSBoundParameters.$Key -Force -PassThru 
            }
        }

        Write-Debug ("Exporting $Name " + (($Manifest | Format-List * | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n"))

        # All the parameters, except "Path"
        $ModuleManifest = $Manifest | ConvertTo-Hashtable $ModuleManifestProperties -IgnoreEmptyProperties
        # Fix the Required Modules for New-ModuleManifest
        if( $ModuleManifest.RequiredModules ) {
            $ModuleManifest.RequiredModules = $ModuleManifest.RequiredModules | % { 
               $null = $_.Remove("PackageInfoUrl"); 
               if(!$_.ContainsKey("ModuleVersion")) {  $_.ModuleName } else { $_ }
            }
        }
        New-ModuleManifest -Path (Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $ModuleManifestExtension)) @ModuleManifest


        $PoshCode = $Manifest | ConvertTo-Hashtable $PoshCodeProperties -IgnoreEmptyProperties
        Write-Debug ("Exporting $Name Info " + (($PoshCode | Format-Table | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n"))

        $PoshCode | Export-Metadata -Path (Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $PackageInfoExtension))


        #$NuGetSpec = $Manifest | Get-Member $NuGetProperties -Type Properties | ForEach-Object {$H=@{}}{ $H.($_.Name) = $Manifest.($_.Name) }{$H}

        Set-Content -Path (Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $NuSpecManifestExtension)) -Value ($Manifest | Get-NuspecContent)
    }
}
