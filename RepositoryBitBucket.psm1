#####################################################
#### TODO: DELETE THIS FILE AND CLEANUP PoshCode.psd1
#####################################################

function FindModule
{
    [CmdletBinding(DefaultParameterSetName='GetAll')]
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