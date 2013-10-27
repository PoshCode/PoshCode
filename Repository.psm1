function Find-Module {
   <#
      .Synopsis
         Find PoshCode packages online
      .DESCRIPTION
         This searches a list of online repositories (like github) for available modules packages.
      .EXAMPLE
         Find-Module

         Lists all the module in all the available repositories
      .EXAMPLE
         Find-Module Viso

         Find all modules which mention Visio in (their package manifests) in all repositories
      .EXAMPLE
         Find-Module -Author jrich523

         Finds all modules by jrich523 in all repositories
      .EXAMPLE
         Find-Module -Author jrich523 -ModuleName PSVA -Repository GitHub

         Finds a specific module by a specific author in a specific repository
      .OUTPUTS
         PoshCode.Search.ModuleInfo
   #>
   [CmdletBinding()]
   Param
   (
      # Term to Search for
      [string]$SearchTerm,
        
      # Search for modules published by a particular author.
      [Parameter(ValueFromPipelineByPropertyName=$true)]
      [string]$Author,

      # Search for a specific module.
      [alias('Repo','Name','MN')]
      [Parameter(ValueFromPipelineByPropertyName=$true)]
      [string]$ModuleName,

      # The path of a configured repository (allows wildcards), or a hashtable of @{RepositoryType=@("RepositoryRootUri")}
      [Parameter(ValueFromPipelineByPropertyName=$true)]
      $Repository
   )
    
   process {
      if($Repository -is [hashtable]) {
         $ConfiguredRepositories = $Repository
      } else {
         # Filter Repositories
         $ConfiguredRepositories = (Get-ConfigData).Repositories
         if($Repository) {
            $ks = $ConfiguredRepositories.Keys |%{ $_ }
            foreach($k in $ks) {
               $ConfiguredRepositories.$k = $ConfiguredRepositories.$k | Where-Object { foreach($r in @($Repository)){ $_ -like "$r" } }
               if(!$ConfiguredRepositories.$k) {
                  $null = $ConfiguredRepositories.Remove($k)
               }
            }
         }
      }
      $null = $PSBoundParameters.Remove("Repository")
      
      Write-Verbose ($ConfiguredRepositories | Out-String)


      foreach($RepoName in $ConfiguredRepositories.Keys) {
         Import-Module "${PSScriptRoot}\Repositories\${RepoName}"
      }

      ## Get all the "FindModule" cmdlets from nested modules
      $FindCommands = $MyInvocation.MyCommand.Module.NestedModules | % { $_.ExportedCommands['FindModule'] } 

      foreach($RepoName in $ConfiguredRepositories.Keys) {

         Write-Verbose "Get-Command FindModule -Module '${RepoName}'"
            $FindCommands | Where-Object { $_.ModuleName -eq ${RepoName} } | % {

            Write-Verbose "${RepoName}\$_"
            foreach($root in @($ConfiguredRepositories.${RepoName})) {

               Write-Progress "Searching Module Repositories" "Searching ${Repository} ${Root}"
               try {
                  &$_ @PSBoundParameters -Root $root | Add-Member NoteProperty ModuleType SearchResult -Passthru
               }
               catch 
               {
                  Write-Warning "Error Searching ${RepoName} $($_)"
               }
            }
         }
      }
   }
}

Export-ModuleMember -Function 'Find-Module'