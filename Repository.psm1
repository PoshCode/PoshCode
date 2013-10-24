Import-Module -Name "$PSScriptRoot\RepositoryFileSystem.psm1", "$PSScriptRoot\RepositoryGitHub.psm1"

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
    $FindCommands = Get-Command FindModul[e] -Module Repository*
    $ConfiguredRepositories = (Get-ConfigData).Repositories

    Write-Verbose $($FindCommands | Out-Default)

    foreach($Repository in $ConfiguredRepositories.Keys) {

      Write-Verbose "Get-Command FindModule -Module 'Repository${Repository}'"
      Get-Command FindModule -Module "Repository${Repository}" | % {

        Write-Verbose "Repository${Repository}\$_"
        foreach($root in @($ConfiguredRepositories.$Repository)) {

          Write-Progress "Searching Module Repositories" "Searching ${Repository} ${Root}"
          &$_ @PSBoundParameters -Root $root | Add-Member NoteProperty ModuleType SearchResult
        }
      }
    }
}

Export-ModuleMember -Function 'Find-Module'