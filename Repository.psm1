# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1

if(!(Get-Command Invoke-WebReques[t] -ErrorAction SilentlyContinue)){
  Import-Module $PoshCodeModuleRoot\InvokeWeb
}

Import-Module $PoshCodeModuleRoot\Metadata.psm1
# FULL # END FULL


$CommonParameters = "ErrorAction", "WarningAction", "Verbose", "Debug", "ErrorVariable", "WarningVariable", "OutVariable", "OutBuffer", "PipelineVariable"

function Find-Module {
    <#
      .Synopsis
         Find PoshCode packages online
      .DESCRIPTION
         This searches a list of online repositories (like github) for available modules packages.
      .EXAMPLE
         Find-Module

         Lists all the module in all the available repositories
      .EXAMPLE
         Find-Module Viso

         Find all modules which mention Visio in (their package manifests) in all repositories
      .EXAMPLE
         Find-Module -Author jrich523

         Finds all modules by jrich523 in all repositories
      .EXAMPLE
         Find-Module -Author jrich523 -Name PSVA -Repository GitHub

         Finds a specific module by a specific author in a specific repository
      .OUTPUTS
         PoshCode.Search.ModuleInfo
    #>
    [CmdletBinding()]
    param
    (
        # Text to search for in name, description or tags (supports wildcards).
        [string]$SearchTerm,
        
        # Search for modules published by a particular author (supports wildcards, and searches for partial matches by default because multiple authors end up as one string in PowerShell modules).
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Author,

        # Search for a specific module by name (supports wildcards).
        [alias('ModuleName','MN')]
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Name,

        # Search for a specific version. Not all repositories support versions.
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleVersion","MV")]
        [string]$Version,

        # The path of a configured repository (allows wildcards), or a hashtable of @{RepositoryType=@("RepositoryRootUri")}
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        $Repository,

        [int]
        $Limit = 0
    )
    begin { 
        $Global:SearchErrors = New-Object System.Collections.ArrayList
        $Count = 0
    }
    process {
        if($Repository -is [hashtable]) {
            $SelectedRepositories = $Repository
        } else {
            $SelectedRepositories = @{}
            $ConfiguredRepositories = (Get-ConfigData).Repositories
            if(!$Repository) {
                Write-Verbose "Using SearchByDefault Repositories"
                foreach($Repo in $ConfiguredRepositories.Keys | Where-Object { $ConfiguredRepositories.$_.SearchByDefault }) {
                    $SelectedRepositories."$Repo" = $ConfiguredRepositories."$Repo"
                }
            } else {
                # Filter Repositories
                # First try matching the name exactly:
                if($ConfiguredRepositories."$Repository") {
                    Write-Verbose "Found exact name: $Repository"
                    $SelectedRepositories."$Repository" = $ConfiguredRepositories."$Repository"
                # Then try wildcards:
                } elseif($Keys = $ConfiguredRepositories.Keys | Where-Object { foreach($r in @($Repository)){ $_ -like "$r" } }) {
                    Write-Verbose "Found matching names: $Keys"
                    foreach($Repo in $Keys) {
                        $SelectedRepositories."$Repo" = $ConfiguredRepositories."$Repo"
                    }
                } elseif($Keys = $ConfiguredRepositories.Keys | Where-Object { foreach($r in @($Repository)){ $_.Root -like "$r" } }) {
                    Write-Verbose "Found matching Roots: $Keys"
                    foreach($Repo in $Keys) {
                        $SelectedRepositories."$Repo" = $ConfiguredRepositories."$Repo"
                    }
                }
            }
        }

        if($SelectedRepositories.Count -eq 0) {
            Write-Error "No repository specified for search. Please specify a repository name or set one or more of your configured repositories to SearchByDefault."
            return
        }
    
        $null = $PSBoundParameters.Remove("Repository")
        $null = $PSBoundParameters.Remove("Limit")
      
        # Write-Verbose ($SelectedRepositories | %{ $_ | Format-Table -HideTableHeaders }| Out-String -Width 110)
        foreach($Name in $SelectedRepositories.Keys) {
            $Repo = $SelectedRepositories.$Name
            Write-Verbose "$(${Repo}.Type)\FindModule -Root $($Repo.Root)"

            $Command = Import-Module "${PoshCodeModuleRoot}\Repositories\$(${Repo}.Type)" -Passthru | % { $_.ExportedCommands['FindModule'] } 

            # We help out by mapping anything in the settings to their parameters
            foreach($k in @($Repo.Keys) | Where-Object { ($Command.Parameters.Keys -contains $_) -and ("Type" -notcontains $_)}) {
                $PSBoundParameters.$k = $Repo.$k
            }

            $Mandatory = $Command.Parameters.Values | 
                Where-Object { $_.Attributes.Mandatory -and ($PSBoundParameters.Keys -NotContains $_.Name)} |
                ForEach-Object { $_.Name }

            if($Mandatory) {
                Write-Warning "Not searching $($Repo.Type) repository $Name, missing mandatory parameter(s) '$($Mandatory -join ''',''')'"
            } else {
                # Write-Verbose ($PSBoundParameters | Format-Table | Out-String -Width 110)
                try {
                    $(if($Limit -gt 0) {
                        &$Command @PSBoundParameters | ForEach-Object { if(($Count++) -lt $Limit){ $_ } else { break } }
                    } else {
                        &$Command @PSBoundParameters
                    }) | ConvertTo-PSModuleInfo -AddonInfo @{ 
                            ModuleType = "SearchResult"  # As opposed to "Script" or "Binary" or "Manifest" (I think "CDXML" modules stay as "Manifest" modules after importing)
                            Repository = @{ $Name = $Repo }
                         } -PSTypeNames ("PoshCode.ModuleInfo", "PoshCode.Search.ModuleInfo", "PoshCode.Search.${Name}.ModuleInfo") -AsObject
                }
                catch 
                {
                    $SearchErrors.Add($_)
                    Write-Warning "Error Searching $($Repo.Type) $($Repo.Root) (See `$SearchErrors)"
                }
                if($Limit -gt 0 -and $Count -ge $Limit) { return }
            }
        }
    }
}




function Publish-Module {
    #.Synopsis
    #   Pushes a package to a NuGet-API compatible repository
    param(
        # The file you want to publish
        [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        $Package,

        # The name or partial URL of a configured repository, or the full URL to a repository
        $Repository,

        # An API Key or login credentials for the repository
        $ApiKey
    )
    begin { 
        $Global:PublishErrors = New-Object System.Collections.ArrayList
        $Count = 0
    }
    process {

        if($Repository -is [hashtable]) {
            $SelectedRepositories = $Repository
        } else {
            $SelectedRepositories = @{}
            $ConfiguredRepositories = (Get-ConfigData).Repositories
            if(!$Repository) {
                Write-Verbose "Using SearchByDefault Repositories"
                foreach($Repo in $ConfiguredRepositories.Keys | Where-Object { $ConfiguredRepositories.$_.PublishByDefault }) {
                    $SelectedRepositories."$Repo" = $ConfiguredRepositories."$Repo"
                }
            } else {
                # Filter Repositories
                # First try matching the name exactly:
                if($ConfiguredRepositories."$Repository") {
                    Write-Verbose "Found exact name: $Repository"
                    $SelectedRepositories."$Repository" = $ConfiguredRepositories."$Repository"
                # Then try wildcards:
                } elseif($Keys = $ConfiguredRepositories.Keys | Where-Object { foreach($r in @($Repository)){ $_ -like "$r" } }) {
                    Write-Verbose "Found matching names: $Keys"
                    foreach($Repo in $Keys) {
                        $SelectedRepositories."$Repo" = $ConfiguredRepositories."$Repo"
                    }
                } elseif($Keys = $ConfiguredRepositories.Keys | Where-Object { foreach($r in @($Repository)){ $_.Root -like "$r" } }) {
                    Write-Verbose "Found matching Roots: $Keys"
                    foreach($Repo in $Keys) {
                        $SelectedRepositories."$Repo" = $ConfiguredRepositories."$Repo"
                    }
                }
            }
        }

        if($SelectedRepositories.Count -eq 0) {
            Write-Error "No repository specified for search. Please specify a repository name or set one or more of your configured repositories to SearchByDefault."
            return
        }
    
        $null = $PSBoundParameters.Remove("Repository")

        foreach($Name in $SelectedRepositories.Keys) {
            $Repo = $SelectedRepositories.$Name
            Write-Verbose "$(${Repo}.Type)\PushModule -Root $($Repo.Root)"

            $Command = Import-Module "${PoshCodeModuleRoot}\Repositories\$(${Repo}.Type)" -Passthru | % { $_.ExportedCommands['PushModule'] } 

            # We help out by mapping anything in the settings to their parameters
            foreach($k in @($Repo.Keys) | Where-Object { ($Command.Parameters.Keys -contains $_) -and ("Type" -notcontains $_)}) {
                $PSBoundParameters.$k = $Repo.$k
            }

            $Mandatory = $Command.Parameters.Values | 
                Where-Object { $_.Attributes.Mandatory -and ($PSBoundParameters.Keys -NotContains $_.Name)} |
                ForEach-Object { $_.Name }

            if($Mandatory) {
                Write-Warning "Not publishing to $($Repo.Type) repository $($Name), missing mandatory parameter(s) '$($Mandatory -join ''',''')'"
            } else {
                # Write-Verbose ($PSBoundParameters | Format-Table | Out-String -Width 110)
                try {
                    &$Command @PSBoundParameters
                }
                catch 
                {
                    $PublishErrors.Add($_)
                    Write-Warning "Error Searching $($Repo.Type) $($Repo.Root) (See `$PublishErrors)"
                }
            }
        }
    }
}


Export-ModuleMember -Function 'Find-Module', 'Publish-Module'
