add-type -AssemblyName system.runtime.serialization
if("System.Runtime.Serialization.Json.JsonReaderWriterFactory" -as [Type]) { 

   function FindModule {
      [CmdletBinding()]
      param(
         # Term to Search for (defaults to find "all" modules)
         [string]$SearchTerm,

         # Search for modules published by a particular author.
         [string]$Author,

         # Search for a specific module.
         [alias('Repo')]
         [string]$ModuleName,

         $Root = "https://api.github.com/search/code"
      )


      if($Author -and $ModuleName) # SAM,AM
      {
         $search = "$SearchTerm @$Author/$ModuleName"
      }
      elseif($Author) # A,AS
      {
         $search = "$SearchTerm @$Author"
      }
      elseif($ModuleName) #M,MS
      {
         $search = "$SearchTerm $ModuleName"
      }
      else # S
      {
         $search = $SearchTerm
      }
    
      Write-Verbose "q= $search path:package.psd1"
      
      Add-Type -AssemblyName System.Web.Extensions

      # Note: while in preview, the GitHub api requires an "Accept" header as acknowledgement of it's beta status.
      $pagedata = Invoke-WebRequest $Root -Body @{q="$search path:package.psd1"} -Headers @{Accept='application/vnd.github.preview'}
      $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
      $json = $ser.DeserializeObject($pagedata)

      $json.items | %{
         $obj = New-Object psobject -Property @{
            'Author'=$_.repository.owner.login
            'ModuleName'=$_.repository.name
            'Description'=$_.repository.description
            # The PackageManifestUri should point at the raw version of the html_url so tools can download it
            'PackageManifestUri'=$_.html_url -replace "(https?://)",'$1raw.' -replace "/blob",""

            'SourceRepoUri'=$_.repository.html_url
            'Repository' = @{ GitHub = $Root }
         }
         $obj.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
         $obj.pstypenames.Insert(0,'PoshCode.Search.GithubModuleInfo')
         if($ModuleName)
         {
            $obj | Where-Object { $_.Name -eq $ModuleName }
         }
         else
         {
            $obj
         }
      }

   }

   Export-ModuleMember -Function FindModule

}
else { write-Warning "Github Searching is unavailable because it requires the JavaScriptSerializer from .Net 3.5" }

