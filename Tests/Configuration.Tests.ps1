[CmdletBinding()]param()

Import-Module PSAINT # http://poshcode.org/Modules/PSAINT.psd1
Import-Module "$PSScriptRoot\..\Configuration.psm1" -Force -ErrorAction Stop

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



test "Get Special Folder" {
   arrange {
      $FolderNames = [Environment+SpecialFolder].GetFields("Public,Static").Name | Sort
   }
   act {
      $truth = @{}
      foreach($name in $FolderNames) {
         $truth.$name = [Environment]::GetFolderPath($name)
      }
   }
   assert {
      foreach($name in $FolderNames) {
         if($truth.$name) {
            $truth.$name.MustEqual((Get-SpecialFolder $name -Value))
         } else {
            Assert-That { $null -eq (Get-SpecialFolder $name -Value) } -FailMessage "Get-SpecialFolder '$name' returned a value that's not in the Environment!"
         }
      }
   }
}