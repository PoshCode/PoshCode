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

test "Get Scope Storage Path" {
    arrange {
        $AllM = Get-Module -ListAvailable 
        $Module = $AllM | Where { $_.ModuleBase -like "${Home}*" } | Select -First 1
        if(!$Module) { $Module = $Allm[0] }

        $Name = $Module.Name
        $Base = $Module.ModuleBase
        $Local = Get-SpecialFolder LocalApplicationData -Value
    }
    act {
        $Default = Get-ScopeStoragePath -Module $Module -Name "UserSettings"
        $User    = Get-ScopeStoragePath -Module $Module -Name "UserSettings" -Scope "User"
        $Module  = Get-ScopeStoragePath -Module $Module -Name "UserSettings" -Scope "Module"
    }
    assert {
        $Module.MustEqual( (Join-Path ${Base} "UserSettings.psd1") )
        $User.MustEqual( (Join-Path ${Local} "PoshCode\$Name\UserSettings.psd1") )
        $Default.MustEqual( $Module )
    }
}