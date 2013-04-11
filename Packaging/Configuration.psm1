function Test-ExecutionPolicy {
  #.Synopsis
  #   Validate the ExecutionPolicy
  param()

  $Policy = Get-ExecutionPolicy
  if(([Microsoft.PowerShell.ExecutionPolicy[]]"Restricted","Default") -contains $Policy) {
    $Warning = "Your execution policy is $Policy, so you will not be able import script modules."
  } elseif(([Microsoft.PowerShell.ExecutionPolicy[]]"Unrestricted","RemoteSigned") -contains $Policy) {
    $Warning = "Your execution policy is $Policy, if modules are flagged as internet, you won't be able to import them."
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

  $ConfigString = "# You can edit this file using the Packaging commands:`n" +
                  "# Get-ConfigData and Set-ConfigData or using Update-Config`n" +
                  "# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder`n"

  $ConfigString += $(
    foreach($k in $ConfigData.Keys) {
      "{0} = {1}" -f $k, $ConfigData.$k
    }
  ) -join "`n"

  Set-Content $Path $ConfigString  
}

function Update-Config {
  #.Synopsis
  #  Validate and configure the module installation paths
  [CmdletBinding()]param()

  $PSModulePaths = $Env:PSModulePath -split ";" | Resolve-Path | Convert-Path

  Write-Host ("The Environment Variable `"PSModulePath`" controls which folders are searched for installed modules.`n" +
              "By default, it includes two locations: The reserved `"System`" location, and the `"User`" location.`n" +
              "The PoshCode Packaging module adds a third `"Common`" location based on Microsoft's recommendations.`n" +
              "Yours may be customized. Here are the folders in your current PSModulePath:")

  Write-Host "`n$($PSModulePaths -Join "`n")`n" -Foreground Yellow -Background Black

  Write-Host -NoNewLine "* The System Location:"
  Write-Host -Foreground Red "$PSHome\Modules"
  Write-Host "This location is reserved by Microsoft for the built-in modules which ship with Windows.`n`n"

  Write-Host "These are the locations used by PoshCode Packaging:`n"

  Write-Host -NoNewLine "* The User Location:"
  Write-Host -Foreground Red "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Modules"
  Write-Host "This is the default location, all modules will be installed here unless otherwise specified.`n`n"

  Write-Host -NoNewLine "* The Common Location:"
  Write-Host -Foreground Red "$([Environment]::GetFolderPath("CommonProgramFiles"))\Modules"
  Write-Host "This location is recommended for modules which can be shared by all users."
  Write-Host "When installing modules with Install-ModulePackage, you can use the -Common switch to install here.`n`n"

  Write-Host ("You will now be allowed to customize those locations.`n" +
              "If you enter folders which do not exist, we will attempt to create them.`n" +
              "If you enter folders which are not already in your PSModulePath, we will attempt to add them.`n")

  $null = Read-Host "Press ENTER to continue..."

  $Paths = Get-ConfigData

  foreach($path in @($Paths.Keys)) {
    $name = $path -replace 'Path$'

    do {
      $folder = Read-Host "`nConfiguring $name module location:`nPress ENTER to accept the current value:`n`t$($Paths.$path)`nor type a new path"
      if([string]::IsNullOrWhiteSpace($folder)) {
        $folder = $Paths.$path
      }

      ## Create the folder, if necessary
      if(!(Test-Path $folder)){
        $CP, $ConfirmPreference = $ConfirmPreference, 'Low'
        if($PSCmdlet.ShouldContinue("The folder '$folder' does not exist, do you want to create it?", "Configuring $name module location:")) {
          $ConfirmPreference = $CP
          if(!(New-Item $folder -Type Directory -Force -ErrorAction SilentlyContinue -ErrorVariable fail))
          {
            Write-Warning ($fail.Exception.Message + "`nThe $name Location path '$folder' couldn't be created.`n`nYou may need to be elevated.`n`nPlease enter a new path, or press Ctrl+C to give up.")
          }
        }
        $ConfirmPreference = $CP
      }

      ## Add it to the PSModulePath, if necessary
      if((Test-Path $folder) -and ($PSModulePaths -notcontains (Convert-Path $folder))) {
        $CP, $ConfirmPreference = $ConfirmPreference, 'Low'
        if($PSCmdlet.ShouldContinue("The folder '$folder' is not in your PSModulePath, do you want to add it?", "Configuring $name module location:")) {
          $ConfirmPreference = $CP          
          # Global and System paths need to go in the Machine registry to work properly
          if("Global","System" -contains $name) {
            try {
              $PsMP = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine") + ";" + $Folder
              [System.Environment]::SetEnvironmentVariable("PSModulePath",$PsMP,"Machine")
            }
            catch [System.Security.SecurityException] 
            {
              Write-Warning ($_.Exception.Message + " The $name path '$folder' couldn't be added to your Local Machine PSModulePath.")
              try {
                $PsMP = [System.Environment]::GetEnvironmentVariable("PSModulePath", "User") + ";" + $Folder
                [System.Environment]::SetEnvironmentVariable("PSModulePath", $PsMP, "User")
                Write-Host "Added '$folder' to your user PSModulePath instead."
              }
              catch [System.Security.SecurityException] 
              {
                Write-Warning ($_.Exception.Message + " The $name path '$folder' couldn't be added to your PSModulePath.")
              }
            }
          } else {
            try {
              $PsMP = [System.Environment]::GetEnvironmentVariable("PSModulePath", "User") + ";" + $Folder
              [System.Environment]::SetEnvironmentVariable("PSModulePath", $PsMP, "User")
            }
            catch [System.Security.SecurityException] 
            {
              Write-Warning ($_.Exception.Message + " The $name path '$folder' couldn't be added to your PSModulePath.")
            }
          }
        }
        $ConfirmPreference = $CP
      }
    } while(!(Test-Path $folder))
    $Paths.$path = $folder
  }

  Set-ConfigData -ConfigData $Paths
}

