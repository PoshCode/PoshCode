.{
  ########################################################################
  ## Copyright (c) 2013 by Joel Bennett, all rights reserved.
  ## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice.
  ########################################################################
  #.Synopsis
  #   Installs the PoshCode Packaging module
  #.Example
  #   iex (iwr http://PoshCode.org/Install).Content
  [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
  param(
    # The path to a package to download
    [Parameter()]
    $Url = "http://PoshCode.org/Modules/Packaging.psmx"
  )
  end {
    # If this code isn't running from a module, then run the install
    if(!$MyInvocation.MyCommand.Module) {
      Write-Progress "Installing Package" -Id 0
      $InstallPath = Select-ModulePath
      $PackageFile = Get-ModulePackage $Url $InstallPath
      Install-ModulePackage $PackageFile $InstallPath -Import
      Test-ExecutionPolicy
    }
  }

  begin {
    Add-Type -Assembly WindowsBase

    # NOTE: these types are needed elsewhere (Packaging Module)
    #       the types and Get-ModulePackage aren't needed for the installer
    #       but they are part of the "packaging light" module, so here they are.
    # We need to make up a URL for the metadata psd1 relationship type
    $Script:ModuleMetadataType   = "http://schemas.poshcode.org/package/module-metadata"
    $Script:ModuleHelpInfoType   = "http://schemas.poshcode.org/package/help-info"
    $Script:PackageThumbnailType = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"
    # This is what nuget uses for .nuspec, we use it for .moduleinfo ;)
    $Script:ManifestType         = "http://schemas.microsoft.com/packaging/2010/07/manifest"
    # I'm not sure there's any benefit to extra types:
    # CorePropertiesType is the .psmdcp
    $Script:CorePropertiesType   = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
    $Script:ModuleRootType       = "http://schemas.poshcode.org/package/module-root"
    $Script:ModuleContentType    = "http://schemas.poshcode.org/package/module-file"
    # Our Extensions
    $Script:ModuleInfoExtension  = ".psdxml"
    $Script:ModuleManifestExtension = ".psd1"
    $Script:ModulePackageExtension = ".psmx"

    function Get-ModulePackage {
      #.Synopsis
      #   Download the module package to a local path
      [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
      param(
        # The path to a package to download
        [Parameter(Position=0)]
        [string]$Url = "http://PoshCode.org/Packaging.psmx",

        # The PSModulePath to install to
        [Parameter(ParameterSetName="InstallPath", Mandatory=$false, Position=1)]
        [Alias("PSModulePath")]
        $InstallPath = $([IO.Path]::GetTempPath()),

        # If set, the module is installed to the Common module path (as specified in Packaging.ini)
        [Parameter(ParameterSetName="CommonPath", Mandatory=$true)]
        [Switch]$Common,

        # If set, the module is installed to the User module path (as specified in Packaging.ini)
        [Parameter(ParameterSetName="UserPath")]
        [Switch]$User
      )

      begin {
        if($PSCmdlet.ParameterSetName -ne "InstallPath") {
          $Config = Get-ConfigData
          switch($PSCmdlet.ParameterSetName){
            "UserPath"   { $InstallPath = $Config.UserPath }
            "CommonPath" { $InstallPath = $Config.CommonPath }
            # "SystemPath" { $InstallPath = $Config.SystemPath }
          }
          $PsBoundParameters.Remove(($PSCmdlet.ParameterSetName + "Path")) | Out-Null
          $PsBoundParameters.Add("InstallPath", $InstallPath) | Out-Null
        }
        Write-Host "ParameterSetName: $($PSCmdlet.ParameterSetName)`nInstallPath: ${InstallPath}`n$($PsBoundParameters|Format-Table -Auto|Out-String)"        
      }
      end {
        ## TODO: Confirm they want to overwrite the file?
        if(Get-Command Packaging\Invoke-Web -ErrorAction SilentlyContinue) {
          Write-Verbose "Using Invoke-Web"
          Packaging\Invoke-Web $Url -OutFile $InstallPath
        } else {
          Write-Verbose "Manual Download (missing Invoke-Web)"
          try {
          # Get the Packaging package from the web

            $Reader = [Net.WebRequest]::Create($Url).GetResponse().GetResponseStream()
            ## TODO: Find the right file name, that's what Invoke-Web would do!
            $PackagePath = Join-Path $InstallPath (Split-Path $Url -Leaf)
            $Writer = [IO.File]::Open($PackagePath, "Create", "Write" )

            Copy-Stream $reader $writer -Activity "Downloading $Url"
            Get-Item $PackagePath
          } catch [Exception] {
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            Write-Error "Could not download package from $Url"
          } finally {
            $Reader.Close()
            $Reader.Dispose()
            if($Writer) {
              $Writer.Close()
              $Writer.Dispose()
            }
          }
        }
      }
    }

    function Install-ModulePackage {
      #.Synopsis
      #   Install a module package to the module 
      [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium", DefaultParameterSetName="UserPath")]
      param(
        # The package file to be installed
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true, Position=0)]
        [Alias("PSPath","PackagePath")]
        $Package,

        # The PSModulePath to install to
        [Parameter(ParameterSetName="InstallPath", Mandatory=$true, Position=1)]
        [Alias("PSModulePath")]
        $InstallPath,

        # If set, the module is installed to the Common module path (as specified in Packaging.ini)
        [Parameter(ParameterSetName="CommonPath", Mandatory=$true)]
        [Switch]$Common,

        # If set, the module is installed to the User module path (as specified in Packaging.ini)
        [Parameter(ParameterSetName="UserPath")]
        [Switch]$User,

        # If set, overwrite existing modules without prompting
        [Switch]$Force,

        # If set, the module is imported immediately after install
        [Switch]$Import,

        # If set, output information about the files as well as the module 
        [Switch]$Passthru
      )
      begin {
        if($PSCmdlet.ParameterSetName -ne "InstallPath") {
          $Config = Get-ConfigData
          switch($PSCmdlet.ParameterSetName){
            "UserPath"   { $InstallPath = $Config.UserPath }
            "CommonPath" { $InstallPath = $Config.CommonPath }
            # "SystemPath" { $InstallPath = $Config.SystemPath }
          }
          $PsBoundParameters.Remove(($PSCmdlet.ParameterSetName + "Path"))
          $PsBoundParameters.Add("InstallPath", $InstallPath)
        }
        if(!(Test-Path variable:RejectAllOverwriteOnInstall)){
          $RejectAllOverwriteOnInstall = $false;
          $ConfirmAllOverwriteOnInstall = $false;
        }
      }
      process {
        if("$Package" -match "^https?://" ) {
          $Package = Get-ModulePackage $Package $InstallPath
        }
        # Open it as a package
        $PackagePath = Resolve-Path $Package -ErrorAction Stop
        $InstallPath = "$InstallPath".TrimEnd("\")

        # Warn them if they're installing in an irregular location
        [string[]]$ModulePaths = $Env:PSModulePath -split ";" | Resolve-Path -ErrorAction SilentlyContinue | Convert-Path -ErrorAction SilentlyContinue
        if(!($ModulePaths -match ([Regex]::Escape((Convert-Path $InstallPath)) + ".*"))) {
          if((Get-PSCallStack | Where-Object{ $_.Command -eq "Install-ModulePackage" }).Count -le 1) {
            Write-Warning "Install path '$InstallPath' is not in yout PSModulePath!"
          }
        }

        # We need to verify the RequiredModules are available, or install them.
        $Manifest = Get-ModuleManifestXml $PackagePath
        if($Manifest."ModuleManifest.RequiredModules") {
          $FailedModules = @()
          foreach($RequiredModule in $Manifest."ModuleManifest.RequiredModules".ModuleId) {
            # If the module is available ... 
            $VPR = "SilentlyContinue"
            $VPR, $VerbosePreference = $VerbosePreference, $VPR
            if($Module = Get-Module -Name $RequiredModule.Name -ListAvailable) {
              $VPR, $VerbosePreference = $VerbosePreference, $VPR
              if($Module = $Module | Where-Object { $_.Version -ge $RequiredModule.Version }) {
                if($Import) {
                  Import-Module -Name $RequiredModule.Name -MinimumVersion
                  continue
                }
              } else {
                Write-Warning "The package $PackagePath requires $($RequiredModule.Version) of the $($RequiredModule.Name) module. Yours is version $($Module.Version). Trying upgrade:"
              }
            } else {
                Write-Warning "The package $PackagePath requires the $($RequiredModule.Name) module. Trying install:"
            }
            # Check for a local copy, maybe we get lucky:
            $Folder = Split-Path $PackagePath
            # Check with and without the version number in the file name:
            if(($RequiredFile = Get-Item (Join-Path $Folder "$($RequiredModule.Name)*$ModulePackageExtension") | 
                                  Sort-Object { [IO.Path]::GetFileNameWithoutExtension($_) } | 
                                  Select-Object -First 1) -and
               (Get-ModuleManifestXml $RequiredFile).Version -ge $RequiredModule.Version)
            {
              Write-Warning "Installing required module $($RequiredModule.Name) from $RequiredFile"
              Install-ModulePackage $RequiredFile $InstallPath
              continue
            } 
            # If they have a ModuleInfoUri, try that:
            if($RequiredModule.ModuleInfoUri) {
              Write-Warning "Installing required module $($RequiredModule.Name) from $($RequiredModule.ModuleInfoUri)"
              Install-ModulePackage $RequiredModule.ModuleInfoUri $InstallPath
              continue
            } 

            Write-Warning "The module package does not have a ModuleInfoUri for the required module $($RequiredModule.Name), and there's not a local copy."
            $FailedModules += $RequiredModule
            continue
          }
          if($FailedModules) {
            Write-Error "Unable to resolve required modules."
            Write-Output $FailedModules
            return # TODO: Should we install anyway? Prompt?
          }
        }

        try {
          $Package = [System.IO.Packaging.Package]::Open( $PackagePath, "Open", "Read" )
          Write-Host ($Package.PackageProperties|Select-Object Title,Version,@{n="Guid";e={$_.Identifier}},Creator,Description, @{n="Package";e={$PackagePath}}|Out-String)

          $ModuleName = $Package.PackageProperties.Title
          if($InstallPath -match ([Regex]::Escape($ModuleName)+'$')) {
            $InstallPath = Split-Path $InstallPath
          }

          if($PSCmdlet.ShouldProcess("Extracting the module '$ModuleName' to '$InstallPath\$ModuleName'", "Extract '$ModuleName' to '$InstallPath\$ModuleName'?", "Installing $($ModuleName)" )) {
            if($Force -Or !(Test-Path "$InstallPath\$ModuleName" -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The module '$InstallPath\$ModuleName' already exists, do you want to replace it?", "Installing $ModuleName", [ref]$ConfirmAllOverwriteOnInstall, [ref]$RejectAllOverwriteOnInstall)) {
              $success = $false
              $null = New-Item -Type Directory -Path "$InstallPath\$ModuleName" -Force -ErrorVariable FailMkDir
              
              ## Handle the error if they asked for -Common and don't have permissions
              if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
                throw "You do not have permission to install a module to '$InstallPath\$ModuleName'. You may need to be elevated."
              }

              foreach($part in $Package.GetParts() | where Uri -match ("^/" + $ModuleName)) {
                $fileSuccess = $false
                # Copy the data to the file system
                try {
                  if(!(Test-Path ($Folder = Split-Path ($File = Join-Path $InstallPath $Part.Uri)) -EA 0) ){
                    $null = New-Item -Type Directory -Path $Folder -Force
                  }
                  Write-Verbose "Unpacking $File"
                  $writer = [IO.File]::Open( $File, "Create", "Write" )
                  $reader = $part.GetStream()

                  Copy-Stream $reader $writer -Activity "Writing $file"
                  $fileSuccess = $true
                } catch [Exception] {
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
                if(!$fileSuccess) { throw "Couldn't unpack to $File."}
                if($Passthru) { Get-Item $file }
              }
            } else { # !Force
              $Import = $false # Don't _EVER_ import if they refuse the install
            }
            $success = $true
          } # ShouldProcess
        } catch [Exception] {
          $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
        } finally {
          $Package.Close()
          $Package.Dispose()
        }
        if(!$success) { throw "Couldn't unpack $ModuleName."}
        if($Import) {
          Import-Module $ModuleName -Passthru:$Passthru
        } else {
          Get-Module $ModuleName
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
        if($Module -is "string") {
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
              Get-ModuleManifestXml $ModulePath |
              Add-Member NoteProperty PackagePath $ModulePath -Passthru |
              Add-Member NoteProperty PSPath ("{0}::{1}" -f $ModulePath.Provider, $ModulePath.ProviderPath) -Passthru
              return 
            }
            default {
              Write-Verbose "Finding Module by Module Name"
              # Hopefully, they've just specified a module name:

              $VPR = "SilentlyContinue"
              $VPR, $VerbosePreference = $VerbosePreference, $VPR
              $Module = Get-Module $ModulePath -ListAvailable | Select-Object -First 1
              $VPR, $VerbosePreference = $VerbosePreference, $VPR
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
            $VPR = "SilentlyContinue"
            $VPR, $VerbosePreference = $VerbosePreference, $VPR
            $Module = Get-Module (Split-Path $ModuleBase -Leaf) -ListAvailable | Where-Object { $_.ModuleBase -eq $ModuleBase }
            $VPR, $VerbosePreference = $VerbosePreference, $VPR
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
          $ModuleInfo = ([xml](gc $ModuleInfoPath)).ModuleManifest | 
                          Add-Member NoteProperty ModuleInfoPath $ModuleInfoPath -Passthru | 
                          Add-Member NoteProperty ModuleManifestPath $ModuleManifestPath -Passthru
          Write-Output $ModuleInfo
        }
        elseif($Module) 
        {
          Write-Verbose "Write out PSModuleInfo"
          Write-Output ($Module | 
                          Add-Member NoteProperty ModuleInfoPath $ModuleInfoPath -Passthru | 
                          Add-Member NoteProperty ModuleManifestPath $ModuleManifestPath -Passthru)
        } 
        else 
        {
          throw "Unable to get ModuleInfo"
        }
      }
    }

    function Get-ModuleManifestXml {
      param( 
        $ModulePath 
      )
      end {
        try {
          $Package = [System.IO.Packaging.Package]::Open( (Convert-Path $ModulePath), [IO.FileMode]::Open, [System.IO.FileAccess]::Read )

          $Manifest = @($Package.GetRelationshipsByType( $ManifestType ))[0]
          if(!$Manifest -or !$Manifest.TargetUri) {
            Write-Warning "This Package is invalid, it has not specified the manifest"
            Write-Output $Package.PackageProperties
            return
          }

          $Part = $Package.GetPart( $Manifest.TargetUri )
          if(!$Part) {
            Write-Warning "This Package is invalid, it has no manifest at $($Manifest.TargetUri)"
            Write-Output $Package.PackageProperties
            return
          }

          try {
            $stream = $part.GetStream()
            $reader = New-Object System.IO.StreamReader $stream
            # This gets the ModuleInfo
            ([xml]$reader.ReadToEnd()).ModuleManifest
          } catch [Exception] {
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
          } finally {
            if($reader) {
              $reader.Close()
              $reader.Dispose()
            }
            if($stream) {
              $stream.Close()
              $stream.Dispose()
            }
          }

        } catch [Exception] {
          $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
        } finally {
          $Package.Close()
          $Package.Dispose()
        }
      }
    }


    ##### Private functions ######
    function Copy-Stream {
      #.Synopsis
      #   Copies data from one stream to another
      param(
        # The source stream to read from
        [IO.Stream]
        $reader,

        # The destination stream to write to
        [IO.Stream]
        $writer,

        [string]$Activity = "File Packing",

        [Int]
        $Length = 0
      )
      end {
        $bufferSize = 0x1000 
        [byte[]]$buffer = new-object byte[] $bufferSize
        [int]$sofar = [int]$count = 0
        while(($count = $reader.Read($buffer, 0, $bufferSize)) -gt 0)
        {
          $writer.Write($buffer, 0, $count);

          $sofar += $count
          if($Length -gt 0) {
             Write-Progress -Activity $Activity  -Status "Copied $sofar of $Length" -ParentId 0 -Id 1 -PercentComplete (($sofar/$Length)*100)
          } else {
             Write-Progress -Activity $Activity  -Status "Copied $sofar bytes..." -ParentId 0 -Id 1
          }
        }
        Write-Progress -Activity "File Packing" -ParentId 0 -Id 1 -Complete
      }
    }

    function Select-ModulePath {
      #.Synopsis
      #   Interactively choose (and validate) a folder from the Env:PSModulePath
      [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
      param(
        # The folder to install to. This folder should be one of the ones in the PSModulePath, NOT a subfolder.
        $InstallPath
      )
      end {
        $ChoicesWithHelp = @()
        [Char]$Letter = "A"
        $default = -1
        $index = -1
        switch -Wildcard ($Env:PSModulePath -split ";") {
          "${PSHome}*" {
            ##### We do not support installing to the System location. #####
            #$index++
            #$ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "S&ystem", $_
            continue
          }
          "$(Split-Path $PROFILE)*" {
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "&Profile", $_
            $default = $index
            continue
          }
          "$([Environment]::GetFolderPath("CommonProgramFiles"))\Modules*" {
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "&Common", $_
            if($Default -lt 0){$Default = $index}
            continue
          }          
          "$([Environment]::GetFolderPath("MyDocuments"))\*" { 
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "&MyDocuments", $_
            if($Default -lt 0){$Default = $index}
            continue
          }
          default {
            $index++
            $Key = $_ -replace [regex]::Escape($Env:USERPROFILE),'~' -replace "((?:[^\\]*\\){2}).+((?:[^\\]*\\){2})",'$1...$2'
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "&$Letter $Key", $_
            $Letter = 1 + $Letter
            continue
          }
        }
        $index++
        $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "&Other", "Type in your own path!"

        while(!$InstallPath -or !(Test-Path $InstallPath)) {
          if($InstallPath -and !(Test-Path $InstallPath)){
            if($PSCmdlet.ShouldProcess(
              "Verifying module install path '$InstallPath'", 
              "Create folder '$InstallPath'?", 
              "Creating Module Install Path" )) {

              $null = New-Item -Type Directory -Path $InstallPath -Force -ErrorVariable FailMkDir
            
              ## Handle the error if they asked for -Common and don't have permissions
              if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
                Write-Warning "You do not have permission to install a module to '$InstallPath\$ModuleName'. You may need to be elevated. (Press Ctrl+C to cancel)"
              } 
            }
          }

          if(!$InstallPath -or !(Test-Path $InstallPath)){
            $Answer = $Host.UI.PromptForChoice(
              "Please choose an install path.",
              "Choose a Module Folder (use ? to see full paths)",
              ([System.Management.Automation.Host.ChoiceDescription[]]$ChoicesWithHelp),
              $Default)

            if($Answer -ge $index) {
              $InstallPath = Read-Host ("You should pick a path that's already in your PSModulePath. " + 
                                        "To choose again, press Enter.`n" +
                                        "Otherwise, type the path for a 'Modules' folder you want to create")
            } else {
              $InstallPath = $ChoicesWithHelp[$Answer].HelpMessage
            }
          }
        }

        return $InstallPath
      }
    }

    function Test-ExecutionPolicy {
      #.Synopsis
      #   Validate the ExecutionPolicy
      param()

      $Policy = Get-ExecutionPolicy
      if(([Microsoft.PowerShell.ExecutionPolicy[]]"Restricted","Default") -contains $Policy) {
        $Warning = "Your execution policy is $Policy, so you will not be able import script modules."
      } elseif(([Microsoft.PowerShell.ExecutionPolicy[]]"Unrestricted","RemoteSigned") -contains $Policy) {
        $Warning = "Your execution policy is $Policy, if modules are flagged as internet, you'll be warned before importing them."
      } elseif(([Microsoft.PowerShell.ExecutionPolicy[]]"AllSigned") -eq $Policy) {
        $Warning = "Your execution policy is $Policy, if modules are not signed, you won't be able to import them."
      }
      if($Warning) {
        Write-Warning ("$Warning`n" +
            "You may want to change your execution policy to RemoteSigned, Unrestricted or even Bypass.`n" +
            "`n" +
            "        PS> Set-ExecutionPolicy RemoteSigned`n" +
            "`n" +
            "For more information, read about execution policies by executing:`n" +
            "        `n" +
            "        PS> Get-Help about_execution_policies`n")
      }
    }
  } 
}

Export-ModuleMember -Function * -Alias * -Variable *