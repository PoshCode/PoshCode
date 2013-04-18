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
    $Script:ModuleInfoExtension  = ".moduleinfo"
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
            # If they have a ReleaseUri, try that:
            if($RequiredModule.ReleaseUri) {
              Write-Warning "Installing required module $($RequiredModule.Name) from $($RequiredModule.ReleaseUri)"
              Install-ModulePackage $RequiredModule.ReleaseUri $InstallPath
              continue
            } 

            Write-Warning "The module package does not have a ReleaseUri for the required module $($RequiredModule.Name), and there's not a local copy."
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
# SIG # Begin signature block
# MIIarwYJKoZIhvcNAQcCoIIaoDCCGpwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUq9sr7hNWdrZDDzp4mUECZ+VV
# ZV+gghXlMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# KoZIhvcNAQkEMRYEFB71wR2jAtdubF6Qpr30Kk3NS/e8MA0GCSqGSIb3DQEBAQUA
# BIIBAG5AuHiD5Avg8LRFqXm6Dguv9z1IqNaZwvYCCl/u2wapiXdb/aB4g2SL4XRF
# EK8sU/T+21pz/G0s7hrhkvQiEKnN8eaw5B8eGPEbSt9h/bLJ04NUMReT9fILV6G+
# AldwU4a/SpJC+rAt3woPxuUDAxT4RnoRtOBfkfAEXFI0JXok25m/c6NQ3GxjWtLS
# fs+verS/r3zELvLIan/cckIe5n/iECXpjQnwHfz0i+8o48ZC8BIW14I+DQfGrd//
# UiML09nhyR7hHPFg9OLGOpCeCITpXCyIV/zE07zjrz0PoTZ6VsbOH3DBcQTj5dxS
# AidC8zecARXQTwNpMAZwS0IJj5KhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQC
# AQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0Eg
# LSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNDE4MDYzNTM0WjAjBgkq
# hkiG9w0BCQQxFgQU0tHrcw5h7R8Tdc7R+P3jPzbe8wIwDQYJKoZIhvcNAQEBBQAE
# ggEAZdtwCKpN06AaoktQSpOp+30//bd3u9vmo0qRDIOrdW1X4S/NANMGKPTKEZlA
# jWTwpxs8eUIkj5uopFwJEt1cgKDsQdhKzXg8XhLfu5FAHnITVG2LUbDyNnnZldfo
# E7nNtBReV3IXnCors2lH0+tpsN/kjSl98EkVjQvQ4PJRbZy3ZsR/DotqTtpmG7ei
# N6s9Msf3bTO9tZkKSLHtZc1z3q0oRxlPdN27qzt2EqQsYI7YoeR2sCDfU/sEBc/5
# nzJ84v9w3bW84+m8ARBnCM4GrJI9VtZCJsMOFyREvK+bcjB38tgCVsumAy7BqxVp
# 35IfBWCIaWcHkfXFdNLsB+VTnA==
# SIG # End signature block
