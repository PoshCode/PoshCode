[CmdletBinding()]param()

Import-Module PSAINT -Force -Min 1.5 # https://github.com/jaykul/PSAINT
Import-Module PoshCode -Min 4.0.0.5 # http://poshcode.org/Modules/PoshCode.psd1
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



test "Compress-Module" {

   arrange {
      $TempFolder = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
      mkdir $TempFolder | Push-Location
   }
   act {
      Write-Verbose "Compress-Module PoshCode $TempFolder -OutVariable Files"
      Compress-Module PoshCode $TempFolder -OutVariable Files -Verbose | Out-String | Write-Host -Fore Cyan
   }
   assert {
      Assert-That { $Files.Count -eq 2 }
      
      Pop-Location
      Remove-Item $TempFolder -Recurse
   }
} -Category Search
