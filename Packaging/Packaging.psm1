########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################

# We need to make up a URL for the metadata psd1 relationship type
$ModuleMetadataType   = "http://schemas.poshcode.org/package/module-metadata"
$ModuleHelpInfoType   = "http://schemas.poshcode.org/package/help-info"
$PackageThumbnailType = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"
# This is what nuget uses for .nuspec, we use it for .moduleinfo ;)
$ManifestType         = "http://schemas.microsoft.com/packaging/2010/07/manifest"
# I'm not sure there's any benefit to extra types:
# CorePropertiesType is the .psmdcp
$CorePropertiesType   = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
$ModuleRootType       = "http://schemas.poshcode.org/package/module-root"
$ModuleContentType    = "http://schemas.poshcode.org/package/module-file"
# Our Extensions
$ModuleInfoExtension  = ".moduleinfo"
$ModuleManifestExtension = ".psd1"
$ModulePackageExtension = ".psmx"
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
    [ValidateScript({if(!(Test-Path $_ -Type Leaf)){ throw "The OutputPath must be an existing FOLDER path." }})]
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
      $Module = Get-Module $Module -ListAvailable | Select-Object -First 1
    }

    Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Validating Inputs" -Id 0    

    # If the Module.Path isn't a PSD1, then there is none, so we can't package this module
    if( $Module -isnot [System.Management.Automation.PSModuleInfo] -and
        [IO.Path]::GetExtension($Module.Path) -ne ".psd1" ) {
      $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.InvalidDataException "Module metadata file (.psd1) not found for $($PsBoundParameters["Module"])"), "Unexpected Exception", "InvalidResult", $_) )
    }

    # If there's no ModuleInfo file, then we need to *create* one so that we can package this module
    $ModuleInfoPath = [IO.Path]::ChangeExtension($Module.Path, $ModuleInfoExtension)
    if(!(Test-Path $ModuleInfoPath))
    {
      Write-Warning "ModuleInfo file not found, generating from module manifest: $($Module.Path)"
      Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Creating ModuleInfo Metatada File" -Id 0
      # Note: this will prompt for mandatory parameters if they're not provided to New-ModulePackage
      Set-ModuleInfo $Module
      $null = Test-Path $ModuleInfoPath -ErrorAction Stop
    }

    # Our packages are ModuleName.psmx (for now, $ModulePackageExtension = .psmx)
    $PackageName = $Module.Name
    $PackageVersion = $Module.Version
    if(!$OutputPath.EndsWith($ModulePackageExtension)) {
      if(Test-Path $OutputPath -ErrorAction Stop) {
        $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
      }
    } elseif($Piped) {
      $OutputPath = Split-Path $OutputPath
      if(Test-Path $OutputPath -ErrorAction Stop) {
        $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
      }
    }

    if($PSCmdlet.ShouldProcess("Package the module '$($Module.ModuleBase)' to '$PackagePath'", "Package '$($Module.ModuleBase)' to '$PackagePath'?", "Packaging $($Module.Name)" )) {
      if($Force -Or !(Test-Path $PackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$PackagePath' already exists, do you want to replace it?", "Packaging $($Module.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

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
          if($FileList -notcontains $ModuleInfoPath) {
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
              $reader = [IO.File]::Open( $File, "Open", "Read" )
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

          if($Module.HelpInfoUri) {
            $Package.CreateRelationship( $Module.HelpInfoUri, "External", $ModuleHelpInfoType)
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
      $ModulePath = Convert-Path $Module -ErrorAction SilentlyContinue -ErrorVariable noPath
      if($noPath) { $ModulePath = $Module }
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

            $manifest = $Package.GetRelationshipsByType( $ManifestType )
            if(!$manifest) {
              Write-Warning "This Package is invalid, it has not specified the manifest"
              Write-Output $Package.PackageProperties
              return
            }

            $Part = $Package.GetPart( $manifest.TargetUri )
            if(!$manifest) {
              Write-Warning "This Package is invalid, it has no manifest at $($manifest.TargetUri)"
              Write-Output $Package.PackageProperties
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
    [string]
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
    ${ReleaseUri},

    [AllowNull()]
    [string]
    ${ProjectUri},

    [switch]
    ${PassThru},

    [AllowNull()]
    [string]
    ${DefaultCommandPrefix}
  )
  begin {
    $null = $PsBoundParameters.Remove("Module")
    ## And the stupid common parameters:
    if($PsBoundParameters.ContainsKey("Verbose")) {
      $null = $PsBoundParameters.Remove("Verbose")
    }
    $RejectAllOverwrite = $false;
    $ConfirmAllOverwrite = $false;
  }
  end
  {
    $ModuleInfo = Get-ModuleInfo $Module
    $ErrorAction = "Stop"

    if($ModuleInfo.FileList) {
      [string[]]$Files = $ModuleInfo.FileList -replace ("(?i:" + [regex]::Escape((Split-Path $ModuleInfo.ModuleInfoPath)) + "\\?)"), ".\"
      $ModuleInfo.FileList.Clear()
      $ModuleInfo.FileList.AddRange($Files)
    }


    if($PSModuleInfo = Get-Module $Module -ErrorAction SilentlyContinue) {
      if($PSModuleInfo.FileList) {
        [string[]]$Files = $PSModuleInfo.FileList -replace ("(?i:" + [regex]::Escape($PSModuleInfo.ModuleBase) + "\\?)"), ".\"
        $PSModuleInfo.FileList.Clear()
        $PSModuleInfo.FileList.AddRange($Files)
      }
      $PSModuleInfo = [PoshCode.Packaging.ModuleManifest]$PSModuleInfo

      $Properties = $PSModuleInfo.GetType().GetProperties() | 
                      Select-Object -Expand Name | 
                      Where-Object { ($PsBoundParameters.Keys -notcontains $_) -and $PSModuleInfo.$_ }
      foreach($prop in $Properties) {
        if($Interface = $PSModuleInfo.$prop.GetType().GetInterface("System.Collections.Generic.IList``1")) {
          foreach($item in $PSModuleInfo.$prop) {
            if($ModuleInfo.$prop -notcontains $item) {
              if($PSCmdlet.ShouldContinue(
                  "The value '$item' is in the .psd1 manifest. Do you want to add it to the ModuleInfo?",
                  "Updating ModuleInfo '$prop' for $($ModuleInfo.Name)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {
                $ModuleInfo.$prop.Add( ($item -as ($Interface.GenericTypeArguments[0])) )
              }
            }
          }
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

    [Xaml.XamlServices]::Save( $ModuleInfo ) > $ModuleInfo.ModuleInfoPath

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
      Write-Warning "Generating ModuleInfo file: '$($ModuleInfo.ModuleInfoPath)' with new values. Please verify the manifest matches."
      # Call New-ModuleManifest with the ModuleInfo hashtable
      New-ModuleManifest @HashTable -Path $ModuleInfo.ModuleManifestPath
      Write-Host "Updated values:`n$($PsBoundParameters | Out-String)"
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


