$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { Split-Path $_.Value -Parent }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
}
. $PoshCodeModuleRoot\Constants.ps1


function FindModule {
   [CmdletBinding()]
   param(
      # Term to Search for (defaults to find "all" modules)
      [string]$SearchTerm,

      # Search for modules published by a particular author.
      [string]$Author,

      # Search for a specific module.
      [string]$ModuleName,

      # Search for a specific version (NOT SUPPORTED)
      [string]$Version,

      [Parameter(Mandatory=$true)]
      $Root
   )
   process {
      $(
         $RepositoryRoot = $Root
         Write-Verbose "Folder Repository $RepositoryRoot"
                 
         if(!$ModuleName) {
             $Source = Join-Path $RepositoryRoot "*${PackageInfoExtension}"
         } else {
             $Source = (Join-Path $RepositoryRoot "${ModuleName}*${PackageInfoExtension}"),
                         (Join-Path $RepositoryRoot "*${ModuleName}*${PackageInfoExtension}")
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
      ) | %{ New-Object PSObject -Property $_ } | % {
            $_.pstypenames.Insert(0,'PoshCode.ModuleInfo')
            $_.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
            $_.pstypenames.Insert(0,'PoshCode.Search.FileSystem.ModuleInfo')
            Add-Member -Input $_ -Passthru -MemberType NoteProperty -Name Repository -Value @{ FileSystem = $Root }
         }
   }
}
