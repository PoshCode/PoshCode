$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { Split-Path $_.Value -Parent }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
}

if(!(Get-Command Invoke-WebReques[t] -ErrorAction SilentlyContinue)){
  Import-Module $PoshCodeModuleRoot\InvokeWeb
}

add-type -AssemblyName system.runtime.serialization
if("System.Runtime.Serialization.Json.JsonReaderWriterFactory" -as [Type]) { 

   function FindModule {
      [CmdletBinding()]
      param(
         # Term to Search for (defaults to find "all" modules)
         [string]$SearchTerm,

         # Search for modules published by a particular author.
         [Parameter(Mandatory=$true)]
         [string]$Author,

         # Search for a specific module.
         [Parameter(Mandatory=$false)]
         [string]$Name,

         # Search for a specific version (NOT SUPPORTED)
         [string]$Version,

         $Root = "https://api.github.com/search/code"
      )


      if($Author -and $Name) # SAM,AM
      {
         $search = "$SearchTerm packageInfo in:path repo:$Author/$Name"
      }
      elseif($Author) # A,AS
      {
         $search = "$SearchTerm packageInfo in:path user:$Author"
      }
    
      Write-Verbose "q=${search}"
      
      Add-Type -AssemblyName System.Web.Extensions

      # Note: while in preview, the GitHub api requires an "Accept" header as acknowledgement of it's beta status.
      # -Headers @{Accept='application/vnd.github.preview'}
      $wr = Invoke-WebRequest $Root -Body @{q="${search}"} 
      # Read the data using the right character set, because Invoke-WebRequest doesn't
      try {
         $null = $wr.RawContentStream.Seek(0,"Begin")
         $reader = New-Object System.IO.StreamReader $wr.RawContentStream, $wr.BaseResponse.CharacterSet
         $content = $reader.ReadToEnd()
      } catch {
         $content= $wr.Content
      } finally {
         if($reader) { $reader.Close() }
      }

      $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
      $json = $ser.DeserializeObject($Content)

      $json.items | Where-Object { !$Name -or $_.repository.name -eq $Name } | %{
         @{
            'Author'=$_.repository.owner.login
            'ModuleName'=$_.repository.name
            'Description'=$_.repository.description
            # The PackageInfoUrl should point at the raw version of the html_url so tools can download it
            'PackageInfoUrl'=$_.html_url -replace "(https?://)",'$1raw.' -replace "/blob",""

            'SourceRepoUri'=$_.repository.html_url
            'Repository' = @{ GitHub = $Root }
         }
      }
   }

   Export-ModuleMember -Function FindModule

}
else { write-Warning "Github Searching is unavailable because it requires the JavaScriptSerializer from .Net 3.5" }

