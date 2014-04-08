$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { Split-Path $_.Value -Parent }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
}
. $PoshCodeModuleRoot\Constants.ps1

Import-Module $PoshCodeModuleRoot\Atom.psm1

function FindModule {
   [CmdletBinding()]
   param(
      # Term to Search for (defaults to find "all" modules)
      [string]$SearchTerm,

      # Search for modules published by a particular author.
      [string]$Author,

      # Search for a specific module.
      [string]$Name,

      # Search for a specific version (NOT SUPPORTED)
      [string]$Version,

      [Parameter(Mandatory=$true)]
      $Root
    )
    process {
        $RepositoryRoot = $Root
        Write-Verbose "Folder Repository $RepositoryRoot"
                 
        if(!$Name) {
            $Source = (Join-Path $RepositoryRoot "*${PackageInfoExtension}"), (Join-Path $RepositoryRoot "*${XmlFileExtension}")
        } else {
            $Source = (Join-Path $RepositoryRoot "${ModuleName}*${PackageInfoExtension}"),
                      (Join-Path $RepositoryRoot "*${ModuleName}*${PackageInfoExtension}"),
                      (Join-Path $RepositoryRoot "${ModuleName}*${XmlFileExtension}"),
                      (Join-Path $RepositoryRoot "*${ModuleName}*${XmlFileExtension}")
        }
      
        $OFS = ", "
        $Modules = Get-Item $Source | % { $_.FullName } | Sort-Object -Unique
        Write-Verbose "Found $($Modules.Count) Module Files in $Source"
        $Modules | Import-AtomFeed | Where-Object {
                # Write-Verbose "Folder Repository Item Values: $($_.Values -split " |\\|/" -join ', ')"
                $("$SearchTerm$Author"-eq"") -or
      
                $(if($SearchTerm) {
                    ($_.Values -Split " |\\|/" -like $SearchTerm) -or
                    ($_.Values -like $SearchTerm)
                }) -or 
      
                $(if($Author) { $_.Author.Contains($Author) })
            }
    }
}
