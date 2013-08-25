########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################
## Configuration.psm1 defines the Get/Set functionality for ConfigData
## It also includes Get-SpecialFolder for resolving special folder paths

# The config file
$ConfigFile = Join-Path $PSScriptRoot ([IO.Path]::GetFileName( [IO.Path]::ChangeExtension($PSScriptRoot, ".ini") ))

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

function Get-ConfigData {
  #.Synopsis
  #   Gets the modulename.ini settings as a hashtable
  #.Description
  #   Parses the non-comment lines in the config file as a simple hashtable, 
  #   parsing it as string data, and replacing {SpecialFolder} paths
  [CmdletBinding()]
  param(
    # A path to a file with FolderPath ini strings in it, or 
    # A string with path names in it like {MyDocuments} and {ProgramFiles}
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [string]$StringData = $Script:ConfigFile
  )
  begin {
    $Names = @([System.Environment+SpecialFolder].GetFields("Public,Static") | ForEach-Object { $_.Name }) + @("PSHome") | Sort-Object

    if(Test-Path $StringData -Type Leaf) {
      $StringData = Get-Content $StringData -Delim ([char]0)
      $StringData = $StringData -replace '(?m)^[#;].*[\r\n]+'
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

      [string[]]$PSModulePaths = $Env:PSModulePath -split ";" | Resolve-Path | Convert-Path

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

Export-ModuleMember -Function Get-SpecialFolder, Get-ConfigData, Set-ConfigData, Test-ConfigData