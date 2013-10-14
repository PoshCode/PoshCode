<#
.Synopsis
   Find PoshCode packages online
.DESCRIPTION
   This searches a list of online repositories (like github) for available modules packages.
.EXAMPLE
   Find-Module
.EXAMPLE
   Find-Module -owner jrich523
.EXAMPLE
    Find-Module -owner jrich523 -name PSVA
.OUTPUTS
   PoshCode.Search.ModuleInfo
#>

function Find-Module
{
    [CmdletBinding()]
    Param
    (
        # Search for Modules published by a particular user.
        [Parameter(Mandatory=$false,ParameterSetName='Owner')]
        [Parameter(Mandatory=$true,ParameterSetName='Repo',Position=0)]
        [string]
        $Owner,

        # Search for a certain Module based on the Owner and the repository name, Owner IS required to use this.
        [Parameter(Mandatory=$true,ParameterSetName='Repo',Position=1)]
        [Alias('Repo')]
        [string]
        $Name
    )
    
    ## get all FindModule cmdlets
    Get-Module (split-path $PSScriptRoot -leaf) | select -exp NestedModules | ? {$_.exportedcommands.FindModule} | %{&$_.exportedcommands.findmodule @PSBoundParameters}
    
}

Export-ModuleMember -Function 'Find-Module'