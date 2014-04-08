# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1

if(!(Get-Command Invoke-WebReques[t] -ErrorAction SilentlyContinue)){
  Import-Module $PoshCodeModuleRoot\InvokeWeb
}

Import-Module $PoshCodeModuleRoot\ModuleInfo.psm1
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
        # Term to Search for
        [string]$SearchTerm,
        
        # Search for modules published by a particular author.
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Author,

        # Search for a specific module.
        [alias('ModuleName','MN')]
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Name,

        # Search for a specific version. Not all repositories support versions
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
                $ConfiguredRepositories = $(
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
                )
            }
        }
    
        $null = $PSBoundParameters.Remove("Repository")
        $null = $PSBoundParameters.Remove("Limit")
      
        # Write-Verbose ($ConfiguredRepositories | %{ $_ | Format-Table -HideTableHeaders }| Out-String -Width 110)
        foreach($Name in $SelectedRepositories.Keys) {
            $Repo = $SelectedRepositories.$Name
            $Command = Import-Module "${PoshCodeModuleRoot}\Repositories\$(${Repo}.Type)" -Passthru | % { $_.ExportedCommands['FindModule'] } 

            Write-Verbose "$(${Repo}.Type)\FindModule -Root $($Repo.Root)"

            # We help out by mapping anything in the settings to their parameters
            foreach($k in @($Repo.Keys) | Where-Object { ($Command.Parameters.Keys -contains $_) -and ("Type" -notcontains $_)}) {
                $PSBoundParameters.$k = $Repo.$k
            }

            $Mandatory = $Command.Parameters.Values | 
                Where-Object { $_.Attributes.Mandatory -and ($PSBoundParameters.Keys -NotContains $_.Name)} |
                ForEach-Object { $_.Name }

            if($Mandatory) {
                Write-Warning "Not searching $($Repo.Type), missing mandatory parameter(s) '$($Mandatory -join ''',''')'"
            } else {
                # Write-Verbose ($PSBoundParameters | Format-Table | Out-String -Width 110)
                try {
                    $(if($Limit -gt 0) {
                        &$Command @PSBoundParameters | ForEach-Object { if(($Count++) -lt $Limit){ $_ } else { break } }
                    } else {
                        &$Command @PSBoundParameters
                    }) | ConvertTo-PSModuleInfo -AddonInfo @{ 
                            ModuleType = "SearchResult"
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

Export-ModuleMember -Function 'Find-Module'
