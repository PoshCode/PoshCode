
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
      $(
         if((Test-Path $Root -Type Leaf) -or (Test-Path (Join-Path $PSScriptRoot $Root) -Type Leaf)) {
            if(!(Test-Path $Root -Type Leaf)) { $Root = Join-Path $PSScriptRoot $Root }

            Write-Verbose "File Repository $Root"
            $Repository = Import-Metadata $Root

            if($ModuleName) {
               $Repository.$ModuleName
            } else {
               $Repository.Values | 
                  Where-Object {
                     # Write-Verbose "File Repository Item Values: $($_.Values -split " |\\|/" -join ', ')"
                     $("$SearchTerm$Author"-eq"") -or

                     $(if($SearchTerm) {
                        ($_.Values -Split " |\\|/" -like $SearchTerm) -or
                        ($_.Values -like $SearchTerm)
                     }) -or 

                     $(if($Author) { $_.Author.Contains($Author) })
                  }        
            }
         } else {
            Write-Verbose "Folder Repository $Root"
                
            if(!$ModuleName) {
               $Source = Join-Path $Root "*.psd1"
            } else {
               $Source = (Join-Path $Root "${ModuleName}*.psd1"),
                         (Join-Path $Root "*${ModuleName}*.psd1")
            }

            $OFS = ", "
            Get-Item $Source | 
               Sort-Object -Unique |
               Import-Metadata |
               Where-Object {
                  # Write-Verbose "Folder Repository Item Values: $($_.Values -split " |\\|/" -join ', ')"
                  $("$SearchTerm$Author"-eq"") -or

                  $(if($SearchTerm) {
                     ($_.Values -Split " |\\|/" -like $SearchTerm) -or
                     ($_.Values -like $SearchTerm)
                  }) -or 

                  $(if($Author) { $_.Author.Contains($Author) })
               }
         }
      ) | %{ New-Object PSObject -Property $_ } | % {
            $_.pstypenames.Insert(0,'PoshCode.ModuleInfo')
            $_.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
            $_.pstypenames.Insert(0,'PoshCode.Search.FileSystem.ModuleInfo')
            Add-Member -Input $_ -Passthru -MemberType NoteProperty -Name Repository -Value @{ FileSystem = $Root }
         }
   }
}