#####################################################
#### TODO: DELETE THIS FILE AND CLEANUP PoshCode.psd1
#####################################################

function FindModule
{
    [CmdletBinding(DefaultParameterSetName='GetAll')]
    Param
    (
        # Search for Modules published by a particular user.
        [Parameter(Mandatory=$false,ParameterSetName='Owner')]
        [Parameter(Mandatory=$true,ParameterSetName='Repo')]
        [string]
        $Owner,

        # Search for a certain Module based on the Owner and the repository name
        [Parameter(Mandatory=$true,ParameterSetName='Repo')]
        [Alias('Repo')]
        [string]
        $Name
    )

        $obj = new-object psobject -property @{
            'Name'="super duper black box"
            'Description'="Collect all the things!"
            'SourceRepoUri'="http://itssad"
            'PackageManifestUri'="http://noWayToQuery"
            'Owner'="Me!"
            'Repository'='BitBucket'
            }
         $obj.pstypenames.insert(0,'PoshCode.Search.ModuleInfo')
         $obj.pstypenames.insert(0,'PoshCode.Search.BitBucketModuleInfo')
         $obj

}

Export-ModuleMember -Function FindModule