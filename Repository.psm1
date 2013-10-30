$CommonParameters = "ErrorAction", "WarningAction", "Verbose", "Debug", "ErrorVariable", "WarningVariable", "OutVariable", "OutBuffer", "PipelineVariable"

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
      [alias('Name','MN')]
      [Parameter(ValueFromPipelineByPropertyName=$true)]
      [string]$ModuleName,

      # The path of a configured repository (allows wildcards), or a hashtable of @{RepositoryType=@("RepositoryRootUri")}
      [Parameter(ValueFromPipelineByPropertyName=$true)]
      $Repository,

      [int]
      $Limit = 0
   )
   begin {
      $Count = 0      
   }
   process {
      if(($Repository -is [hashtable]) -or ($Repository -as [hashtable[]])) {
         $ConfiguredRepositories = $Repository
      } else {
         $ConfiguredRepositories = @((Get-ConfigData).Repositories)
         if(!$Repository) {
            $ConfiguredRepositories = $ConfiguredRepositories | Where-Object { $_.SearchByDefault }
         } else {
            # Filter Repositories
            # $ConfiguredRepositories = @((Get-ConfigData).Repositories)
            $ConfiguredRepositories = $(
               $Matching = $ConfiguredRepositories | Where-Object { foreach($r in @($Repository)){ $_.Type -like "$r" } }
               if(!$Matching) {
                  Write-Verbose "No matching Type"
                  $Matching = $ConfiguredRepositories | Where-Object { foreach($r in @($Repository)){ $_.Name -like "$r" } }
               }
               if(!$Matching) {
                  Write-Verbose "No matching Name"
                  $Matching = $ConfiguredRepositories | Where-Object { foreach($r in @($Repository)){ $_.Root -like "$r" } }
               }
               $Matching
            )
         }
      }
      $null = $PSBoundParameters.Remove("Repository")
      $null = $PSBoundParameters.Remove("Limit")
      
      # Write-Verbose ($ConfiguredRepositories | %{ $_ | Format-Table -HideTableHeaders }| Out-String -Width 110)
      foreach($Repo in $ConfiguredRepositories) {
         $Command = Import-Module "${PSScriptRoot}\Repositories\$(${Repo}.Type)" -Passthru | % { $_.ExportedCommands['FindModule'] } 

         Write-Verbose "$(${Repo}.Type)\FindModule -Root $($Repo.Root)"

         foreach($k in @($Repo.Keys) | Where-Object { ($Command.Parameters.Keys -contains $_) -and ("Type" -notcontains $_)}) {
            $PSBoundParameters.$k = $Repo.$k
         }

         $Mandatory = $Command.Parameters.Values | 
            Where-Object { $_.Attributes.Mandatory -and ($PSBoundParameters.Keys -NotContains $_.Name)} |
            ForEach-Object { $_.Name }


         if($Mandatory) {
            Write-Warning "Not searching $($Repo.Type), missing mandatory parameter(s) '$($Mandatory -join ''',''')'"
         } else {
            # Write-Verbose ($PSBoundParameters | Format-Table | Out-String -Width 110)
            try {
               if($Limit -gt 0) {
                  &$Command @PSBoundParameters | Add-Member NoteProperty ModuleType SearchResult -Passthru | 
                     ForEach-Object { if(($Count++) -lt $Limit){ $_ } else { break } 
                     }
               } else {
                  &$Command @PSBoundParameters | Add-Member NoteProperty ModuleType SearchResult -Passthru
               }
            }
            catch 
            {
               Write-Warning "Error Searching $($Repo.Type) $($Repo.Root)"
            }
            if($Limit -gt 0 -and $Count -ge $Limit) { return }
         }
      }
   }
}

Export-ModuleMember -Function 'Find-Module'