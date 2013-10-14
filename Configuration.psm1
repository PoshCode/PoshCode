########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################
## Configuration.psm1 defines the Get/Set functionality for ConfigData
## It also includes Get-SpecialFolder for resolving special folder paths
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
        throw "Cannot convert Path, with value: `"$Name`", to type `"System.Environment+SpecialFolder`": Error: `"The identifier name $Name is noe one of $($Names -join ', ')"
      }
    })]
    [String]$Path = "*",

    # If set, returns a hashtable of folder names to paths
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
# The config file
$Script:ConfigFile = Join-Path $PSScriptRoot ([IO.Path]::GetFileName( [IO.Path]::ChangeExtension($PSScriptRoot, ".ini") ))

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

# These functions are just simple helpers for use in data sections (see about_data_sections) and .psd1 files (see Import-LocalizedData)
function PSObject {
   <#
      .Synopsis
         Creates a new PSCustomObject with the specified properties
      .Description
         This is just a wrapper for the PSObject constructor with -Property $Value
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The hashtable of properties to add to the created objects
   #>
   param([hashtable]$Value)
   New-Object System.Management.Automation.PSObject -Property $Value 
}

function Guid {
   <#
      .Synopsis
         Creates a GUID with the specified value
      .Description
         This is basically just a type cast to GUID.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The GUID value.
   #>   
   param([string]$Value)
   [Guid]$Value
}

function DateTime {
   <#
      .Synopsis
         Creates a DateTime with the specified value
      .Description
         This is basically just a type cast to DateTime, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The DateTime value, preferably from .Format('o'), the .Net round-trip format
   #>   
   param([string]$Value)
   [DateTime]$Value
}

function DateTimeOffset {
   <#
      .Synopsis
         Creates a DateTimeOffset with the specified value
      .Description
         This is basically just a type cast to DateTimeOffset, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The DateTimeOffset value, preferably from .Format('o'), the .Net round-trip format
   #>    
   param([string]$Value)
   [DateTimeOffset]$Value
}

# Import and Export are the external functions. 
function Import-Metadata {
   <#
      .Synopsis
         Creates a data object from the items in a Manifest file
   #>
   [CmdletBinding()]
   param(
      [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
      [string]$Path
   )

   process {
      $ModuleInfo = $null
      # When we have a file, use Import-LocalizedData (via Import-PSD1)
      if(Test-Path $Path) {
         Write-Verbose "Importing Module Manifest From Path: $Path"
         if(!(Test-Path $Path -PathType Leaf)) {
            $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleInfoExtension)
         }
         try {
            if($FilePath = Convert-Path $Path -ErrorAction SilentlyContinue) {
               $ModuleInfo = @{}
               Import-LocalizedData -BindingVariable ModuleInfo -BaseDirectory (Split-Path $FilePath) -FileName (Split-Path $FilePath -Leaf) -SupportedCommand "PSObject", "GUID"
               $ModuleInfo = $ModuleInfo | Add-SimpleNames
            }
         } catch {
            Write-Warning "Couldn't get ModuleManifest from the file:`n${Manifest}"
            $PSCmdlet.ThrowTerminatingError( $_ )
         }
         if(!$ModuleInfo.Count) {
            $Path = Get-Content $Path -Delimiter ([char]0)
         }
      }

      # Otherwise, use the Tokenizer and Invoke-Expression with a "Data" section
      if(!$ModuleInfo) {
         ConvertFrom-Metadata $Path
      }
      Write-Output $ModuleInfo
   }
}

function Export-Metadata {
   <#
      .Synopsis
         A metadata export function that works like json
      .Description
         Converts simple objects to psd1 data files
         Exportable data is limited the rules of data sections (see about_Data_Sections)

         The only things exportable are Strings and Numbers, and Arrays or Hashtables where the values are all strings or numbers.
         NOTE: Hashtable keys must be simple strings or numbers
         NOTE: Simple dynamic objects can also be exported (they come back as PSObject)
   #>
   [CmdletBinding()]
   param(
      # Specifies the path to the PSD1 output file.
      [Parameter(Mandatory=$true, Position=0)]
      $Path,

      # Specifies the objects to export as metadata structures.
      # Enter a variable that contains the objects or type a command or expression that gets the objects.
      # You can also pipe objects to Export-Metadata.
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      $InputObject
   )
   begin { $data = @() }

   process {
      $data += @($InputObject)
   }

   end {
      ConvertTo-Metadata -Path $Path -Value (ConvertTo-Metadata $data)
   }
}

# At this time there's not a lot of value in exporting the ConvertFrom/ConvertTo functions
# Private Functions (which could be exported)
function ConvertFrom-Metadata {
   [CmdletBinding()]
   param($InputObject)
   begin {
      $ValidTokens = "Keyword", "Command", "Variable", "CommandParameter", "GroupStart", "GroupEnd", "Member", "Operator", "String", "Number", "Comment", "NewLine", "StatementSeparator"
      $ValidCommands = "PSObject", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData"
      $ValidParameters = "-StringData", "-Value"
      $ValidKeywords = "if","else","elseif"
      $ValidVariables = "PSCulture","PSUICulture","True","False","Null"
      $ParseErrors = $Null
   }   
   process {
      # You can't stuff signatures into a data block
      $InputObject = $InputObject -replace "# SIG # Begin(?s:.*)# SIG # End signature block"
      Write-Verbose "Converting Metadata From Content: $($InputObject.Length) bytes"

      # Safety checks just to make sure they can't escape the data block
      # If there are unbalanced curly braces, it will fail to tokenize
      $Tokens = [System.Management.Automation.PSParser]::Tokenize(${InputObject},[ref]$ParseErrors)
      if($ParseErrors -ne $null) {
         $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord "Parse error reading metadata", "Parse Error", "InvalidData", $ParseErrors) )
      }
      if($InvalidTokens = $Tokens | Where-Object { $ValidTokens -notcontains $_.Type }){
         $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord "Invalid Tokens found when parsing package manifest. $(@($InvalidTokens)[0].Content +' on Line '+ @($InvalidTokens)[0].StartLine +', character '+@($InvalidTokens)[0].StartColumn)", "Parse Error", "InvalidData", $InvalidTokens) )
      }

      $InvalidTokens = $(switch($Tokens){
         {$_.Type -eq "Keyword"} { if($ValidKeywords -notcontains $_.Content) { $_ } }
         {$_.Type -eq "CommandParameter"} { if(!($ValidParameters -match $_.Content)) { $_ } }
         {$_.Type -eq "Command"} { if($ValidCommands -notcontains $_.Content) { $_ } }
         {$_.Type -eq "Variable"} { if($ValidVariables -notcontains $_.Content) { $_ } }
      })
      if($InvalidTokens) {
         $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord "Invalid Tokens found when parsing package manifest. $(@($InvalidTokens)[0].Content +' on Line '+ @($InvalidTokens)[0].StartLine +', character '+@($InvalidTokens)[0].StartColumn)", "Parse Error", "InvalidData", $InvalidTokens) )
      }

      # Even with this much protection, Invoke-Expression makes me nervous, which is why I try to avoid it.
      try {
         Invoke-Expression "Data -SupportedCommand PSObject, GUID, DateTime, DateTimeOffset, ConvertFrom-StringData { ${InputObject} }"
      } catch {
         Write-Warning "Couldn't get ModuleManifest from the data:`n${Manifest}"
         $PSCmdlet.ThrowTerminatingError( $_ )
      }
   }
}

function ConvertTo-Metadata {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
      $InputObject
   )
   begin { $t = "  " }

   process {
      if($InputObject -is [Int16] -or 
         $InputObject -is [Int32] -or 
         $InputObject -is [Int64] -or 
         $InputObject -is [Double] -or 
         $InputObject -is [Decimal] -or 
         $InputObject -is [Byte]) { 
         Write-Verbose "Numbers"
         "$InputObject" 
      }
      elseif($InputObject -is [bool])  {
         Write-Verbose "Boolean"
         if($InputObject) { '$True' } else { '$False' }
      }
      elseif($InputObject -is [DateTime])  {
         Write-Verbose "DateTime"
         "DateTime '{0}'" -f $InputObject.ToString('o')
      }
      elseif($InputObject -is [DateTimeOffset])  {
         Write-Verbose "DateTime"
         "DateTimeOffset '{0}'" -f $InputObject.ToString('o')
      }
      elseif($InputObject -is [String])  {
         Write-Verbose "String"
         "'$InputObject'" 
      }
      elseif($InputObject -is [System.Collections.IDictionary]) {
         Write-Verbose "Dictionary"
         "@{{`n$t{0}`n}}" -f ($(
         ForEach($key in $InputObject.Keys) {
            if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
               "$key = " + (ConvertTo-Metadata $InputObject.($key))
            }
            else {
               "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
            }
         }) -split "`n" -join "`n$t")
      } 
      elseif($InputObject -is [System.Collections.IEnumerable]) {
         Write-Verbose "Enumarable"
         "@($($(ForEach($item in $InputObject.GetEnumerator()) { ConvertTo-Metadata $item }) -join ','))"
      }
      elseif($InputObject -is [Guid]) {
         Write-Verbose "GUID:"
         "Guid '$InputObject'"
      }
      elseif($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
         Write-Verbose "Dictionary"

         "PSObject @{{`n$t{0}`n}}" -f ($(
            ForEach($key in $InputObject | Get-Member -Type Properties | Select -Expand Name) {
               if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
                  "$key = " + (ConvertTo-Metadata $InputObject.($key))
               }
               else {
                  "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
               }
            }
         ) -split "`n" -join "`n$t")
      } 
      else {
         Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
         "'{0}'" -f $InputObject.ToString()
      }
   }
}

Export-ModuleMember -Function Get-SpecialFolder, Select-ModulePath, Test-ExecutionPolicy, 
                              Get-ConfigData, Set-ConfigData, Test-ConfigData, 
                              Import-Metadata, Export-Metadata, ConvertFrom-Metadata, ConvertTo-Metadata
# FULL # END FULL
