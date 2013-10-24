
function FindModule {
   [CmdletBinding()]
   param(
      # Term to Search for (defaults to find "all" modules)
      [string]$SearchTerm,

      # Search for modules published by a particular author.
      [string]$Author = '*',

      # Search for a specific module.
      [string]$ModuleName = '*',

      $Root = "\\PoshCode.org\Modules"
   )
   process {
      $Source = (Join-Path $Root (Join-Path $Author "${ModuleName}*.psd1")),
                (Join-Path $Root (Join-Path $Author "*${ModuleName}*.psd1"))

      foreach($result in Get-ChildItem $Source | 
                           Import-Metadata $result -AsObject |
                           Where-Object { !$SearchTerm -or $true } ){
         $result.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
         $result.pstypenames.Insert(0,'PoshCode.Search.FileSystem')      
         Add-Member -Input $result -Passthru -MemberType NoteProperty -Name Repository -Value @{ FileSystem = $Root }
    
      }
   }
}