param(
  [Parameter(Mandatory=$true)]
  [Version]$Version
)

$Installation = (Get-Content .\Packaging\Installation.psm1 -Raw) -replace 'Export-ModuleMember.*(?m:;|$)' -replace "# SIG # Begin signature block(?s:.*)# SIG # End signature block"

Set-Content .\Install.ps1 ((@'
########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice.
########################################################################
#.Synopsis
#   Install a module package to the module 
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium", DefaultParameterSetName="UserPath")]
param(
  # The package file to be installed
  [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
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
  [Switch]$Import = $true,

  # If set, output information about the files as well as the module 
  [Switch]$Passthru
)
end {{
  # If this code isn't running from a module, then run the install
  Write-Progress "Validating Packaging Module" -Id 0
  if($PSBoundParameters.ContainsKey("Package")) {{
    $TargetModulePackage = $PSBoundParameters["Package"]
  }}

  $Module = Get-Module Packaging -ListAvailable

  if(!$Module -or $Module.Version -lt 1.0.8) {{
    Write-Progress "Installing Packaging Module" -Id 0
    if(!$PSBoundParameters.ContainsKey("InstallPath")) {{
      $PSBoundParameters["InstallPath"] = $InstallPath = Select-ModulePath
    }}
    # Use the psdxml now that we can, rather than hard-coding the version ;)    
    $PSBoundParameters["Package"] = "http://PoshCode.org/Modules/Packaging.psdxml"

    $PackagingPath = Join-Path $InstallPath Packaging
    Install-ModulePackage @PSBoundParameters
    Import-Module $PackagingPath

    # Now that we've installed the Packaging module, we will update the config data with the path they picked
    $ConfigData = Get-ConfigData
    if($InstallPath -match ([Regex]::Escape([Environment]::GetFolderPath("UserProfile")) + "*")) {{
      $ConfigData["UserPath"] = $InstallPath
    }} elseif($InstallPath -match ([Regex]::Escape([Environment]::GetFolderPath("CommonDocuments")) + "*")) {{
      $ConfigData["CommonPath"] = $InstallPath
    }} elseif($InstallPath -match ([Regex]::Escape([Environment]::GetFolderPath("CommonProgramFiles")) + "*")) {{
      $ConfigData["CommonPath"] = $InstallPath
    }} else {{
      $ConfigData["Default"] = $InstallPath
    }}
    Set-ConfigData -ConfigData $ConfigData
  }}

  if($TargetModulePackage) {{
    Write-Progress "Installing Package" -Id 0
    $PSBoundParameters["Package"] = $TargetModulePackage
    Install-ModulePackage @PSBoundParameters
  }}
  
  Test-ExecutionPolicy
}}

begin {{

{1}

}}
'@
) -f $Version, $Installation)

Sign .\Install.ps1 -WA 0 -EA 0
Sign -Module Packaging -WA 0 -EA 0

Update-ModuleInfo Packaging -Version $Version
New-ModulePackage Packaging .