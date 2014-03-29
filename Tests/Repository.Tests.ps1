[CmdletBinding()]param()

Import-Module PSAINT -Force # https://github.com/pester/Pester
Import-Module PoshCode -Min 4.0.0.4 # http://poshcode.org/Modules/PoshCode.psd1
Import-Module "$PSScriptRoot\..\Repository.psm1" -Force -ErrorAction Stop

#     test "" {
#        arrange {
#
#        }
#        act {
#
#        }
#        assert {
#           Assert-That {  }
#        }
#     } -Category ExpandPackage

# TODO: package this cleverness into PSAINT as a mocking framework



test "Base Case: Search" {

   arrange {
      New-MockCmdlet Import-LocalStorage {
         @{ Repositories = @{ FileSystem = "PoshCodeRegistry" } } 
      } -ModuleName "PoshCode","Configuration"

      # calls Import-LocalStorage which is mocked above!
      $config = Get-ConfigData

      Assert-That { $config.InstallPaths -eq $null } -FailMessage "Mock Failed."
      Assert-That { $config.Repositories.Count -eq 1 } -FailMessage "ConfigData needs to be set for testing."
      Assert-That { $config.Repositories.FileSystem -eq "PoshCodeRegistry" } -FailMessage "ConfigData missing PoshCodeRegistry."
   }
   act {
      $Modules = Find-Module
   }
   assert {
      Assert-That { $Modules.Count -gt 5 }
      # Assert-That { $NoSuchRepo } -FailMessage "Expected an error from NoSuchRepo"
      # Assert-That { $Modules | Where Name -eq "PoshCode" }
      
      $Modules | Assert-That Name -FailMessage "Modules must all have names"
      # $Modules | Assert-That PackageInfoUrl -FailMessage "Modules must all have PackageInfoUrl"
      $Error.Remove($NoSuchRepo)
   }
} -Category Search


test "Filtered Search" {
   arrange {
      New-MockCmdlet Import-LocalStorage { 
         @{ Repositories = @{ 
               FileSystem = "PoshCodeRegistry"
               NoSuchRepo = "https://api.github.com/search/code"
      } } } -Module "PoshCode","Configuration"

      # calls Import-LocalStorage which is mocked above!
      $config = Get-ConfigData

      Assert-That { $config.InstallPaths -eq $null } -FailMessage "Mock Failed."
      Assert-That { $config.Repositories.Count -eq 2 } -FailMessage "ConfigData needs to be set for testing."
      Assert-That { $config.Repositories.FileSystem -eq "PoshCodeRegistry" } -FailMessage "ConfigData missing PoshCodeRegistry."
      Assert-That { $config.Repositories.NoSuchRepo -eq "https://api.github.com/search/code" } -FailMessage "ConfigData missing PoshCodeRegistry."
   }
   act {
      # If the Repository filter doesn't work, this will throw on NoSuchRepo
      $Modules = Find-Module -Repository "PoshCodeRegistry"
   }
   assert {
      foreach($module in $Modules) { 
         Assert-That { $module.Repository.Keys -eq "FileSystem" } -FailMessage "Modules should all be from the FileSystem"
         Assert-That { $module.Repository.FileSystem -like "PoshCodeRegistry"} -FailMessage "Modules must all be from the 'PoshCodeRegistry' root"
      }
   }
} -Category Search