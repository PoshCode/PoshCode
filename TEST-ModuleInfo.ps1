[CmdletBinding()]param()

Import-Module PSAINT # http://poshcode.org/Modules/PSAINT.psd1

Import-Module "$PSScriptRoot\ModuleInfo.psm1" -ErrorAction Stop

test "Add Simple Names" {
   arrange {
      $ModuleInfo = Microsoft.PowerShell.Core\Get-Module PSAINT
   }
   act {
      $ModuleInfo = $ModuleInfo | Add-SimpleNames
      $RequiredModules = $ModuleInfo.RequiredModules | Select -First 1
   }
   assert {
      "Name = Reflection".MustEqual( ("Name = " + $RequiredModules.Name) )
      "ModuleName = Reflection".MustEqual( ("ModuleName = " + $RequiredModules.ModuleName) )
   }
} -Category AddSimpleNames


test "Read-Module Adds Simple Names" {
   arrange {
      $ModuleInfo = Read-Module PSAINT
   }
   act {
      $RequiredModules = $ModuleInfo.RequiredModules | Select -First 1
   }
   assert {
      "Name = Reflection".MustEqual( ("Name = " + $RequiredModules.Name) )
      "ModuleName = Reflection".MustEqual( ("ModuleName = " + $RequiredModules.ModuleName) )
   }
} -Category AddSimpleNames


test "Update-ModuleInfo Adds Simple Names" {
   arrange {
      $ModuleInfo = Read-Module PSAINT | Select -First 1
      $ModuleManifest = Update-ModuleInfo $ModuleInfo.Path
   }
   act {
      $RequiredModules = $ModuleManifest.RequiredModules | Select -First 1
   }
   assert {
      "Name = Reflection".MustEqual( ("Name = " + $RequiredModules.Name) )
      "ModuleName = Reflection".MustEqual( ("ModuleName = " + $RequiredModules.ModuleName) )
   }
} -Category AddSimpleNames


test "Update-ModuleInfo Imports Package Manifest" {
   arrange {
      $ModuleInfo = Read-Module PSAINT | Select -First 1
      $ModuleManifest = Update-ModuleInfo $ModuleInfo.Path
   }
   act {
      $RequiredModules = $ModuleManifest.RequiredModules | Select -First 1
   }
   assert {
      "Name = Reflection".MustEqual( ("Name = " + $RequiredModules.Name) )
      "ModuleName = Reflection".MustEqual( ("ModuleName = " + $RequiredModules.ModuleName) )

      "http://poshcode.org/Modules/PSAINT.psd1".MustEqual( $ModuleManifest.ModuleInfoUri )
      "http://PoshCode.org/Modules/Reflection.psdxml".MustEqual( $RequiredModules.ModuleInfoUri )
   }
} -Category AddSimpleNames



test "Get-PackageInfo Includes Both Manifest" {
   arrange {
      $ModulePackage = "C:\Users\Joel\Documents\WindowsPowerShell\Modules\WASP.psmx"
      
      if(!(Test-Path $ModulePackage)) {
         $null = Invoke-WebRequest -Uri "http://poshcode.org/Modules/WASP-2.0.0.6.psmx" -OutFile $ModulePackage
      }
      $ModuleManifest = Get-PackageInfo $ModulePackage
   }
   act {
      $RequiredModules = $ModuleManifest.RequiredModules | Select -First 1
   }
   assert {
      "Name = Reflection".MustEqual( ("Name = " + $RequiredModules.Name) )
      "ModuleName = Reflection".MustEqual( ("ModuleName = " + $RequiredModules.ModuleName) )

      "http://poshcode.org/Modules/PSAINT.psd1".MustEqual( $ModuleManifest.ModuleInfoUri )
      "http://PoshCode.org/Modules/Reflection.psdxml".MustEqual( $RequiredModules.ModuleInfoUri )
   }
} -Category AddSimpleNames
