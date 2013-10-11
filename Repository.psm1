## call all FindModule functions
ipmo "$PSScriptRoot\RepositoryGitHub.psm1"
ipmo "$PSScriptRoot\RepositoryBitBucket.psm1"

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

        # Search for a certain Module based on the Owner and the repository name
        [Parameter(Mandatory=$true,ParameterSetName='Repo',Position=1)]
        [Alias('Repo')]
        [string]
        $Name
    )
    
    ## get all FindModule cmdlets
    Get-Module | ? {$_.exportedcommands.FindModule} | %{&$_.exportedcommands.findmodule @PSBoundParameters}
    
}

Export-ModuleMember -Function 'Find-Module'