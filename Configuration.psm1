########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################
## Configuration.psm1 defines the Get/Set functionality for ConfigData
## It also includes Get-SpecialFolder for resolving special folder paths

# The config file
$Script:ConfigFile = Join-Path $PSScriptRoot ([IO.Path]::GetFileName( [IO.Path]::ChangeExtension($PSScriptRoot, ".ini") ))

function Get-SpecialFolder {
  #.Synopsis
  #   Gets the current value for a well known special folder
  [CmdletBinding()]
  param(
    # The name of the Path you want to fetch (supports wildcards).
    #  From the list: AdminTools, ApplicationData, CDBurning, CommonAdminTools, CommonApplicationData, CommonDesktopDirectory, CommonDocuments, CommonMusic, CommonOemLinks, CommonPictures, CommonProgramFiles, CommonProgramFilesX86, CommonPrograms, CommonStartMenu, CommonStartup, CommonTemplates, CommonVideos, Cookies, Desktop, DesktopDirectory, Favorites, Fonts, History, InternetCache, LocalApplicationData, LocalizedResources, MyComputer, MyDocuments, MyMusic, MyPictures, MyVideos, NetworkShortcuts, Personal, PrinterShortcuts, ProgramFiles, ProgramFilesX86, Programs, PSHome, Recent, Resources, SendTo, StartMenu, Startup, System, SystemX86, Templates, UserProfile, Windows
    [ValidateScript({
      $Name = $_
      $Names = @([System.Environment+SpecialFolder].GetFields("Public,Static") | ForEach-Object { $_.Name }) + @("PSHome") | Sort-Object
      if($Names -like $Name) {
        return $true
      } else {
        throw "Cannot convert Path, with value: `"$Name`", to type `"System.Environment+SpecialFolder`": Error: `"The identifier name $Name cannot be processed due to the inability to differentiate between the following enumerator names: $($Names -join ', ')"
      }
    })]
    [String]$Path = "*",

    # If set, returns a hashtable of folder names to paths
    [Switch]$Value
  )

  $Names = @( [System.Environment+SpecialFolder].GetFields("Public,Static") |
              ForEach-Object { $_.Name }) + @("PSHome") |
                Where-Object { $_ -like $Path } | 
                Sort-Object
  if(!$Value) {
    $return = @{}
  }

  foreach($name in $Names) {
    $result = $(
      if($name -eq "PSHome") {
        $PSHome
      } else {
        [Environment]::GetFolderPath($name)
      }
    )
    if($result) {
      if($Value) {
        Write-Output $result
      } else {
        $return.$name = $result
      }
    }
  }
  if(!$Value) {
    Write-Output $return
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
      [Char]$Letter = "D"
      $default = -1
      $index = -1
      $common = -1
      switch -Wildcard ($Env:PSModulePath -split ";" | ? {$_}) {
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
         "$(Join-Path ([Environment]::GetFolderPath("ProgramFiles")) WindowsPowerShell\Modules*)" {
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription $(if($common -lt 0){"&Common"}elseif($common -lt 1){"C&ommon"}elseif($common -lt 2){"Co&mmon"}else{"Commo&n"}), $_
            $common++
            if($Default -lt 0){$Default = $index}
            continue
         }
         "$(Join-Path ([Environment]::GetFolderPath("ProgramFiles")) Microsoft\Windows\PowerShell\Modules*)" {
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription $(if($common -lt 0){"&Common"}elseif($common -lt 1){"C&ommon"}elseif($common -lt 2){"Co&mmon"}else{"Commo&n"}), $_
            $common++
            if($Default -lt 0){$Default = $index}
            continue
         }
         "$(Join-Path ([Environment]::GetFolderPath("CommonProgramFiles")) Modules)*" {
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription $(if($common -lt 0){"&Common"}elseif($common -lt 1){"C&ommon"}elseif($common -lt 2){"Co&mmon"}else{"Commo&n"}), $_
            $common++
            if($Default -lt 0){$Default = $index}
            continue
         }
         "$(Join-Path ([Environment]::GetFolderPath("CommonDocuments")) Modules)*" {
            $index++
            $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription $(if($common -lt 0){"&Common"}elseif($common -lt 1){"C&ommon"}elseif($common -lt 2){"Co&mmon"}else{"Commo&n"}), $_
            $common++
            if($Default -lt 0){$Default = $index}
            continue
         }
         "$([Environment]::GetFolderPath("MyDocuments"))*" { 
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
      # Let's make sure they have at least one of the "Common" locations:
      if($common -lt 0) {
         $index++
         $ChoicesWithHelp += New-Object System.Management.Automation.Host.ChoiceDescription "&Common", (Join-Path ([Environment]::GetFolderPath("ProgramFiles")) WindowsPowerShell\Modules)
      }
      # And we always offer the "Other" location:
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
               "Choose a Module Folder (use ? to see the full paths)",
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
  } elseif(([Microsoft.PowerShell.ExecutionPolicy]"Unrestricted") -eq $Policy) {
    Write-Host "Your execution policy is $Policy and should be fine. Note that modules flagged as internet may still cause warnings."
  } elseif(([Microsoft.PowerShell.ExecutionPolicy]"RemoteSigned") -contains $Policy) {
    Write-Host "Your execution policy is $Policy and should be fine. Note that modules flagged as internet will not load if they're not signed."
  } 
}

# FULL # BEGIN FULL: This cmdlet is only needed in the full version of the module
function Get-ConfigData {
  #.Synopsis
  #   Gets the modulename.ini settings as a hashtable
  #.Description
  #   Parses the non-comment lines in the config file as a simple hashtable, 
  #   parsing it as string data, and replacing {SpecialFolder} paths
  [CmdletBinding(DefaultParameterSetname="FromFile")]
  param(
    # A path to a file with FolderPath ini strings in it
    [Parameter(ValueFromPipelineByPropertyName=$true, Position=0, ParameterSetName="FromFile")]
    [Alias("PSPath")]
    [string]$ConfigFile = $Script:ConfigFile,

    # A key = value string (optionally, with special folder tokens in it like {MyDocuments} and {ProgramFiles})
    [Parameter(ValueFromPipeline=$true, Mandatory=$true, ParameterSetName="FromData")]
    [string]$StringData
  )
  begin {
    $Names = @([System.Environment+SpecialFolder].GetFields("Public,Static") | ForEach-Object { $_.Name }) + @("PSHome") | Sort-Object

    if($PSCmdlet.ParameterSetName -eq "FromFile") {
      $StringData = Get-Content $ConfigFile -Delim ([char]0) -ErrorAction Stop
      $StringData = $StringData -replace '(?m)^[#;].*[\r\n]+'
    } else {

    }
  }

  process {
    $Paths = [Regex]::Matches($StringData, "{(?:$($Names -Join "|"))}")
    for($i = $Paths.Count - 1; $i -ge 0; $i--) {
      if($Path = Get-SpecialFolder $Paths[$i].Value.Trim("{}") -Value) {
        $StringData = $StringData.Remove($Paths[$i].Index,$Paths[$i].Length).Insert($Paths[$i].Index, $Path)
      }
    }

    ConvertFrom-StringData ($StringData -replace "\\","\\")
  }
}

function Set-ConfigData {
  #.Synopsis
  #   Updates the config file with the specified hashtable
  [CmdletBinding()]
  param(
    # A path to a file with FolderPath ini strings in it, or 
    # A string with path names in it like {MyDocuments} and {ProgramFiles}
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [string]$Path = $Script:ConfigFile,

    # The config hashtable to save
    [Hashtable]$ConfigData
  )

  # When serializing the ConfigData, we want to tokenize the path
  # So that it will be user-agnostic
  $table = Get-SpecialFolder
  $table = $table.GetEnumerator() | Sort-Object Value -Descending

  foreach($setting in @($ConfigData.Keys)) {
    foreach($kvPath in $table) {
      if($ConfigData.$setting -like ($kvPath.Value +"*")) {
        $ConfigData.$setting = $ConfigData.$setting -replace ([regex]::Escape($kvPath.Value)), "{$($kvPath.Key)}"
      }
    }
  }

  $ConfigString = "# You can edit this file using the ConfigData commands: Get-ConfigData and Set-ConfigData`n" +
                  "# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder`n" +
                  "# Note that the defaults here are the ones recommended by Microsoft:`n" +
                  "# http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350%28v=vs.85%29.aspx`n"

  $ConfigString += $(
    foreach($k in $ConfigData.Keys) {
      "{0} = {1}" -f $k, $ConfigData.$k
    }
  ) -join "`n"

  Set-Content $Path $ConfigString  
}

function Test-ConfigData {
  #.Synopsis
  #  Validate and configure the module installation paths
  [CmdletBinding()]
  param(
    # A Name=Path hashtable containing the paths you want to use in your configuration
    $ConfigData = $(Get-ConfigData)
  )

  foreach($path in @($ConfigData.Keys)) {
    $name = $path -replace 'Path$'
    $folder = $ConfigData.$path
    do {
      ## Create the folder, if necessary
      if(!(Test-Path $folder)) {
        Write-Warning "The $name module location does not exist. Please validate:"
        $folder = Read-Host "Press ENTER to accept the current value:`n`t$($ConfigData.$path)`nor type a new path"
        if([string]::IsNullOrWhiteSpace($folder)) { $folder = $ConfigData.$path }

        if(!(Test-Path $folder)) {
          $CP, $ConfirmPreference = $ConfirmPreference, 'Low'
          if($PSCmdlet.ShouldContinue("The folder '$folder' does not exist, do you want to create it?", "Configuring <$name> module location:")) {
            $ConfirmPreference = $CP
            if(!(New-Item $folder -Type Directory -Force -ErrorAction SilentlyContinue -ErrorVariable fail))
            {
              Write-Warning ($fail.Exception.Message + "`nThe $name Location path '$folder' couldn't be created.`n`nYou may need to be elevated.`n`nPlease enter a new path, or press Ctrl+C to give up.")
            }
          }
          $ConfirmPreference = $CP
        }
      }

      ## Note: PSModulePath entries don't necessarily exist
      [string[]]$PSModulePaths = $Env:PSModulePath -split ";" #| Convert-Path -ErrorAction 0

      ## Add it to the PSModulePath, if necessary
      if((Test-Path $folder) -and ($PSModulePaths -notcontains (Convert-Path $folder))) {
        $folder = Convert-Path $folder
        $CP, $ConfirmPreference = $ConfirmPreference, 'Low'
        if($PSCmdlet.ShouldContinue("The folder '$folder' is not in your PSModulePath, do you want to add it?", "Configuring <$name> module location:")) {
          $ConfirmPreference = $CP          
          # Global and System paths need to go in the Machine registry to work properly
          if("Global","System","Common" -contains $name) {
            try {
              $PsMP = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine") + ";" + $Folder
              $PsMP = ($PsMP -split ";" | Where-Object { $_ } | Select-Object -Unique) -Join ";"
              [System.Environment]::SetEnvironmentVariable("PSModulePath",$PsMP,"Machine")
              $Env:PSModulePath = ($PSModulePaths + $folder) -join ";"
            }
            catch [System.Security.SecurityException] 
            {
              Write-Warning ($_.Exception.Message + " The $name path '$folder' couldn't be added to your Local Machine PSModulePath.")
              if($PSCmdlet.ShouldContinue("Do you want to store the path '$folder' in your <User> PSModulePath instead?", "Configuring <$name> module location:")) {
                try {
                  $PsMP = [System.Environment]::GetEnvironmentVariable("PSModulePath", "User") + ";" + $Folder
                  $PsMP = ($PsMP -split ";" | Where-Object { $_ } | Select-Object -Unique) -Join ";"
                  [System.Environment]::SetEnvironmentVariable("PSModulePath", $PsMP, "User")
                  $Env:PSModulePath = ($PSModulePaths + $folder) -join ";"
                  Write-Host "Added '$folder' to your User PSModulePath instead."
                }
                catch [System.Security.SecurityException] 
                {
                  Write-Warning ($_.Exception.Message + " The $name path '$folder' couldn't be permanently added to your User PSModulePath. Adding for this session anyway.")
                  $Env:PSModulePath = ($PSModulePaths + $folder) -join ";"
                }
              }
            }
          } else {
            try {
              $PsMP = [System.Environment]::GetEnvironmentVariable("PSModulePath", "User") + ";" + $Folder
              $PsMP = ($PsMP -split ";" | Where-Object { $_ } | Select-Object -Unique) -Join ";"
              [System.Environment]::SetEnvironmentVariable("PSModulePath", $PsMP, "User")
              $Env:PSModulePath = ($PSModulePaths + $folder) -join ";"
            }
            catch [System.Security.SecurityException] 
            {
              Write-Warning ($_.Exception.Message + " The $name path '$folder' couldn't be permanently added to your User PSModulePath. Adding for this session anyway.")
              $Env:PSModulePath = ($PSModulePaths + $folder) -join ";"
            }
          }
        }
        $ConfirmPreference = $CP
      }
    } while(!(Test-Path $folder))
    $ConfigData.$path = $folder
  }
  # If you pass in a Hashtable, you get a Hashtable back
  if($PSBoundParameters.ContainsKey("ConfigData")) {
    Write-Output $ConfigData
    # Otherwise, we set it back where we got it from!
  } else {
    Set-ConfigData -ConfigData $ConfigData
  }
}
# FULL # END FULL

Export-ModuleMember -Function Get-SpecialFolder, Get-ConfigData, Set-ConfigData, Test-ConfigData, Select-ModulePath, Test-ExecutionPolicy
