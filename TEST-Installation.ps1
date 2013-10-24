[CmdletBinding()]param()

Import-Module PSAINT # http://poshcode.org/Modules/PSAINT.psd1

Import-Module "$PSScriptRoot\Installation.psm1" -ErrorAction Stop

test "Expand Package" {
   arrange {
      $ModulePackage = Convert-Path "~\Documents\WindowsPowerShell\Modules\WASP.psmx"
      $ModulePath = Convert-Path "~\Documents\WindowsPowerShell\Modules\WASP\"
      if(!(Test-Path $ModulePackage)) {
         $null = Invoke-WebRequest -Uri "http://poshcode.org/Modules/WASP-2.0.0.6.psmx" -OutFile $ModulePackage
      }
      if(Test-Path $ModulePath) {
         Remove-Item $ModulePath -Recurse -Force
      }
   }
   act {
      $ModuleFiles = Expand-Package -Package $ModulePackage -InstallPath (Split-Path $ModulePath) -Force -Passthru
   }
   assert {
      Assert-That { Test-Path $ModulePath }

      # I could test for all the files, but there's no point.
      # If these three are there, the rest are there too...
      $ModuleFiles.FullName.MustContain( (Join-Path $ModulePath "WASP.psm1") )
      $ModuleFiles.FullName.MustContain( (Join-Path $ModulePath "WASP.psd1") )
      $ModuleFiles.FullName.MustContain( (Join-Path $ModulePath "package.psd1") )

      $ModuleFiles | % {
         Assert-That { Test-Path $_ }
      }
   }
} -Category ExpandPackage


test "Expand Zip" {
   arrange {
      $ModulePackage = Join-Path (Convert-Path "~\Documents\WindowsPowerShell\Modules") "WASP.zip"
      $ModulePath = Convert-Path "~\Documents\WindowsPowerShell\Modules\WASP\"
      if(!(Test-Path $ModulePackage)) {
         $null = Invoke-WebRequest -Uri "http://poshcode.org/Modules/WASP-2.0.0.6.zip" -OutFile $ModulePackage
      }
      if(Test-Path $ModulePath) {
         Remove-Item $ModulePath -Recurse -Force
      }
   }
   act {
      $ModuleFiles = Expand-Package -Package $ModulePackage -InstallPath (Split-Path $ModulePath) -Force -Passthru
   }
   assert {
      Assert-That { Test-Path $ModulePath }

      # I could test for all the files, but there's no point.
      # If these three are there, the rest are there too...
      $ModuleFiles.FullName.MustContain( (Join-Path $ModulePath "WASP.psm1") )
      $ModuleFiles.FullName.MustContain( (Join-Path $ModulePath "WASP.psd1") )
      $ModuleFiles.FullName.MustContain( (Join-Path $ModulePath "package.psd1") )

      $ModuleFiles | % {
         Assert-That { Test-Path $_ }
      }
   }
} -Category ExpandPackage
