function Find-Module {
   <#
      .Synopsis
         Find PoshCode packages online
      .DESCRIPTION
         This searches a list of online repositories (like github) for available modules packages.
      .EXAMPLE
         Find-Module
      .EXAMPLE
         Find-Module -Author jrich523
      .EXAMPLE
         Find-Module -Author jrich523 -ModuleName PSVA
      .OUTPUTS
         PoshCode.Search.ModuleInfo
   #>
   [CmdletBinding()]
   Param
   (
      # Term to Search for
      [string]$SearchTerm,
        
      # Search for modules published by a particular author.
      [string]$Author,

      # Search for a specific module.
      [alias('Repo','Name','MN')]
      [string]$ModuleName
    )
    
    ## Get all the "FindModule" cmdlets from already loaded modules
    $FindCommands = $MyInvocation.MyCommand.Module.NestedModules | % { $_.ExportedCommands['FindModule'] } 
    $ConfiguredRepositories = (Get-ConfigData).Repositories

    foreach($Repository in $ConfiguredRepositories.Keys) {

      Write-Verbose "Get-Command FindModule -Module 'Repository${Repository}'"
         $FindCommands | Where-Object { $_.ModuleName -like "*${Repository}" } | % {

         Write-Verbose "Repository${Repository}\$_"
         foreach($root in @($ConfiguredRepositories.$Repository)) {

            Write-Progress "Searching Module Repositories" "Searching ${Repository} ${Root}"
            try {
               &$_ @PSBoundParameters -Root $root | Add-Member NoteProperty ModuleType SearchResult -Passthru
            }
            catch 
            {
               Write-Warning "Error Searching ${Repository} $($_)"
            }
         }
      }
   }
}

Export-ModuleMember -Function 'Find-Module'