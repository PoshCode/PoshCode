########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################
## Configuration.psm1 defines the Get/Set functionality for ConfigData
## It also includes Get-SpecialFolder for resolving special folder paths

# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1

# We're not using Requires because it just gets in the way on PSv2
#!Requires -Modules Metadata
Import-Module $PoshCodeModuleRoot\Metadata.psm1
# FULL # END FULL

$Script:SpecialFolderNames = @([System.Environment+SpecialFolder].GetFields("Public,Static") | ForEach-Object { $_.Name }) + @("PSHome") | Sort-Object

function Get-SpecialFolder {
  #.Synopsis
  #   Gets the current value for a well known special folder
  [CmdletBinding()]
  param(
    # The name of the Path you want to fetch (supports wildcards).
    #  From the list: AdminTools, ApplicationData, CDBurning, CommonAdminTools, CommonApplicationData, CommonDesktopDirectory, CommonDocuments, CommonMusic, CommonOemLinks, CommonPictures, CommonProgramFiles, CommonProgramFilesX86, CommonPrograms, CommonStartMenu, CommonStartup, CommonTemplates, CommonVideos, Cookies, Desktop, DesktopDirectory, Favorites, Fonts, History, InternetCache, LocalApplicationData, LocalizedResources, MyComputer, MyDocuments, MyMusic, MyPictures, MyVideos, NetworkShortcuts, Personal, PrinterShortcuts, ProgramFiles, ProgramFilesX86, Programs, PSHome, Recent, Resources, SendTo, StartMenu, Startup, System, SystemX86, Templates, UserProfile, Windows
    [ValidateScript({
      $Name = $_
      $Names = 
      if($Script:SpecialFolderNames -like $Name) {
        return $true
      } else {
        throw "Cannot convert Path, with value: `"$Name`", to type `"System.Environment+SpecialFolder`": Error: `"The identifier name $Name is not one of $($Script:SpecialFolderNames -join ', ')"
      }
    })]
    [String]$Path = "*",

    # If not set, returns a hashtable of folder names to paths
    [Switch]$Value
  )

  $Names = $Script:SpecialFolderNames -like $Path
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
      #  Suppress error when running in remote sessions by making sure $PROFILE is defined
      if(!$PROFILE) { $PROFILE = Join-Path (Get-SpecialFolder MyDocuments) "WindowsPowerShell\Profile.ps1" }
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

# FULL # BEGIN FULL: These cmdlets are only necessary in the full version of the module
function Get-ConfigData {
  #.Synopsis
  #   Gets the UserSettings.pds settings as a hashtable
  #.Description
  #   Parses the non-comment lines in the config file as a simple hashtable, 
  #   parsing it as string data, and replacing {SpecialFolder} paths
  [CmdletBinding(DefaultParameterSetname="FromFile")]
  param()
  end {
    $Results = Import-LocalStorage $PSScriptRoot UserSettings.psd1

    # Our ConfigData has InstallPaths which may use tokens:
    foreach($Key in $($Results.InstallPaths.Keys)) {
      $Results.InstallPaths.$Key = $(
        foreach($StringData in @($Results.InstallPaths.$Key)) {
          $Paths = [Regex]::Matches($StringData, "{(?:$($Script:SpecialFolderNames -Join "|"))}")
          for($i = $Paths.Count - 1; $i -ge 0; $i--) {
            if($Path = Get-SpecialFolder $Paths[$i].Value.Trim("{}") -Value) {
              $StringData = $StringData.Remove($Paths[$i].Index,$Paths[$i].Length).Insert($Paths[$i].Index, $Path)
              break
            }
          }
          $StringData
        }
      )
    }

    # Our ConfigData has Repositories which may use tokens in their roots
    # The Repositories has to be an array:
    foreach($Repo in $Results.Repositories.Keys) {
      foreach($Setting in @($Results.Repositories.$Repo.Keys)) {
        $Results.Repositories.$Repo.$Setting = $(
          foreach($StringData in @($Results.Repositories.$Repo.$Setting)) {
            $Paths = [Regex]::Matches($StringData, "{(?:$($Script:SpecialFolderNames -Join "|"))}")
            for($i = $Paths.Count - 1; $i -ge 0; $i--) {
              if($Path = Get-SpecialFolder $Paths[$i].Value.Trim("{}") -Value) {
                $StringData = $StringData.Remove($Paths[$i].Index,$Paths[$i].Length).Insert($Paths[$i].Index, $Path)
                break
              }
            }
            $StringData
          }
        )
      }
    }
    
    return $Results
  }
}

function Set-ConfigData {
  #.Synopsis
  #   Updates the config file with the specified hashtable
  [CmdletBinding()]
  param(
    # The config hashtable to save
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [Hashtable]$ConfigData
  )
  end {
    # When serializing the ConfigData we want to tokenize the path
    # So that it will be user-agnostic
    $table = Get-SpecialFolder
    $table = $table.GetEnumerator() | Sort-Object Value -Descending

    # Our ConfigData has InstallPaths and Repositories
    # We'll explicitly save just those:
    $SaveData = @{ InstallPaths = @{}; Repositories = @{} }

    # Our ConfigData has InstallPaths which may use tokens:
    foreach($Key in $($ConfigData.InstallPaths.Keys)) {
      $SaveData.InstallPaths.$Key = $ConfigData.InstallPaths.$Key
      foreach($kvPath in $table) {
        if($ConfigData.InstallPaths.$Key -like ($kvPath.Value +"*")) {
          $SaveData.InstallPaths.$Key = $ConfigData.InstallPaths.$Key -replace ([regex]::Escape($kvPath.Value)), "{$($kvPath.Key)}"
          break
        }
      }
    }

    # Our ConfigData has Repositories which may use tokens in their roots
    # The Repositories has to be an array:
    foreach($Repo in $ConfigData.Repositories) {
      foreach($Setting in @($ConfigData.Repositories.$Repo.Keys)) {
        foreach($kvPath in $table) {
          if($ConfigData.Repositories.$Repo.$Setting -like ($kvPath.Value +"*")) {
            $ConfigData.Repositories.$Repo.$Setting = $ConfigData.Repositories.$Repo.$Setting -replace ([regex]::Escape($kvPath.Value)), "{$($kvPath.Key)}"
            break
          }
        }
      }
    }


    $ConfigString = "# You can edit this file using the ConfigData commands: Get-ConfigData and Set-ConfigData`n" +
                    "# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder`n" +
                    "# Note that the default InstallPaths here are the ones recommended by Microsoft:`n" +
                    "# http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350`n" +
                    "#`n" +
                    "# Repositories: must a hashtable of hashtables with Type and Root`n" +
                    "#   The keys in the Repositories hashtable are the unique names, which can be used to filter Find-Module`n" +
                    "#   The keys in the nested hashtables MUST include the TYPE and ROOT, and may include additional settings for the Repository's FindModule command`n"

    Export-LocalStorage -Module $PSScriptRoot -Name UserSettings.psd1 -InputObject $ConfigData -CommentHeader $ConfigString
  }
}

function Test-ConfigData {
  #.Synopsis
  #  Validate and configure the module installation paths
  [CmdletBinding()]
  param(
    # A Name=Path hashtable containing the paths you want to use in your configuration
    $ConfigData = $(Get-ConfigData)
  )

  foreach($path in @($ConfigData.InstallPaths.Keys)) {
    $name = $path -replace 'Path$'
    $folder = $ConfigData.$path
    do {
      ## Create the folder, if necessary
      if(!(Test-Path $folder)) {
        Write-Warning "The $name module location does not exist. Please validate:"
        $folder = Read-Host "Press ENTER to accept the current value:`n`t$($ConfigData.$path)`nor type a new path"
        # DO NOT REFACTOR TO IsNullOrWhiteSpace (that's .net 4 only)
        if(!$folder -or ($folder -replace '\s+').Length -eq 0) { $folder = $ConfigData.$path }

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

# These are special functions just for saving in the AppData folder...
function Get-LocalStoragePath {
   #.Synopsis
   #   Gets the LocalApplicationData path for the specified company\module 
   #.Description
   #   Appends Company\Module to the LocalApplicationData, and ensures that the folder exists.
   param(
      # The name of the module you want to access storage for (defaults to SplunkStanzaName)
      [Parameter(Position=0, Mandatory=$true)]
      [ValidateScript({ 
         $invalid = $_.IndexOfAny([IO.Path]::GetInvalidFileNameChars())       
         if($invalid -eq -1){ 
            return $true
         } else {
            throw "Invalid character in Module Name '$_' at $invalid"
         }
      })]         
      [string]$Module,

      # The name of a "company" to use in the storage path (defaults to "PoshCode")
      [Parameter(Position=1)]
      [ValidateScript({ 
         $invalid = $_.IndexOfAny([IO.Path]::GetInvalidFileNameChars())       
         if($invalid -eq -1){ 
            return $true
         } else {
            throw "Invalid character in Company Name '$_' at $invalid"
         }
      })]         
      [string]$Company = "PoshCode"

   )
   end {
      if(!($path = $SplunkCheckpointPath)) {
         $path = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) $Company
      } 
      $path  = Join-Path $path $Module

      if(!(Test-Path $path -PathType Container)) {
         $null = New-Item $path -Type Directory -Force
      }
      Write-Output $path
   }
}

function Get-ScopeStoragePath {
    #.Synopsis
    #   Saves the object to local storage with the specified name
    #.Description
    #   Persists objects to disk using Get-LocalStoragePath and Export-Metadata
    param(
        # A unique valid module name to use when persisting the object to disk
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({ 
            $invalid = "$_".IndexOfAny([IO.Path]::GetInvalidPathChars())       
            if($invalid -eq -1){ 
                return $true
            } else {
                throw "Invalid character in Module Name '$_' at $invalid"
            }
        })]      
        $Module,

        # A unique object name to use when persisting the object to disk
        [Parameter(Mandatory=$true, Position=1)]
        [ValidateScript({ 
            $invalid = $_.IndexOfAny([IO.Path]::GetInvalidFileNameChars())       
            if($invalid -eq -1){ 
                return $true
            } else {
                throw "Invalid character in Object Name '$_' at $invalid"
            }
        })]      
        [string]$Name,

        # The scope to store the data in. Defaults to storing in the ModulePath
        [ValidateSet("Module", "User")]
        $Scope = "Module"
    )
    end {
        $invalid = "$Module".IndexOfAny([IO.Path]::GetInvalidFileNameChars())       
        if(($Scope -ne "User") -and $invalid -and (Test-Path "$Module")) 
        {
            $ModulePath = Resolve-Path $Module
        } 
        elseif($Scope -eq "Module") 
        {
            if($Module -is [System.Management.Automation.PSModuleInfo]) {
                $ModulePath = $Module.ModuleBase
            } else {
                $Module = Split-Path $Module -Leaf
                $ModulePath = Get-ModuleInfo $Module -ListAvailable | Select -Expand ModuleBase -First 1
            }
        }

        # Scope -eq "User"
        if(!$ModulePath -or !(Test-Path $ModulePath)) {
            $Module = Split-Path $Module -Leaf
            $ModulePath = Get-LocalStoragePath $Module
            if(!(Test-Path $ModulePath) -and ($Scope -ne "Module")) {
                $Null = New-Item -ItemType Directory $ModulePath
            }
        }

        if(!(Test-Path $ModulePath)) {
            Write-Error "The folder for storage doesn't exist: $ModulePath"
        }

        # Make sure it has a PSD1 extension
        if($Name -notmatch '.*\.psd1$') {
            $Name = "${Name}.psd1"
        }

        Join-Path $ModulePath $Name
    }
}


function Export-LocalStorage {
   #.Synopsis
   #   Saves the object to local storage with the specified name
   #.Description
   #   Persists objects to disk using Get-LocalStoragePath and Export-Metadata
   param(
      # A unique valid module name to use when persisting the object to disk
      [Parameter(Mandatory=$true, Position=0)]
      [ValidateScript({ 
         $invalid = $_.IndexOfAny([IO.Path]::GetInvalidPathChars())       
         if($invalid -eq -1){ 
            return $true
         } else {
            throw "Invalid character in Module Name '$_' at $invalid"
         }
      })]
      [string]$Module,

      # A unique object name to use when persisting the object to disk
      [Parameter(Mandatory=$true, Position=1)]
      [ValidateScript({ 
         $invalid = $_.IndexOfAny([IO.Path]::GetInvalidFileNameChars())       
         if($invalid -eq -1){ 
            return $true
         } else {
            throw "Invalid character in Object Name '$_' at $invalid"
         }
      })]      
      [string]$Name,

      # The scope to store the data in. Defaults to storing in the ModulePath
      [ValidateSet("Module", "User")]
      $Scope,

      # comments to place on the top of the file (to explain it's settings)
      [string[]]$CommentHeader,

      # The object to persist to disk
      [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=10)]
      $InputObject
   )
   begin {
      if($PSBoundParameters.ContainsKey("InputObject")) {
         $null = $PSBoundParameters.Remove("InputObject")
         $Path = Get-ScopeStoragePath @PSBoundParameters
         Write-Verbose "Clean Export"
         Export-Metadata -Path $Path -InputObject $InputObject -CommentHeader $CommentHeader
         $Output = $null
      } else {
         $Output = @()
         $Path = Get-ScopeStoragePath @PSBoundParameters
      }
   }
   process {
    if($Output) {
      $Output += $InputObject
    }
   }
   end {
      if($Output) {
         Write-Verbose "Tail Export"
         # Avoid arrays when they're not needed:
         if($Output.Count -eq 1) { $Output = $Output[0] }
         Export-Metadata -Path $Path -InputObject $Output -CommentHeader $CommentHeader
      }
   }
}

function Import-LocalStorage {
   #.Synopsis
   #   Loads an object with the specified name from local storage 
   #.Description
   #   Retrieves objects from disk using Get-LocalStoragePath and Import-CliXml
   param(
      # A unique valid module name to use when persisting the object to disk
      [Parameter(Mandatory=$true, Position=0)]
      [ValidateScript({ 
         $invalid = $_.IndexOfAny([IO.Path]::GetInvalidPathChars())       
         if($invalid -eq -1){ 
            return $true
         } else {
            throw "Invalid character in Module Name '$_' at $invalid"
         }
      })]
      [string]$Module,

      # A unique object name to use when persisting the object to disk
      [Parameter(Position=1)]
      [ValidateScript({ 
         $invalid = $_.IndexOfAny([IO.Path]::GetInvalidPathChars())       
         if($invalid -eq -1){ 
            return $true
         } else {
            throw "Invalid character in Object Name '$_' at $invalid"
         }
      })]      
      [string]$Name = '*',

      # The scope to store the data in. Defaults to storing in the ModulePath
      [ValidateSet("Module", "User")]
      $Scope,

      # A default value (used in case there's an error importing):
      [Parameter()]
      [Object]$DefaultValue
   )
   end {
      $null = $PSBoundParameters.Remove("DefaultValue")
      if($Name -eq "*") {
        $PSBoundParameters["Name"] = "*" 
      }
      $Path = Get-ScopeStoragePath @PSBoundParameters
      try {
         $Path = Resolve-Path $Path -ErrorAction Stop
         if(@($Path).Count -gt 1) {
            $Output = @{}
            foreach($Name in $Path) {
               $Key = Split-Path $Name -Leaf
               $Output.$Key = Import-Metadata -Path $Name
            }
         } else {
            Import-Metadata -Path $Path
         }
      } catch {
         if($DefaultValue) {
            Write-Output $DefaultValue
         } else {
            throw
         }
      }
   }
}
                              
Export-ModuleMember -Function Get-ScopeStoragePath, Get-LocalStoragePath,
                              Import-LocalStorage, Export-LocalStorage,
                              Get-SpecialFolder, Select-ModulePath, Test-ExecutionPolicy, 
                              Get-ConfigData, Set-ConfigData, Test-ConfigData
# FULL # END FULL
