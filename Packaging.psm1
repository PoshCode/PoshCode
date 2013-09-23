#Requires -Version 3 -Modules Installation
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

# Cache the compiled code as Packaging.dll
if(!(Test-Path "$PSScriptRoot\Packaging.dll") -or $LastDate -gt (Get-Item "$PSScriptRoot\Packaging.dll").LastWriteTime) {
  Add-Type -Path $SourceFiles -ReferencedAssemblies System.Xaml -OutputAssembly "$PSScriptRoot\Packaging.dll" -Passthru
} else {
  Add-Type -Path "$PSScriptRoot\Packaging.dll" -Passthru
}

function New-Module {
   <#
      .Synopsis
         Generate a new module from some script files
      .Description
         New-Module serves two ways of creating modules, but in either case, it can generate the psd1 and psm1 necessary for a module based on script files.
         
         In one use case, it's just a simplified wrapper for New-ModuleManifest which answers some of the parameters based on the files already in the module folder.
         
         In the second use case, it allows you to collect one or more scripts and put them into a new module folder.
      .Example
         New-Module FileUtilities *.ps1 -Author "Joel Bennett" -Description "My collection of file utility functions"
         
         This example shows the recommended way to run the New-Module cmdlet, providing a full Author name, and a real description. It collecta all the script files in the present working directory and generates a new module "MyUtility" ...
      .Example
         New-Module MyUtility *.ps1 -recurse 
         
         This example shows how to collect all the script files in the folder and it's subfolders to recursively generate a new module "MyUtility" with the default values for everything else.
      .Example
         New-Module ~\Documents\WindowsPowerShell\Modules\MyUtility -Upgrade
      
         This example shows how to (re)generate the MyUtility module from all the files that have already been moved to that folder. 
         If you use the first example to generate a module, and then you add some files to it, this is the simplest way to update it after adding new script files.  However, you can also create the module and move files there by hand, and then call this command-line to generate the psd1 and psm1 files...
      
         Note: the Upgrade parameter keeps the module GUID, increments the ModuleVersion, updates the FileList, TypesToProcess, FormatsToProcess, and NestedModules from the files in the directory, and overwrites the convention-based values: RootModule, FunctionsToExport, AliasesToExport, VariablesToExport, and CmdletsToExport.  You may provide additional parameters (like AuthorName) and overwrite those as well.
      .Example
         Get-ChildItem *.ps1,*.psd1 -Recurse | New-Module MyUtility
         
         This example shows how to pipe the files into the New-Module, and yet another approach to collecting the files needed.
   #>
   [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium", DefaultParameterSetName="NewModuleManifest")]
   param(
      # If set, overwrites existing modules without prompting
      [Switch]$Force,

      # If set, appends to (increments) existing modules without prompting.
      # THe Updgrade switch will leave any customizations to your module in place:
      # * It doesn't alter the psm1 (but will create one if it's missing)
      # * It only changes the manifest module version, and any explicitly set parameters
      [Switch]$Upgrade,

      # The name of the module to create
      [Parameter(Position=0, Mandatory=$true)]
      [ValidateScript({if($_ -match "[$([regex]::Escape(([io.path]::GetInvalidFileNameChars() -join '')))]") { throw "The ModuleName must be a valid folder name. The character '$($matches[0])' is not valid in a Module name."} else { $true } })]
      $ModuleName,

      # The script files to put in the module. Should be .ps1 files (but could be .psm1 too)
      [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="OverwriteModule")]
      [Alias("PSPath")]
      $Path,

      # Supports recursively searching for File
      [Switch]$Recurse,

      # If set, enforces the allowed verb names on function exports
      [Switch]$StrictVerbs,

      # The name of the author to use for the psd1 and copyright statement
      [PSDefaultValue(Help = {"Env:UserName: (${Env:UserName})"})]
      [String]$Author = $Env:UserName,

      # A short description of the contents of the module.
      [Parameter(Position=1)]
      [PSDefaultValue(Help = {"'A collection of script files by ${Env:UserName}' (uses the value from the Author parmeter)"})]
      [string]${Description} = "A collection of script files by $Author",

      # The vresion of the module 
      # (This is a passthru for New-ModuleManifest)
      [Parameter()]
      [PSDefaultValue(Help = "1.0 (when -Upgrade is set, increments the existing value to the nearest major version number)")]
      [Alias("Version","MV")]
      [Version]${ModuleVersion} = "1.0",

      # (This is a passthru for New-ModuleManifest)
      [AllowEmptyString()]
      [String]$CompanyName = "None (Personal Module)",

      # Specifies the minimum version of the Common Language Runtime (CLR) of the Microsoft .NET Framework that the module requires (Should be 2.0 or 4.0). Defaults to the (rounded) currently available ClrVersion.
      # (This is a passthru for New-ModuleManifest)
      [version]
      [PSDefaultValue(Help = {"Your current CLRVersion number (rounded): ($($PSVersionTable.CLRVersion.ToString(2)))"})]
      ${ClrVersion} = $($PSVersionTable.CLRVersion.ToString(2)),

      # Specifies the minimum version of Windows PowerShell that will work with this module. Defaults to 1 less than your current version.
      # (This is a passthru for New-ModuleManifest)
      [version]
      [PSDefaultValue(Help = {"Your current PSVersion number (rounded): ($($PSVersionTable.PSVersion.ToString(2))"})]
      [Alias("PSV")]
      ${PowerShellVersion} = $("{0:F1}" -f (([Double]$PSVersionTable.PSVersion.ToString(2)) - 1.0)),
      
      # Specifies modules that this module requires. (This is a passthru for New-ModuleManifest)
      [System.Object[]]
      [Alias("Modules","RM")]
      ${RequiredModules} = $null,
      
      # Specifies the assembly (.dll) files that the module requires. (This is a passthru for New-ModuleManifest)
      [AllowEmptyCollection()]
      [string[]]
      [Alias("Assemblies","RA")]
      ${RequiredAssemblies} = $null
   )

   begin {
      # Make sure ModuleName isn't really a path ;)
      if(Test-Path $ModuleName -Type Container) {
         [String]$ModulePath = Resolve-Path $ModuleName
      } else {
         if(!$ModuleName.Contains([io.path]::DirectorySeparatorChar) -and !$ModuleName.Contains([io.path]::AltDirectorySeparatorChar)) {
            [String]$ModulePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules\$ModuleName"
         } else {
            [String]$ModulePath = $ModuleName
         }
      }
      [String]$ModuleName = Split-Path $ModuleName -Leaf

      # If they passed in the File(s) as a parameter
      if($Path) {
         $Path = switch($Path) {
            {$_ -is [String]} { 
               if(Test-Path $_) {
                  Get-ChildItem $_ -Recurse:$Recurse | % { $_.FullName }
               } else { throw "Can't find the file '$_' doesn't exist." }
            }
            {$_ -is [IO.FileSystemInfo]} { $_.FullName }
            default { Write-Warning $_.GetType().FullName + " type not supported for `$Path" }
         }
      }

      $ScriptFiles = @()
   }

   process {
      $ScriptFiles += switch($Path){
         {$_ -is [String]} { 
            if(Test-Path $_) {
               Resolve-Path $_ | % { $_.ProviderPath }
            } else { throw "Can't find the file '$_' doesn't exist." }
         }
         {$_ -is [IO.FileSystemInfo]} { $_.FullName }
         {$_ -eq $null}{ } # Older PowerShell version had issues with empty paths
         default { Write-Warning $_.GetType().FullName + " type not supported for `$Path" }
      }
   }

   end {
      # If there are errors in here, we need to stop before we really mess something up.
      $ErrorActionPreference = "Stop"

      # We support either generating a module from an existing module folder, 
      # or generating a module from loose files (but not both)
      if($ScriptFiles) {
         # We have script files, so let's make sure the folder is empty and then put our files in it
         if(!$Upgrade -and (Test-Path $ModulePath)) {
            if($Force -Or $PSCmdlet.ShouldContinue("The specified Module already exists: '$ModulePath'. Do you want to delete it and start over?", "Deleting '$ModulePath'")) {
               Remove-Item $ModulePath -recurse
            } else {
               throw "The specified ModuleName '$ModuleName' already exists in '$ModulePath'. Please choose a new name, or specify -Force to overwrite that folder."
            }
         }

         if(!$Upgrade -or !(Test-Path $ModulePath)) {
            try {
               $null = New-Item -Type Directory $ModulePath
            } catch [Exception]{
               Write-Error "Cannot create Module Directory: '$ModulePath' $_"
            }
         }

         # Copy the files into the ModulePath, recreate directory paths where necessary
         foreach($file in Get-Item $ScriptFiles | Where { !$_.PSIsContainer }) {
            $Destination = Join-Path $ModulePath (Resolve-Path $file -Relative )
            if(!(Test-Path (Split-Path $Destination))) {
               $null = New-Item -Type Directory (Split-Path $Destination)
            }
            Copy-Item $file $Destination
         }
      }

      # We need to run the rest of this (especially the New-ModuleManifest stuff) from the ModulePath
      Push-Location $ModulePath

      try {
         # Create the RootModule if it doesn't exist yet
         if(!$Upgrade -Or !(Test-Path "${ModuleName}.psm1")) {
            if($Force -Or !(Test-Path "${ModuleName}.psm1") -or $PSCmdlet.ShouldContinue("The specified '${ModuleName}.psm1' already exists in '$ModulePath'. Do you want to overwrite it?", "Creating new '${ModuleName}.psm1'")) {
               Set-Content "${ModuleName}.psm1" 'Push-Location $PSScriptRoot' +
                  'Import-LocalizedData -BindingVariable ModuleManifest' +
                  '$ModuleManifest.FileList -like "*.ps1" | % {' +
                  '    $Script = Resolve-Path $_ -Relative' +
                  '    Write-Verbose "Loading $Script"' +
                  '    . $Script' +
                  '}' +
                  'Pop-Location'
            } else {
               throw "The specified Module '${ModuleName}.psm1' already exists in '$ModulePath'. Please create a new Module, or specify -Force to overwrite the existing one."
            }
         }

         if($Force -Or $Upgrade -or !(Test-Path "${ModuleName}.psd1") -or $PSCmdlet.ShouldContinue("The specified '${ModuleName}.psd1' already exists in '$ModulePath'. Do you want to update it?", "Creating new '${ModuleName}.psd1'")) {
            if($Upgrade -and (Test-Path "${ModuleName}.psd1")) {
               Import-LocalizedData -BindingVariable ModuleInfo -File "${ModuleName}.psd1" -BaseDirectory $ModulePath
            } else {
               # If there's no upgrade, then we want to use all the parameter (default) values, not just the PSBoundParameters:
               $ModuleInfo = @{
                  # ModuleVersion is special, because it will get incremented
                  ModuleVersion = 0.0
                  Author = $Author
                  Description = $Description
                  CompanyName = $CompanyName
                  ClrVersion = $ClrVersion
                  PowerShellVersion = $PowerShellVersion
                  RequiredModules = $RequiredModules
                  RequiredAssemblies = $RequiredAssemblies
               }
            }

            # We'll list all the files in the module
            $FileList = Get-ChildItem -Recurse | Where { !$_.PSIsContainer } | Resolve-Path -Relative

            $verbs = if($Strict){ Get-Verb | % { $_.Verb +"-*" } } else { "*-*" }

            $ModuleVersion = [Math]::Floor(1.0 + $ModuleInfo.ModuleVersion).ToString("F1")
            # Overwrite existing values with the new truth ;)
            $ModuleInfo.Path = Resolve-Path "${ModuleName}.psd1"
            $ModuleInfo.RootModule = "${ModuleName}.psm1"
            $ModuleInfo.ModuleVersion = $ModuleVersion
            $ModuleInfo.FileList = $FileList
            $ModuleInfo.TypesToProcess = $FileList -match ".*Types?\.ps1xml"
            $ModuleInfo.FormatsToProcess = $FileList -match ".*Formats?\.ps1xml"
            $ModuleInfo.NestedModules = $FileList -like "*.psm1" -notlike "*${ModuleName}.psm1"
            $ModuleInfo.FunctionsToExport = $Verbs
            $ModuleInfo.AliasesToExport = "*"
            $ModuleInfo.VariablesToExport = "${ModuleName}*"
            $ModuleInfo.CmdletsToExport = $Null

            # Overwrite defaults and upgrade values with specified values (if any)
            $null = $PSBoundParameters.Remove("Path")
            $null = $PSBoundParameters.Remove("Force")
            $null = $PSBoundParameters.Remove("Upgrade")
            $null = $PSBoundParameters.Remove("Recurse")
            $null = $PSBoundParameters.Remove("ModuleName")
            foreach($key in $PSBoundParameters.Keys) {
               $ModuleInfo.$key = $PSBoundParameters.$key
            }

            New-ModuleManifest @ModuleInfo
            Get-Item $ModulePath
         }  else {
            throw "The specified Module Manifest '${ModuleName}.psd1' already exists in '$ModulePath'. Please create a new Module, or specify -Force to overwrite the existing one."
         }

         if($Force -Or !(Test-Path "package.psd1")) {
            Set-Content "package.psd1" '@{' +
               "   ModuleName     = `"${ModuleName}`"" +
               "   ModuleVersion  = `"${ModuleVersion}`"" +
               '   ' +
               '   # The address for a website about this module (or your website, as author)' +
               '   HomePageUri   = ""' +
               '   ' +
               '   # A relative path to a license file, or the url to a license, like http://opensource.org/licenses/MIT' +
               '   LicenseUri    = ""' +
               '   ' +
               '   # The web address where this psd1 file will be uploaded' +
               '   ModuleInfoUri = ""' +
               '   ' +
               '   # The web address where the psmx package file will be uploaded' +
               '   PackageUri    = ""' +
               '   ' +
               '   # This version number is here so users can check for the latest version' +
               '   # It should be incremented with each package, and should match the one in your module psd1.' +
               '   ModuleVersion = "2.0.0.6"' +
               '}'
         }         
      } catch {
         throw
      } finally {
         Pop-Location
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
         try {
            $Module = Get-Module $ModuleName | Select-Object -First 1
         } catch {
            $Module = Get-Module $ModuleName -ListAvailable | Select-Object -First 1
         }
      }
      $ModuleInfo = Get-ModuleInfo $Module.Name | Select-Object -First 1

      Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Validating Inputs" -Id 0    

      # If the Module.Path isn't a PSD1, then there is none, so we can't package this module
      if( $Module -isnot [System.Management.Automation.PSModuleInfo] -and [IO.Path]::GetExtension($Module.Path) -ne ".psd1" ) {
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
   
      # .psmx
      if(!$OutputPath.EndsWith($ModulePackageExtension)) {
         if(Test-Path $OutputPath -ErrorAction Stop) {
            $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
            $PackageInfoPath = Join-Path $OutputPath "${ModuleInfoFile}"
         }
      } elseif($Piped) {
         $OutputPath = Split-Path $OutputPath
         if(Test-Path $OutputPath -ErrorAction Stop) {
            $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
            $PackageInfoPath = Join-Path $OutputPath "${ModuleInfoFile}"
         }
      }

      if($PSCmdlet.ShouldProcess("Package the module '$($Module.ModuleBase)' to '$PackagePath'", "Package '$($Module.ModuleBase)' to '$PackagePath'?", "Packaging $($Module.Name)" )) {
         if($Force -Or !(Test-Path $PackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$PackagePath' already exists, do you want to replace it?", "Packaging $($Module.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

            # If there's no ModuleInfo file, then we need to *create* one so that we can package this module
            $ModuleInfoPath = Join-Path (Split-Path $Module.Path) $ModuleInfoFile

            if(!(Test-Path $ModuleInfoPath))
            {
               $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.FileNotFoundException "Can't find the Package Manifest File: ${ModuleInfoPath}"), "Manifest Not Found", "ObjectNotFound", $_) )
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

                     ([regex]::Escape($ModuleInfoFile) + '$') {
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
                  $null = $Package.CreateRelationship( $Module.HelpInfoUri, "External", $ModuleHelpInfoType )
               }
               if($Module.ModuleInfoUri) {
                  $null = $Package.CreateRelationship( $Module.ModuleInfoUri, "External", $ModuleReleaseType )
               }
               if($Module.LicenseUri) {
                  $null = $Package.CreateRelationship( $Module.LicenseUri, "External", $ModuleLicenseType )
               }
               if($Module.PackageUri) {
                  $null = $Package.CreateRelationship( $Module.PackageUri, "External", $ModuleReleaseType )
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

# Export-ModuleMember -Function New-ModulePackage,