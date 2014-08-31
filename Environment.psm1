# if you're running "elevated" we want to know that:
$PSProcessElevated = ([System.Environment]::OSVersion.Version.Major -gt 5) -and ( # Vista and ...
                                    new-object Security.Principal.WindowsPrincipal (
                                    [Security.Principal.WindowsIdentity]::GetCurrent()) # current user is admin
                                ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

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


function Set-EnvironmentVariable {
    #.Synopsis
    # Set an environment variable at the highest scope possible
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [String]$Name,

        [Parameter(Position=1)]
        [String]$Value,

        [System.EnvironmentVariableTarget]
        $Scope="Machine",

        [Switch]$FailFast
    )

    Set-Content "ENV:$Name" $Value
    $Success = $False
    do {
        try {
            [System.Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
            Write-Verbose "Set $Scope environment variable $Name = $Value"
            $Success = $True
        }
        catch [System.Security.SecurityException]
        {
            if($FailFast) {
                $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (
                    New-Object AccessViolationException "Can't set environment variable in $Scope scope"
                ), "FailFast:$Scope", "PermissionDenied", $Scope) )
            } else {
                Write-Warning "Cannot set environment variables in the $Scope scope"
            }
            $Scope = [int]$Scope - 1
        }
    } while(!$Success -and $Scope -gt "Process")
}


function Add-Path {
    #.Synopsis
    #  Add a folder to a path environment variable
    #.Description
    #  Gets the existing content of the path variable, splits it with the PathSeparator,
    #  adds the specified paths, and then joins them and re-sets the EnvironmentVariable
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$True)]
        [String]$Name,

        [Parameter(Position=1)]
        [String[]]$Append = @(),

        [String[]]$Prepend = @(),

        [System.EnvironmentVariableTarget]
        $Scope="User",

        [Char]
        $Separator = [System.IO.Path]::PathSeparator
    )

    # Make the new thing as an array so we don't get duplicates
    $Path = @($Prepend -split "$Separator" | %{ $_.TrimEnd("\/") } | ?{ $_ })
    $Path += $OldPath = @([Environment]::GetEnvironmentVariable($Name, $Scope) -split "$Separator" | %{ $_.TrimEnd("\/") }| ?{ $_ })
    $Path += @($Append -split "$Separator" | %{ $_.TrimEnd("\/") }| ?{ $_ })

    # Dedup path
    # If the path actually exists, use the actual case of the folder
    $Path = $(foreach($Folder in $Path) {
                if(Test-Path $Folder) {
                    Get-Item ($Folder -replace '(?<!:)(\\|/)', '*$1') | Where FullName -ieq $Folder | % FullName
                } else { $Folder }
            } ) | Select -Unique

    # Turn them back into strings
    $Path = $Path -join "$Separator"
    $OldPath = $OldPath -join "$Separator"

    # Path environment variables are kind-of a pain:
    # The current value in the process scope is a combination of machine and user, with changes
    # We need to fix the CURRENT path instead of just setting it
    $OldEnvPath = @($(Get-Content "ENV:$Name") -split "$Separator" | %{ $_.TrimEnd("\/") }) -join "$Separator"
    if("$OldPath".Trim().Length -gt 0) {
        Write-Verbose "Old $Name Path: $OldEnvPath"
        $OldEnvPath = $OldEnvPath -Replace ([regex]::escape($OldPath)), $Path
        Write-Verbose "New $Name Path: $OldEnvPath"
    } else {
        if($Append) {
            $OldEnvPath = $OldEnvPath + "$Separator" + $Path
        } else {
            $OldEnvPath = $Path + "$Separator" + $OldEnvPath
        }
    }

    Set-EnvironmentVariable $Name $($Path -join "$Separator") -Scope $Scope -FailFast
    if($?) {
        # Set the path back to the normalized value
        Set-Content "ENV:$Name" $OldEnvPath
    }
}
