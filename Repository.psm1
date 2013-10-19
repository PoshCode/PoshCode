function Find-Module {
   <#
      .Synopsis
         Find PoshCode packages online
      .DESCRIPTION
         This searches a list of online repositories (like github) for available modules packages.
      .EXAMPLE
         Find-Module
      .EXAMPLE
         Find-Module -owner jrich523
      .EXAMPLE
         Find-Module -owner jrich523 -name PSVA
      .OUTPUTS
         PoshCode.Search.ModuleInfo
   #>
   [CmdletBinding()]
   Param
   (
      #Term to Search for
      [string]$SearchTerm,
        
      # Search for modules published by a particular author.
      [string]$Author,

      # Search for a specific module.
      [alias('Repo')]
      [string]$ModuleName
    )
    
    ## Get all the "FindModule" cmdlets from already loaded modules
    Get-Command FindModule* -Module Repository* | %{ &$_ @PSBoundParameters }
}

Export-ModuleMember -Function 'Find-Module'