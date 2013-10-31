
function FindModule {
   [CmdletBinding()]
   param(
      # Term to Search for (defaults to find "all" modules)
      [string]$SearchTerm,

      # Search for modules published by a particular author.
      [string]$Author,

      # Search for a specific module.
      [string]$ModuleName,

      [Parameter(Mandatory=$true)]
      $Root
   )
   process {
      $(
         $RepositoryRoot = $Root
         if((Test-Path $RepositoryRoot -Type Leaf) -or (Test-Path (Join-Path $PoshCodeModuleRoot $RepositoryRoot) -Type Leaf) -or (Test-Path (Join-Path $PoshCodeModuleRoot "$RepositoryRoot.psd1") -Type Leaf)) {
            if(!(Test-Path $RepositoryRoot -Type Leaf)) { $RepositoryRoot = Join-Path $PoshCodeModuleRoot $RepositoryRoot }
            if(!(Test-Path $RepositoryRoot -Type Leaf)) { $RepositoryRoot = "$RepositoryRoot.psd1" }

            Write-Verbose "File Repository $RepositoryRoot"
            # TODO: Check $Repository.LastUpdated and fetch from web
            $Repository = Import-Metadata $RepositoryRoot

            if($ModuleName) {
               $Repository.Modules.$ModuleName
            } else {
               $Repository.Modules.Values | 
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
            Write-Verbose "Folder Repository $RepositoryRoot"
                
            if(!$ModuleName) {
               $Source = Join-Path $RepositoryRoot "*.psd1"
            } else {
               $Source = (Join-Path $RepositoryRoot "${ModuleName}*.psd1"),
                         (Join-Path $RepositoryRoot "*${ModuleName}*.psd1")
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