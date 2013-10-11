add-type -AssemblyName system.runtime.serialization
if("System.Runtime.Serialization.Json.JsonReaderWriterFactory" -as [Type])
{ 

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

    $search=$null
    switch($PSCmdlet.ParameterSetName)
    {
        "Repo" {$search ="@$Owner/$Name ";break}
        "Owner"{if($Owner){$search = "@$Owner ";break}}
    }

    Add-Type -AssemblyName System.Web.Extensions

    $pagedata = Invoke-WebRequest https://api.github.com/search/code -Body @{q="$search`"package.psd1`" in:path extension:psd1"} -Headers @{Accept='application/vnd.github.preview'}
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $json = $ser.DeserializeObject($pagedata)

    $json.items | %{
        $obj = New-Object psobject -Property @{
            'Name'=$_.repository.name
            'Description'=$_.repository.description
            'SourceRepoUri'=$_.repository.html_url
            'PackageManifestUri'=$_.html_url -replace "(https?://)",'$1raw.' -replace "/blob",""
            'Owner'=$_.repository.owner.login
            'Repository'='GitHub'
         }
         $obj.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
         $obj.pstypenames.Insert(0,'PoshCode.Search.GitModuleInfo')
         $obj
     }
     
}

Export-ModuleMember -Function FindModule

}
else { write-Warning "Github Searching is unavailable because it requires the JavaScriptSerializer from .Net 3.5" }