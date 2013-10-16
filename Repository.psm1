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
                #Term to Search for
        [string]
        $SearchTerm,
        
        # Search for modules published by a particular author.
        [string]
        $Author,

        # Search for a specific module.
        [alias('Repo')]
        [string]
        $ModuleName
    )
    
    ## get all FindModule cmdlets
    Get-Module (split-path $PSScriptRoot -leaf) | select -exp NestedModules | ? {$_.exportedcommands.FindModule} | %{&$_.exportedcommands.findmodule @PSBoundParameters}
    
}

Export-ModuleMember -Function 'Find-Module'