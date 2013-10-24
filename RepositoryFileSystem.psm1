
function FindModule {
   [CmdletBinding()]
   param(
      # Term to Search for (defaults to find "all" modules)
      [string]$SearchTerm,

      # Search for modules published by a particular author.
      [string]$Author,

      # Search for a specific module.
      [string]$ModuleName,

      $Root = "\\PoshCode.org\Modules"
   )
   process {
      $Source = (Join-Path $Root "${ModuleName}*.psd1"),
                (Join-Path $Root "*${ModuleName}*.psd1"),
                (Join-Path $Root "*${SearchTerm}*.psd1")

      $OFS = ", "
      Write-Verbose "Search: $Source"
      foreach($result in Get-Item $Source | Sort-Object -Unique |
                           Import-Metadata |
                           Where-Object {
                              (if($SearchTerm) {
                                 ($_.Values -Split " |\\|/" -like $SearchTerm) -or
                                 ($_.Values -like $SearchTerm)
                              }) -or (if($Author) { $_.Author.Contains($Author) })
                           } | %{ New-Object PSObject -Property $_ }){
         $result.pstypenames.Insert(0,'PoshCode.ModuleInfo')
         $result.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
         $result.pstypenames.Insert(0,'PoshCode.Search.FileSystem.ModuleInfo')
         Add-Member -Input $result -Passthru -MemberType NoteProperty -Name Repository -Value @{ FileSystem = $Root }
    
      }
   }
}