########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################

# The config file
$ConfigFile = Join-Path $PSScriptRoot ([IO.Path]::GetFileName( [IO.Path]::ChangeExtension($PSScriptRoot, ".ini") ))

$SourceFiles = "$PSScriptRoot\Source\AssemblyInfo.cs",
               "$PSScriptRoot\Source\VersionTypeConverter.cs",
               "$PSScriptRoot\Source\Version.cs",
               "$PSScriptRoot\Source\ModuleId.cs",
               "$PSScriptRoot\Source\StringList.cs",
               "$PSScriptRoot\Source\ModuleInfo.cs",
               "$PSScriptRoot\Source\ModuleManifest.cs"

$LastDate = Get-ChildItem $SourceFiles | Sort LastWriteTime -Descending | Select -First 1 -ExpandProperty LastWriteTime

if(!(Test-Path "$PSScriptRoot\Packaging.dll") -or $LastDate -gt (Get-Item "$PSScriptRoot\Packaging.dll").LastWriteTime) {
  Add-Type -Path $SourceFiles -ReferencedAssemblies System.Xaml -OutputAssembly "$PSScriptRoot\Packaging.dll" -Passthru
} else {
  Add-Type -Path "$PSScriptRoot\Packaging.dll" -Passthru
}

function Update-ModulePackage {
  #.Synopsis
  #   Check for updates for modules
  #.Description
  #   Test the ModuleInfoUri and upgrade if there's a newer version
  [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
  param(
    # The name of the module to package
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()] 
    $Module = "*",

    # If set, overwrite existing packages without prompting
    [switch]$Force
  )
  begin {
    Write-Error "Update-ModulePackage Has Not Been Written Yet. Just run Install-ModulePackage again."
  }
}

function Test-ModulePackage {
  #.Synopsis
  #   Checks if you have the latest version of each module
  #.Description
  #   Test the ModuleInfoUri and offer to upgrade if there's a newer version
  [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
  param(
    # The name of the module to package
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()] 
    $Module = "*",

    # If set, overwrite existing packages without prompting
    [switch]$Force
  )
  begin {
    Write-Error "Test-ModulePackage Has Not Been Written Yet. Just run Install-ModulePackage again."
    return

    if("$Package" -match "^https?://" ) {
      $Package = Get-ModulePackage $Package $InstallPath -ErrorVariable FourOhFour
      if($FourOhFour){
        $PSCmdlet.ThrowTerminatingError( $FourOhFour[0] )
      }
    }
    # Open it as a package
    $PackagePath = Resolve-Path $Package -ErrorAction Stop


    $ModuleInfo = Get-ModuleInfo $Module
    if($ModuleInfo.ModuleInfoUri) {

    } else {

    }
  }
}

function New-ModulePackage {
  #.Synopsis
  #   Create a new psmx package for a module
  #.Description
  #   Create a module package based on a .psd1 metadata module. 
  #.Notes
  #     If the FileList is set in the psd1, only those files are packed
  #     If present, a ${Module}.png image will be used as a thumbnail
  #     HelpInfoUri will be parsed for urls
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
    $Piped = $PsBoundParameters.ContainsKey("Module")

    $RejectAllOverwrite = $false;
    $ConfirmAllOverwrite = $false;

  }
  process {
    if($Module -isnot [System.Management.Automation.PSModuleInfo]) {
      # Hypothetically, could it be faster to select -first, now that pipelines are interruptable?
      $ModuleName = $Module
      $Module = Get-Module $ModuleName | Select-Object -First 1
      if(!$Module) {
        $Module = Get-Module $ModuleName -ListAvailable | Select-Object -First 1
      }
    }
    $ModuleInfo = Get-ModuleInfo $Module.Name | Select-Object -First 1

    Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Validating Inputs" -Id 0    

    # If the Module.Path isn't a PSD1, then there is none, so we can't package this module
    if( $Module -isnot [System.Management.Automation.PSModuleInfo] -and
        [IO.Path]::GetExtension($Module.Path) -ne ".psd1" ) {
      $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.InvalidDataException "Module metadata file (.psd1) not found for $($PsBoundParameters["Module"])"), "Unexpected Exception", "InvalidResult", $_) )
    }


    # Our packages are ModuleName.psmx (for now, $ModulePackageExtension = .psmx)
    $PackageName = $Module.Name
    if($Module.Version -gt "0.0") {
      $PackageVersion = $Module.Version
    } else {
      $ModuleInfo = Get-ModuleInfo $Module.Name | Select-Object -First 1
      $PackageVersion = $ModuleInfo.Version
    }
    if(!$OutputPath.EndsWith($ModulePackageExtension)) {
      if(Test-Path $OutputPath -ErrorAction Stop) {
        $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
        $PackageInfoPath = Join-Path $OutputPath "${PackageName}${ModuleInfoExtension}"
      }
    } elseif($Piped) {
      $OutputPath = Split-Path $OutputPath
      if(Test-Path $OutputPath -ErrorAction Stop) {
        $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
        $PackageInfoPath = Join-Path $OutputPath "${PackageName}${ModuleInfoExtension}"
      }
    }

    if($PSCmdlet.ShouldProcess("Package the module '$($Module.ModuleBase)' to '$PackagePath'", "Package '$($Module.ModuleBase)' to '$PackagePath'?", "Packaging $($Module.Name)" )) {
      if($Force -Or !(Test-Path $PackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$PackagePath' already exists, do you want to replace it?", "Packaging $($Module.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

        # If there's no ModuleInfo file, then we need to *create* one so that we can package this module
        $ModuleInfoPath = [IO.Path]::ChangeExtension( $Module.Path, $Script:ModuleInfoExtension )
        
        if(!(Test-Path $ModuleInfoPath))
        {
          Write-Warning "ModuleInfo file '$ModuleInfoPath' not found, generating from module manifest: $($Module.Path)"
          Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Creating ModuleInfo Metatada File" -Id 0
          # TODO: this should prompt for mandatory parameters if they're not provided to New-ModulePackage
          Remove-Variable Xaml -Scope Script -ErrorAction SilentlyContinue
          Update-ModuleInfo $Module
          if(!(Test-Path $ModuleInfoPath)) {
            if(Test-Path Variable:Xaml) {
              Set-Content $PackageInfoPath $Script:Xaml -ErrorVariable CantWrite
              if($CantWrite) {
                $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.UnauthorizedAccessException "Couldn't output Package Info file: $PackageInfoPath"), "Access Denied", "InvalidResult", $CantWrite) )
              }
            } else {
              $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.UnauthorizedAccessException "Couldn't access Module Manifest file: $ModuleInfoPath"), "Access Denied", "InvalidResult", $_) )
            }
          } else {
            Copy-Item $ModuleInfoPath $OutputPath -ErrorVariable CantWrite
            if($CantWrite) {
              $PSCmdlet.ThrowTerminatingError( $CantWrite[0] )
            }
          }
        } else {
          Copy-Item $ModuleInfoPath $OutputPath -ErrorVariable CantWrite
          if($CantWrite) {
            $PSCmdlet.ThrowTerminatingError( $CantWrite[0] )
          }
        }
        Get-Item $PackageInfoPath

        Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Preparing File List" -Id 0    

        $MetadataName = "${PackageName}.psd1"
        $MetadataPath = Join-Path $Module.ModuleBase $MetadataName
        $ModuleRootRex = [regex]::Escape((Split-Path $Module.ModuleBase))


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
        Set-PackageProperties $Package.PackageProperties $Module

        try {

          # Now pack up all the files we've found:
          $Target = $FileList.Count
          $Count = 0
          foreach($file in $FileList) {
            $Count += 1
            Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Packing File $Count of $Target" -Id 0 -PercentComplete ((($count-1)/$target)*100)

            $FileUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( ($File -replace $ModuleRootRex, "") )

            Write-Verbose "Packing $file to ${PackageName}$ModulePackageExtension::$FileUri"

            # TODO: add MimeTypes for specific powershell types (would let us extract just one type of file)
            switch -regex ([IO.Path]::GetExtension($File)) {
              "\.(?:psd1|psm1|ps1|cs)" {
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
              "\$ModuleInfoExtension" {
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
              $reader = [IO.File]::Open($File, "Open", "Read", "Read")
              $writer = $part.GetStream()
              Copy-Stream $reader $writer -Length (Get-Item $File).Length -Activity "Packing $file"
            } catch [Exception]{
              $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
              if($writer) {
                $writer.Close()
                $writer.Dispose()
              }
              if($reader) {
                $reader.Close()
                $reader.Dispose()
              }
            }

            # Add a Package Relationship to the Document Part
            switch -regex ($File) {
              ([regex]::Escape($Module.Path)) {
                $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleMetadataType)
                Write-Verbose "    Added Relationship: $ModuleMetadataType"
                break
              } 
              "\$ModuleInfoExtension`$" {
                $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ManifestType)
                Write-Verbose "    Added Relationship: $ManifestType"
                break
              }

              # I'm not sure there's any benefit to pointing out the RootModule, but it can't hurt
              # OMG - If I ever get a chance to clue-bat the person that OK'd this change to "RootModule":
              ([regex]::Escape($(if($module.RootModule){$module.RootModule}else{$module.ModuleToProcess})) + '$') {
                $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleRootType)
                Write-Verbose "    Added Relationship: $ModuleRootType"
                break
              }

              ([regex]::Escape($PackageName + "\.(png|gif|jpg)") + '$') {
                $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $PackageThumbnailType)
                Write-Verbose "    Added Relationship: $PackageThumbnailType"
                break
              }

              default {
                $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleContentType)
                Write-Verbose "    Added Relationship: $ModuleContentType"
              }
            }
          }

          # When the manifest can't be written out (and doesn't exist on disk), as a last-ditch effort
          # We have this way around it by generating a manifest in memory (Of course, it won't have URLS)
          if((Test-Path variable:ManifestContent) -and !(Test-Path $ModuleInfoPath)){
            $FileUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( ($ModuleInfoPath -replace $ModuleRootRex, "") )
            $part = $Package.CreatePart( $FileUri, "text/xaml", "Maximum" ); 
            $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ManifestType)
            Write-Verbose "    Added Relationship: $ManifestType"

            # Copy the data to the Document Part 
            try {
              $writer = $part.GetStream()
              $bytes = [System.Text.Encoding]::UTF8.GetBytes($ManifestContent)
              $writer.Write($bytes, 0, $bytes.Count)
            } catch [Exception]{
              $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
              if($writer) {
                $writer.Close()
                $writer.Dispose()
              }
            }
            # TODO: Make mandatory parts of the Module Manifest mandatory, and change this warning.
            Write-Warning "The module package manifest was NOT found (it should be created with Update-ModuleInfo at '$ModuleInfoPath'). Without it, the module is not fully valid."
          }

          if($Module.HelpInfoUri) {
            $Package.CreateRelationship( $Module.HelpInfoUri, "External", $ModuleHelpInfoType )
          }
          if($Module.ModuleInfoUri) {
            $Package.CreateRelationship( $Module.ModuleInfoUri, "External", $ModuleReleaseType )
          }
          if($Module.LicenseUri) {
            $Package.CreateRelationship( $Module.LicenseUri, "External", $ModuleLicenseType )
          }
          if($Module.PackageUri) {
            $Package.CreateRelationship( $Module.PackageUri, "External", $ModuleReleaseType )
          }

        } catch [Exception] {
          $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
        } finally {
          if($Package) { 
            Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Writing Package" -Id 0            
            $Package.Close()
            $Package.Dispose() 
          }
        }

        Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Complete" -Id 0 -Complete

        # Write out the FileInfo for the package
        Get-Item $PackagePath

        # TODO: once the URLs are mandatory, print the full URL here
        Write-Host "You should now copy the $ModuleInfoExtension and $ModuleManifestExtension files to the locations specified by the ModuleInfoUri and PackageUri"  
      }
    }
  }
}

function Get-ModuleInfo {
  #.Synopsis
  #  Get information about a module from the ModuleInfo manifest or the psd1 metadata file.
  [CmdletBinding()]
  param(
    # The name of the module (or path)
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
    [Alias("PSPath","Path","Name")]
    $Module
  )
  process {
    [string]$ModuleManifestPath = ""
    [string]$ModuleInfoPath = ""

    # If the parameter isn't already a ModuleInfo object, then let's make it so:
    if($Module -isnot [System.Management.Automation.PSModuleInfo] -and $Module -isnot [PoshCode.Packaging.ModuleInfo]) {
      if("$Module".Contains([IO.Path]::DirectorySeparatorChar)) {
        $ModulePath = Convert-Path $Module -ErrorAction SilentlyContinue -ErrorVariable noPath
        if($noPath) { $ModulePath = $Module }
      } else {
        $ModulePath = $Module
      }
      $Module = $null
      $Extension = [IO.Path]::GetExtension($ModulePath)
      # It should be either a String or a FileInfo (if it's a string, it might begmo)
      Write-Verbose "Switch on Extension: $Extension  ($ModulePath)"
      switch($Extension) {
        $ModuleInfoExtension {
          Write-Verbose "Finding Module by ModuleInfoPath"
          $ModuleInfoPath = $ModulePath
          $ModuleManifestPath = [IO.Path]::ChangeExtension($ModuleInfoPath, $ModuleManifestExtension)
        }
        $ModuleManifestExtension {
          Write-Verbose "Finding Module by ModuleManifestPath"
          # We have a path to a .psd1
          $ModuleManifestPath = $ModulePath
          $ModuleInfoPath = [IO.Path]::ChangeExtension($ModuleManifestPath, $ModuleInfoExtension)
        }
        $ModulePackageExtension {
          Write-Verbose "Finding Module by ModuleManifestPath"
          try {
            $Package = [System.IO.Packaging.Package]::Open( (Convert-Path $ModulePath), [IO.FileMode]::Open, [System.IO.FileAccess]::Read )

            $Manifest = @($Package.GetRelationshipsByType( $ManifestType ))[0]
            if(!$Manifest -or !$Manifest.TargetUri ){
              Write-Warning "This Package is invalid, it has not specified the manifest"
              Write-Output $Package.PackageProperties | 
                Add-Member NoteProperty HelpInfoUri ($Package.GetRelationshipsByType($ModuleHelpInfoType))[0].TargetUri -Passthru | 
                Add-Member NoteProperty ModuleInfoUri ($Package.GetRelationshipsByType($ModuleReleaseType))[0].TargetUri -Passthru | 
                Add-Member NoteProperty LicenseUri ($Package.GetRelationshipsByType($ModuleLicenseType))[0].TargetUri -Passthru
              return
            }

            $Part = $Package.GetPart( $manifest.TargetUri )
            if(!$Part) {
              Write-Warning "This Package is invalid, it has no manifest at $($manifest.TargetUri)"
              Write-Output $Package.PackageProperties | 
                Add-Member NoteProperty HelpInfoUri ($Package.GetRelationshipsByType($ModuleHelpInfoType))[0].TargetUri -Passthru | 
                Add-Member NoteProperty ModuleInfoUri ($Package.GetRelationshipsByType($ModuleReleaseType))[0].TargetUri -Passthru | 
                Add-Member NoteProperty LicenseUri ($Package.GetRelationshipsByType($ModuleLicenseType))[0].TargetUri -Passthru
              return
            }

            try {
              $reader = $part.GetStream()
              # This gets the ModuleInfo
              [Xaml.XamlServices]::Load($reader) | 
                Add-Member NoteProperty PackagePath $PackagePath -Passthru |
                Add-Member NoteProperty PSPath ("{0}::{1}" -f $PackagePath.Provider, $PackagePath.ProviderPath) -Passthru                
            } catch [Exception]{
              $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
              if($reader) {
                $reader.Close()
                $reader.Dispose()
              }
            }
          } catch [Exception] {
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
          } finally {
            $Package.Close()
            $Package.Dispose()
          }
          return
        }
        default {
          Write-Verbose "Finding Module by Module Name"
          # Hopefully, they've just specified a module name:
          $Module = Get-Module $ModulePath -ListAvailable | Select-Object -First 1
          if($Module) {
            $ModuleInfoPath = Join-Path $Module.ModuleBase "$($Module.Name)$ModuleInfoExtension"
            $ModuleManifestPath = Join-Path $Module.ModuleBase "$($Module.Name)$ModuleManifestExtension"
          }
        }
      }

      if(!$Module -and (Test-Path $ModulePath)) {
        Write-Verbose "Searching for Module by Path"
        # They got crazy and passed us a path instead of a name ...
        $ModuleBase = $ModulePath
        if(Test-Path $ModulePath -PathType Leaf) {
          $ModuleBase = Split-Path $ModulePath
        }
        # Hopefully, it's at least in the PSModulePath (or already loaded)
        $Module = Get-Module (Split-Path $ModuleBase -Leaf) -ListAvailable | Where-Object { $_.ModuleBase -eq $ModuleBase }
        # But otherwise, we can always try importing it:
        if(!$Module) {
          Write-Verbose "Finding Module by Import-Module (least optimal method)"
          $Module = Import-Module $ModulePath -Passthru
          if($Module) {
            Remove-Module $Module
          }
        }
      }
    }
    if($Module) {
      $ModuleInfoPath = Join-Path $Module.ModuleBase "$($Module.Name)$ModuleInfoExtension"
      $ModuleManifestPath = Join-Path $Module.ModuleBase "$($Module.Name)$ModuleManifestExtension"
    }

    Write-Verbose "ModuleManifest Path: $ModuleManifestPath"

    if(Test-Path $ModuleInfoPath) {
      Write-Verbose "Loading ModuleManifest"
      $ModuleInfo = [system.xaml.xamlservices]::Load( $ModuleInfoPath ) | 
                      Add-Member NoteProperty ModuleInfoPath $ModuleInfoPath -Passthru | 
                      Add-Member NoteProperty ModuleManifestPath $ModuleManifestPath -Passthru
      Write-Output $ModuleInfo
    }
    elseif($Module) 
    {
      Write-Verbose "Write out PSModuleInfo"
      Write-Output ($Module -as [PoshCode.Packaging.ModuleManifest] | 
                      Add-Member NoteProperty ModuleInfoPath $ModuleInfoPath -Passthru | 
                      Add-Member NoteProperty ModuleManifestPath $ModuleManifestPath -Passthru)
    } 
    else 
    {
      throw "Unable to get ModuleInfo"
    }
  }
}

function Update-ModuleInfo {
  #.Synopsis
  #   Update the Module.psminfo and Module.psd1
  [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', HelpUri='http://go.microsoft.com/fwlink/?LinkID=141555')]
  param(
    [Parameter(Mandatory=$true, Position=0)]
    ${Module},

    [AllowEmptyCollection()]
    [System.Object[]]
    ${NestedModules},

    [guid]
    ${Guid},

    [AllowEmptyString()]
    [string]
    ${Author},

    [AllowEmptyString()]
    [string]
    ${CompanyName},

    [AllowEmptyString()]
    [string]
    ${Copyright},

    [Alias('ModuleToProcess')]
    [AllowEmptyString()]
    [string]
    ${RootModule},

    [ValidateNotNull()]
    [version]
    [Alias("ModuleVersion")]
    ${Version},

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

    [AllowNull()]
    [string]
    ${LicenseUri},

    [AllowNull()]
    [string]
    ${HomePageUri},

    [AllowNull()]
    [string]
    ${ModuleInfoUri},

    [AllowNull()]
    [string]
    ${PackageUri},

    [switch]
    ${PassThru},

    [AllowNull()]
    [string]
    ${DefaultCommandPrefix}
  )
  begin {
    $PsBoundParameters.Remove("Module") | Out-Null
    ## And the stupid common parameters:
    if($PsBoundParameters.ContainsKey("Verbose")) {
      $PsBoundParameters.Remove("Verbose") | Out-Null
    }
    $RejectAllOverwrite = $false;
    $ConfirmAllOverwrite = $false;
  }
  end
  {
    $ModuleInfo = Get-ModuleInfo $Module
    $ErrorActionPreference = "Stop"

    if($ModuleInfo.FileList) {
      [string[]]$Files = $ModuleInfo.FileList -replace ("(?i:" + [regex]::Escape((Split-Path $ModuleInfo.ModuleInfoPath)) + "\\?)"), ".\"
      $ModuleInfo.FileList.Clear()
      $ModuleInfo.FileList.AddRange($Files)
    }

    # We need to copy the ModuleMetadata, not modify it 
    if($PSModuleInfo = Get-Module $Module -ErrorAction SilentlyContinue) {
      $ModuleBase = $PSModuleInfo.ModuleBase
      $PSModuleInfo = [PoshCode.Packaging.ModuleManifest]$PSModuleInfo
      if($PSModuleInfo.FileList -and $ModuleBase) {
        [string[]]$Files = $PSModuleInfo.FileList -replace ("(?i:" + [regex]::Escape($ModuleBase) + "\\?)"), ".\"
        $PSModuleInfo.FileList.Clear()
        $PSModuleInfo.FileList.AddRange($Files)
      }

      $Properties = $PSModuleInfo.GetType().GetProperties() | 
                      Select-Object -Expand Name | 
                      Where-Object { 
                        ($PsBoundParameters.Keys -notcontains $_) -and 
                        $PSModuleInfo.$_ -and 
                        $PSModuleInfo.$_.GetType().GetInterface("System.Collections.Generic.IList``1") -and
                        $PSModuleInfo.$_.GetType().GetInterface("System.Collections.Generic.IList``1").GenericTypeArguments[0] -eq [string]
                      }
      foreach($prop in $Properties) {
        foreach($item in $PSModuleInfo.$prop) {
          if($ModuleInfo.$prop -NotContains $item) {
            if($PSCmdlet.ShouldContinue(
                "The following item is in the .psd1 manifest. Do you want to add it to the ModuleInfo?`n$($item|out-string)",
                "Updating ModuleInfo '$prop' for $($ModuleInfo.Name)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) 
            {
              $ModuleInfo.$prop.Add( $item )
            }
          }
        }
      }
    }

    # TODO: make the rest of the mandatory things mandatory (version, guid, etc)
    foreach($Uri in @{
      ModuleInfoUri = "the web address where the $ModuleInfoExtension file for the current version can always be found (regardless of version number)."
      LicenseUri    = "the path to a license file which describes the license for this module (CAN be relative)."
      PackageUri    = "the path where this specific .psmx package will be available for download"
      HomePageUri   = "the hompage URI for this module project."
      HelpInfoUri   = "the download URI for the PowerShell Help for this module (press ENTER to leave it blank)."
    }.GetEnumerator()) {

      if($ModuleInfo.($Uri.key) -le "") {
        Write-Host ("{0} is blank. Please enter {1}" -f $Uri.key, $Uri.value)
        if($value = Read-Host) {
          $ModuleInfo.($Uri.key) = $value
          $PsBoundParameters.Add($Uri.key, $value) | Out-Null
        }
      }
    }


    # Update ModuleInfo from the PSBoundParameters
    # $HashTable = Join-Hashtable $HashTable $PsBoundParameters
    foreach($key in $PsBoundParameters.Keys) {
      if($Interface = $ModuleInfo.$key.GetType().GetInterface("System.Collections.Generic.IList``1")) {
        $ModuleInfo.$key.Clear()
        foreach($item in $PsBoundParameters.$key) {
          $o = $item -as ($Interface.GenericTypeArguments[0])
          Write-Verbose "Adding '$o' to $key"
          $ModuleInfo.$key.Add( $o )
        }
      } else {
        Write-Verbose "Setting $key to $($PsBoundParameters.$key)"
        $ModuleInfo.$key = $PsBoundParameters.$key
      }
    }

    ## TODO: Prompt for empty required properties and update ModuleInfo
    $Script:Xaml = $null
    try {
      $Script:Xaml = [Xaml.XamlServices]::Save( $ModuleInfo )
      $NoPermission = $false
      Set-Content $ModuleInfo.ModuleInfoPath $Script:Xaml -Encoding UTF8 -ErrorAction Continue

      # Generate a hashtable from ModuleInfo for splatting to New-ModuleManifest
      $HashTable = $ModuleInfo | Select-Object AliasesToExport, Author, ClrVersion, CmdletsToExport, CompanyName, Copyright,
                                 DefaultCommandPrefix, Description, DotNetFrameworkVersion, FileList, FormatsToProcess,
                                 FunctionsToExport, Guid, HelpInfoUri, PassThru, Path, PowerShellHostName,
                                 PowerShellHostVersion, PowerShellVersion, PrivateData, ProcessorArchitecture,
                                 RequiredAssemblies, RootModule, ScriptsToProcess, TypesToProcess, VariablesToExport,
                                 @{n="ModuleVersion"; e={$_.Version}},
                                 @{n="NestedModules"; e={ $_.NestedModules | % { if($_.Version -gt 0.0) { [HashTable]$_ } else { $_.Name } } }},
                                 @{n="RequiredModules"; e={ $_.RequiredModules | % { if($_.Version -gt 0.0) { [HashTable]$_ } else { $_.Name } } }},
                                 @{n="ModuleList"; e={ $_.ModuleList | % { if($_.Version -gt 0.0) { [HashTable]$_ } else { $_.Name } } }} | ConvertTo-Hashtable -NoNulls

      Write-Verbose "ModuleManifest Values:`n$( $HashTable | Out-String )"

      # If they updated anything, then we should rewrite the ModuleManifest
      if(($PsBoundParameters.Keys.Count -gt 0) -and $PSCmdlet.ShouldContinue("We need to update the module manifest, is that ok?", "Updating $($ModuleInfo.Name)")) {    
        Write-Warning "Generating ModuleInfo file: '$($ModuleInfo.ModuleInfoPath)' with new values. Please verify the manifest matches.`nUpdated values:`n$($PsBoundParameters | Out-String -stream)"
        # Call New-ModuleManifest with the ModuleInfo hashtable
        New-ModuleManifest @HashTable -Path $ModuleInfo.ModuleManifestPath
      }
    } catch [Exception] {
      $NoPermission = $true
      $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
    }

  }
  <#
  .ForwardHelpTargetName New-ModuleManifest
  .ForwardHelpCategory Cmdlet
  #>
}

##### Private functions ######
function Set-PackageProperties {
  #.Synopsis
  #   Sets PackageProperties from a PSModuleInfo
  PARAM(
    # The PackageProperties object to set
    [Parameter(Mandatory=$true, Position=0)]
    [System.IO.Packaging.PackageProperties]$PackageProperties,

    # The ModuleInfo to get values from
    [Parameter(Mandatory=$true, Position=1)]
    [System.Management.Automation.PSModuleInfo]$ModuleInfo
  )
  process {
    $PackageProperties.Title = $ModuleInfo.Name
    $PackageProperties.Identifier = $ModuleInfo.GUID
    $PackageProperties.Version = $ModuleInfo.Version
    $PackageProperties.Creator = $ModuleInfo.Author
    $PackageProperties.Description = $ModuleInfo.Description
    $PackageProperties.Subject = $ModuleInfo.HelpInfoUri
    $PackageProperties.ContentStatus = "PowerShell " + $ModuleInfo.PowerShellVersion
    $PackageProperties.Created = Get-Date

  }
}

function ConvertTo-Hashtable {
  #.Synopsis
  #   Converts an object to a hashtable of property-name = value 
  PARAM(
    # The object to convert to a hashtable
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    $InputObject,

    # Forces the values to be strings and converts them by running them through Out-String
    [switch]$AsString,  

    # If set, allows each hashtable to have it's own set of properties, otherwise, 
    # each InputObject is normalized to the properties on the first object in the pipeline
    [switch]$jagged,

    # If set, empty properties are ommitted
    [switch]$NoNulls
  )
  BEGIN { 
    $headers = @() 
  }
  PROCESS {
    if(!$headers -or $jagged) {
      $headers = $InputObject | get-member -type Properties | select -expand name
    }
    $output = @{}
    if($AsString) {
      foreach($col in $headers) {
        if(!$NoNulls -or ($InputObject.$col -is [bool] -or ($InputObject.$col))) {
          $output.$col = $InputObject.$col | out-string -Width 9999 | % { $_.Trim() }
        }
      }
    } else {
      foreach($col in $headers) {
        if(!$NoNulls -or ($InputObject.$col -is [bool] -or ($InputObject.$col))) {
          $output.$col = $InputObject.$col
        }
      }
    }
    $output
  }
}

function Join-HashTable {
  <#
   .Synopsis
     Join two or more hashtables into a single collection
   .Description
     Takes two hashtables and joins them by copying values from the second into the first.
   .Example
     $config = Import-Yaml SomeFile.Yaml | Join-Hashtable
  #>
  [CmdletBinding()]
  param(
     #  A hashtable to join to other hashtables.
     [Parameter(Position=0)]
     [HashTable]$InputObject = @{},

     # HashTables to be joined together
     [Parameter(ValueFromPipeline=$true, Mandatory=$true, Position=1, ValueFromRemainingArguments=$true)]
     [HashTable[]]$Sources,

     # If set, the first in wins, otherwise, later hashtables will overwrite earlier ones
     [Switch]$NoClobber
  )
  begin {
     $Output = @{} + $InputObject.Clone()
  }
  process {
     Write-Verbose ($Sources|Out-String)
     foreach($Additional in $Sources) {
        foreach($key in @($Additional.Keys)) {
           if(!$NoClobber -or !$Output.ContainsKey($key)){
              $Output.$Key = $Additional.$Key
           }
        }
     }
  }
  end {
     $Output
  }
}



# SIG # Begin signature block
# MIIarwYJKoZIhvcNAQcCoIIaoDCCGpwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUD1h2TRnYcv73bs+0lZ1G4OMf
# 36egghXlMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggahMIIFiaADAgECAhADS1DyPKUAAEvdY0qN2NEFMA0GCSqGSIb3DQEBBQUAMG8x
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBLTEwHhcNMTMwMzE5MDAwMDAwWhcNMTQwNDAxMTIwMDAwWjBt
# MQswCQYDVQQGEwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3Qg
# SGVucmlldHRhMRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pv
# ZWwgSC4gQmVubmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMPj
# sSDplpNPrcGhb5o977Z7VdTm/BdBokBbRRD5hGF+E7bnIOEK2FTB9Wypgp+9udd7
# 6nMgvZpj4gtO6Yj+noUcK9SPDMWgVOvvOe5JKKJArRvR5pDuHKFa+W2zijEWUjo5
# DcqU2PGDralKrBZVfOonity/ZHMUpieezhqy98wcK1PqDs0Cm4IeRDcbNwF5vU1T
# OAwzFoETFzPGX8n37INVIsV5cFJ1uGFncvRbAHVbwaoR1et0o01Jsb5vYUmAhb+n
# qL/IA/wOhU8+LGLhlI2QL5USxnLwxt64Q9ZgO5vu2C2TxWEwnuLz24SAhHl+OYom
# tQ8qQDJQcfh5cGOHlCsCAwEAAaOCAzkwggM1MB8GA1UdIwQYMBaAFHtozimqwBe+
# SXrh5T/Wp/dFjzUyMB0GA1UdDgQWBBRfhbxO+IGnJ/yiJPFIKOAXo+DUWTAOBgNV
# HQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwcwYDVR0fBGwwajAzoDGg
# L4YtaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL2Fzc3VyZWQtY3MtMjAxMWEuY3Js
# MDOgMaAvhi1odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vYXNzdXJlZC1jcy0yMDEx
# YS5jcmwwggHEBgNVHSAEggG7MIIBtzCCAbMGCWCGSAGG/WwDATCCAaQwOgYIKwYB
# BQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9y
# eS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYA
# IAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkA
# dAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAA
# RABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAA
# UgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAA
# dwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4A
# ZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkA
# bgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wgYIGCCsGAQUFBwEBBHYwdDAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEwGCCsGAQUFBzAC
# hkBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURD
# b2RlU2lnbmluZ0NBLTEuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEFBQAD
# ggEBABv8O1PicJ3pbsLtls/jzFKZIG16h2j0eXdsJrGZzx6pBVnXnqvL4ZrF6dgv
# puQWr+lg6wL+Nxi9kJMeNkMBpmaXQtZWuj6lVx23o4k3MQL5/Kn3bcJGpdXNSEHS
# xRkGFyBopLhH2We/0ic30+oja5hCh6Xko9iJBOZodIqe9nITxBjPrKXGUcV4idWj
# +ZJtkOXHZ4ucQ99f7aaM3so30IdbIq/1+jVSkFuCp32fisUOIHiHbl3nR8j20YOw
# ulNn8czlDjdw1Zp/U1kNF2mtZ9xMYI8yOIc2xvrOQQKLYecricrgSMomX54pG6uS
# x5/fRyurC3unlwTqbYqAMQMlhP8wggajMIIFi6ADAgECAhAPqEkGFdcAoL4hdv3F
# 7G29MA0GCSqGSIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0Rp
# Z2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMTAyMTExMjAwMDBaFw0yNjAy
# MTAxMjAwMDBaMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCcfPmgjwrKiUtTmjzsGSJ/DMv3SETQPyJumk/6zt/G0ySR/6hS
# k+dy+PFGhpTFqxf0eH/Ler6QJhx8Uy/lg+e7agUozKAXEUsYIPO3vfLcy7iGQEUf
# T/k5mNM7629ppFwBLrFm6aa43Abero1i/kQngqkDw/7mJguTSXHlOG1O/oBcZ3e1
# 1W9mZJRru4hJaNjR9H4hwebFHsnglrgJlflLnq7MMb1qWkKnxAVHfWAr2aFdvftW
# k+8b/HL53z4y/d0qLDJG2l5jvNC4y0wQNfxQX6xDRHz+hERQtIwqPXQM9HqLckvg
# VrUTtmPpP05JI+cGFvAlqwH4KEHmx9RkO12rAgMBAAGjggNDMIIDPzAOBgNVHQ8B
# Af8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwggHDBgNVHSAEggG6MIIBtjCC
# AbIGCGCGSAGG/WwDMIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2Vy
# dC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6C
# AVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBp
# AGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABh
# AG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBD
# AFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5
# ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABs
# AGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABv
# AHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBj
# AGUALjASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsNC5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMB0GA1UdDgQW
# BBR7aM4pqsAXvkl64eU/1qf3RY81MjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYun
# pyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAe3IdZP+IyDrBt+nnqcSHu9uUkteQ
# WTP6K4feqFuAJT8Tj5uDG3xDxOaM3zk+wxXssNo7ISV7JMFyXbhHkYETRvqcP2pR
# ON60Jcvwq9/FKAFUeRBGJNE4DyahYZBNur0o5j/xxKqb9to1U0/J8j3TbNwj7aqg
# TWcJ8zqAPTz7NkyQ53ak3fI6v1Y1L6JMZejg1NrRx8iRai0jTzc7GZQY1NWcEDzV
# sRwZ/4/Ia5ue+K6cmZZ40c2cURVbQiZyWo0KSiOSQOiG3iLCkzrUm2im3yl/Brk8
# Dr2fxIacgkdCcTKGCZlyCXlLnXFp9UH/fzl3ZPGEjb6LHrJ9aKOlkLEM/zGCBDQw
# ggQwAgEBMIGDMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTECEANLUPI8pQAAS91jSo3Y0QUwCQYF
# Kw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkD
# MQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJ
# KoZIhvcNAQkEMRYEFGmv9p2tthJrQD4SGjJGk4c7OIlQMA0GCSqGSIb3DQEBAQUA
# BIIBAG59kLMmlU44ImDvlOWqqq5R+ieWUEi+OnY2Lfl2WWHhZt/xu5oZpdC8MJR0
# 1iaZHvZ8eifq9TdZOQIOsKKp32CZsZJzSiq0W7s7H00/lw/aiZAPkozKF3JvWuoa
# 8y7N8rns6ZvYvph0T9fhh83orfP6oEemehyABgr2rT7zLjr5ofOICcj5/ppYm6RW
# H0J0GUg+BOn3k5YxVmLSNqT/orgs5JrUrgzEBEsom4YtWrO3IoIspjpeVB8yWd4M
# C3bWIkYBuwD0/SKDogiWBn0HhKtOHKACatLyfUmgYBPEBaZndCQLMnfdx/f2zFhm
# MR+zFuZQS0tFBqgpQLnH9SRiYWqhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQC
# AQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0Eg
# LSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNjEwMDQzMjU3WjAjBgkq
# hkiG9w0BCQQxFgQUPvuvMcWvf2OAAxDe7BRf+Z81nYMwDQYJKoZIhvcNAQEBBQAE
# ggEAWCwtujTvDtzPxACeljyn8Q3pA5UWWhYDsqDQAJQts2XYEWEiSrNuDngyg2Zc
# xhK6qi2lRhe60gPrOXRtNMVHnye1FJza8+ny0uLikMEO8ZgtdydjGg5ezGfzm2g+
# AIqfpHlPD+/7nN2qpcb4pxAX7MCcdrRgPpm99se10ymDaNwNssPv0+5RidRgvfiM
# MDBcY9pNrKq2VBn7cFfauHduuTeHd5kmE/o/DehnJ2LcJ5mpGJ2FSGUU2ZK6nppR
# DIcEz2vvJEgRfOdUp+/pfMh48P6A+naUQduO1t9kRTEI7RVbZNpYDwY+wAREBw1O
# ijZnRTcdx4TH3r7mhbpuNTUtoA==
# SIG # End signature block
