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
   #   Create a new psmx package for a module
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
         $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.InvalidDataException "Module metadata file (.psd1) not found for $($PsBoundParameters["Module"])"), "Unexpected Exception", "InvalidResult", $_) )
      }

      # Our packages are ModuleName.psmx (for now, $ModulePackageExtension = .psmx)
      $PackageName = $Module.Name
      if($Module.Version -gt "0.0") {
         $PackageVersion = $Module.Version
      } else {
         Write-Warning "Module Version not specified properly, using 1.0"
         $PackageVersion = "1.0"
      }
   
      # .psmx
      if($OutputPath.EndsWith($ModulePackageExtension)) {
         Write-Verbose "Specified OutputPath include the Module name (ends with $ModulePackageExtension)"
         $OutputPath = Split-Path $OutputPath
      }
      if(Test-Path $OutputPath -ErrorAction Stop) {
         $PackagePath = Join-Path $OutputPath "${PackageName}.${PackageVersion}${ModulePackageExtension}"
         $PackageInfoPath = Join-Path $OutputPath "${PackageName}${ModuleInfoExtension}"
      }

      Write-Verbose "Creating Module in $OutputPath"
      Write-Verbose "Package File Path: $PackagePath"
      Write-Verbose "Package Manifest : $PackageInfoPath"

      if($PSCmdlet.ShouldProcess("Package the module '$($Module.ModuleBase)' to '$PackagePath'", "Package '$($Module.ModuleBase)' to '$PackagePath'?", "Packaging $($Module.Name)" )) {
         if($Force -Or !(Test-Path $PackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$PackagePath' already exists, do you want to replace it?", "Packaging $($Module.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

            # If there's no ModuleInfo file, then we need to *create* one so that we can package this module
            $ModuleInfoPath = Join-Path (Split-Path $Module.Path) $ModuleInfoFile

            if(!(Test-Path $ModuleInfoPath))
            {
               $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.FileNotFoundException "Can't find the Package Manifest File: ${ModuleInfoPath}"), "Manifest Not Found", "ObjectNotFound", $_) )
            } else {
               Copy-Item $ModuleInfoPath $PackageInfoPath -ErrorVariable CantWrite
               if($CantWrite) {
                  $PSCmdlet.ThrowTerminatingError( $CantWrite[0] )
               }
            }
            Get-Item $PackageInfoPath

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
               Write-Warning "FileList not set in module metadata (.psd1) file. Packing all files from path: $($Module.ModuleBase)"
            }

            # Create the package
            $Package = [System.IO.Packaging.Package]::Open( $PackagePath, [IO.FileMode]::Create )
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
               if($Module.PackageManifestUri) {
                  $null = $Package.CreateRelationship( $Module.PackageManifestUri, "External", $PackageManifestType )
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
            Get-Item $PackagePath

            # TODO: once the URLs are mandatory, print the full URL here
            Write-Host "You should now copy the $ModuleInfoExtension and $ModulePackageExtension files to the locations specified by the PackageManifestUri and DownloadUri"  
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
      $MetadataName = "${PackageName}.psd1"
   }
   process {
      $FileRelativePath = $Path -replace $ModuleRootRex, ""
      $FileUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( $FileRelativePath )

      Write-Verbose "Packing $Path to ${PackageName}$ModulePackageExtension::$FileUri"

      # TODO: add MimeTypes for specific powershell types (would let us extract just one type of file)
      switch -regex ([IO.Path]::GetExtension($Path)) {
         "\.(?:psd1|psm1|ps1|cs|txt|md)" {
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

         ([regex]::Escape($ModuleInfoFile) + '$') {
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

# internal function for setting the PackageProperties of a psmx file
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

    # Add a nuget manifest
    [xml]$doc = "<?xml version='1.0'?>
    <package xmlns='$NuGetNamespace'>
      <metadata>
        <id>$([System.Security.SecurityElement]::Escape($ModuleInfo.Name))</id>
        <version>$([System.Security.SecurityElement]::Escape($ModuleInfo.Version))</version>
        <authors>$([System.Security.SecurityElement]::Escape($ModuleInfo.Author))</authors>
        <owners>$([System.Security.SecurityElement]::Escape($ModuleInfo.CompanyName))</owners>
        <licenseUrl>$([System.Security.SecurityElement]::Escape($ModuleInfo.LicenseUri))</licenseUrl>
        <projectUrl>$([System.Security.SecurityElement]::Escape($ModuleInfo.ModuleInfoUri))</projectUrl>
        <iconUrl>$([System.Security.SecurityElement]::Escape($ModuleInfo.ModuleIconUri))</iconUrl>
        <requireLicenseAcceptance>$(([bool]$ModuleInfo.RequireLicenseAcceptance).ToString().ToLower())</requireLicenseAcceptance>
        <description>$([System.Security.SecurityElement]::Escape($ModuleInfo.Description))</description>
        <releaseNotes>$([System.Security.SecurityElement]::Escape($ModuleInfo.ReleaseNotes))</releaseNotes>
        <copyright>$([System.Security.SecurityElement]::Escape($ModuleInfo.Copyright))</copyright>
        <tags>$([System.Security.SecurityElement]::Escape($ModuleInfo.Keywords -join ' '))</tags>
      </metadata>
    </package>"

    # Remove nodes without values (this is to clean up the "Url" nodes that aren't set)
    $($doc.package.metadata.GetElementsByTagName("*")) | 
       Where-Object { $_."#text" -eq $null } | 
       ForEach-Object { $null = $doc.package.metadata.RemoveChild( $_ ) }
    
    if( $ModuleInfo.RequiredModules ) {
       $dependencies = $doc.package.metadata.AppendChild( $doc.CreateElement("dependencies", $NuGetNamespace) )
       foreach($req in $ModuleInfo.RequiredModules) {
          $dependency = $dependencies.AppendChild( $doc.CreateElement("dependency", $NuGetNamespace) )
          $dependency.SetAttribute("id", $req.Name)
          $dependency.SetAttribute("version", $req.Version)
       }
    }

    Add-File $Package ($ModuleInfo.Name + $NuSpecManifestExtension) -Content $doc.OuterXml

    ## NuGet does the WRONG thing here, assuming the package name is unique, pretending there's only one repo
    #$PackageProperties.Title = $ModuleInfo.Name
    #$PackageProperties.Identifier = $ModuleInfo.GUID
    $PackageProperties.Identifier = $ModuleInfo.Name

    $PackageProperties.Version = $ModuleInfo.Version
    $PackageProperties.Creator = $ModuleInfo.Author
    $PackageProperties.Description = $ModuleInfo.Description
    $PackageProperties.ContentStatus = "PowerShell " + $ModuleInfo.PowerShellVersion
    $PackageProperties.Created = Get-Date
    if($ModuleInfo.Keywords) {
      $PackageProperties.Keywords = $ModuleInfo.Keywords -join ' '
    }
    if($anyUrl = if($ModuleInfo.HelpInfoUri) { $ModuleInfo.HelpInfoUri } elseif($ModuleInfo.ModuleInfoUri) { $ModuleInfo.ModuleInfoUri } elseif($ModuleInfo.DownloadUri) { $ModuleInfo.DownloadUri }) {
      $PackageProperties.Subject = $anyUrl
    }
  }
}


function New-PackageManifest {
   <#
      .Synopsis
         Creates a package manifest (package.psd1) for a module that already has a module manifest.
      .Description
         Creates a package manifest with the mandatory and optional properties
   #>   
   [CmdletBinding()]
   param(
      # The name of the module to create a new package.psd1 file for.
      [Parameter(Mandatory=$true)]
      [String]$Name,

      # The url where the module package will be uploaded
      [Parameter(Mandatory=$true)]
      [String]$DownloadUri,
      
      # The url where the module's package manifest will be uploaded (defaults to the download URI modified to ModuleName.psd1)
      [String]$PackageManifestUri = $( $DownloadUri -replace ([Regex]::Escape([IO.Path]::GetFileName($DownloadUri))), "${Name}.psd1" ),

      # The relative uri for a license file, or a url to a license file
      [String]$LicenseUri,

      # The Required modules is a hashtable of ModuleName=PackageManifestUri
      [Hashtable]$RequiredModules,

      # Choose one category from the list:
      [ValidateSet("Active Directory", "Applications", "App-V", "Backup and System Restore", "Databases", "Desktop Management", "Exchange", "Group Policy", "Hardware", "Interoperability and Migration", "Local Account Management", "Logs and monitoring", "Lync", "Messaging & Communication", "Microsoft Dynamics", "Multimedia", "Networking", "Office", "Office 365", "Operating System", "Other Directory Services", "Printing", "Remote Desktop Services", "Scripting Techniques", "Security", "Servers", "SharePoint", "Storage", "System Center", "UE-V", "Using the Internet", "Windows Azure", "Windows Update")]
      [String]$Category,

      # An array of keyword tags for search
      [String[]]$Keywords,

      # a URL or relative path to your personal avatar in gif/jpg/png form
      [String]$AuthorAvatarUri,

      # your company name, if you have one
      [String]$CompanyName,

      # the address for your your company website
      [String]$CompanyUri,

      # a URL or relative path to your corporate logo in gif/jpg/png form
      [String]$CompanyIconUri,

      # a URL or relative path to a web page about this module
      [String]$ModuleInfoUri,

      # a URL or relative path to an icon for the module in gif/jpg/png form
      [String]$ModuleIconUri,

      # a web URL for a bug tracker or support forum, or a mailto: address for the author/support team.
      [String]$SupportUri
   )
   end {
      $Manifest = Read-Module $Name -ListAvailable 

      if(!$Manifest) {
         throw "Couldn't find module $Name"
      }

      if($PackageManifestUri) {
         $PSBoundParameters.PackageManifestUri = $PackageManifestUri
      }

      $PSBoundParameters.Version = $Manifest.Version
      $PSBoundParameters.Author  = $Manifest.Author

      if($Manifest.RequiredModules.Count -gt 0) {
         $Modules = @()
         # TODO: loop through $RequiredModules and make @{ Name="Name"; PackageManifestUri = "$PackageManifestUri" }
         if($Manifest.RequiredModules -is [Array]) {
            foreach($moduleInfo in $Manifest.RequiredModules) {
               $Name = $( if($moduleInfo.Name) { $moduleInfo.Name } else { "$moduleInfo" } )
               if($RequiredModules.ContainsKey($Name)) {
                  $Modules += @{ Name = $Name; PackageManifestUri = $RequiredModules.$Name }
               } else {
                  Write-Host "Please enter the PackageManifestURI:"
                  $Modules += @{ Name = $Name; PackageManifestUri = (Read-Host $Name )}
               }
            }
         } else {
            $moduleInfo = $Manifest.RequiredModules
            $Name = $( if($moduleInfo.Name) { $moduleInfo.Name } else { "$moduleInfo" } )
            if($RequiredModules -and $RequiredModules.ContainsKey($Name)) {
               $Modules += @{ Name = $Name; PackageManifestUri = $RequiredModules.$Name }
            } else {
               Write-Host "Please enter the PackageManifestURI:"
               $Modules += @{ Name = $Name; PackageManifestUri = (Read-Host $Name )}
            }
         }
         $PSBoundParameters["RequiredModules"] = $Modules
      } elseif($PSBoundParameters.RequiredModules.Count -eq 0) {
         $PSBoundParameters.Remove("RequiredModules")
      }

      $PSBoundParameters | Export-Metadata -Path (Join-Path $Manifest.ModuleBase "package.psd1")
   }
}
