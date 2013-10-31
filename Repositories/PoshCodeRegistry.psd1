@{
  LastUpdated = "2013-10-25T16:25:20Z"
  Modules = @{
    "PSAINT" = @{
      Name = 'PSAINT'
      Description = 'A PowerShell module for 3-As testing'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageManifestUri = 'http://poshcode.org/Modules/PSAINT.psd1'
      LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
      ModuleInfoUri = 'http://huddledmasses.org/arrange-act-assert-intuitive-testing/'
      RequiredModules = @(@{
        Name = 'Reflection'
        PackageManifestUri = 'http://PoshCode.org/Modules/Reflection.psd1'
      })
    }
    "PoshCode" = @{
      Name = 'PoshCode'
      Description = 'PowerShell Packaging Module and Script Sharing'    
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageManifestUri = 'http://poshcode.org/Modules/PoshCode.psd1'
      LicenseUri = 'http://opensource.org/licenses/ms-pl'
      ModuleInfoUri = 'https://github.com/Jaykul/poshcode'
    }
    "Reflection" = @{
      Name = 'Reflection'
      Description = 'A .Net Framework Interaction Module for PowerShell'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageManifestUri = 'http://poshcode.org/Modules/Reflection.psd1'
      ModuleInfoUri = 'http://huddledmasses.org/'
      LicenseUri = 'license.txt'
      RequiredModules = @(@{
        Name = 'Autoload'
        PackageManifestUri = 'http://PoshCode.org/Modules/Autoload.psd1'
      })
    }
    "Autoload" = @{
      Name = 'Autoload'
      Description = 'Autoload function like the Korn shell, and can inject functions into Modules'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageManifestUri = 'http://poshcode.org/Modules/Autoload.psd1'
      LicenseUri = 'license.txt'
      ModuleInfoUri = 'http://huddledmasses.org/'
    }
    "WASP" = @{
      Name = 'Wasp'
      Description = 'PowerShell Packaging Module'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageManifestUri = 'http://poshcode.org/Modules/WASP.psd1'
      ModuleInfoUri = 'https://wasp.codeplex.com/'
      LicenseUri = 'https://wasp.codeplex.com/license'
      RequiredModules = @(@{
        Name = 'Reflection'
        PackageManifestUri = 'http://PoshCode.org/Modules/Reflection.psd1'
      })
    }
    "VisioAutomation" = @{
      Name = "VisioAutomation"
      Description = "PowerShell Visio Automation"
      Author = 'Justin Rich'

      PackageManifestUri="https://raw.github.com/jrich523/PSVA/master/visioAutomation.psd1"
      ModuleInfoUri="https://github.com/jrich523/PSVA"
      LicenseUri="http://opensource.org/licenses/ms-pl"
    }
    "NimblePowerShell" =  @{
      Name = "NimblePowerShell"
      Description = "Nimble Storage Module"
      Author = 'Justin Rich'

      PackageManifestUri="https://raw.github.com/jrich523/NimblePowerShell/master/Nimble.psd1"
      ModuleInfoUri="https://github.com/jrich523/NimblePowerShell"
      LicenseUri="http://opensource.org/licenses/ms-pl"
    }
    "PSReadLine" = @{
      Name = 'PSReadLine'
      Description = 'Great command line editing in the PowerShell console host'
      Author = 'Jason Shirk'

      DownloadUri = 'https://github.com/lzybkr/PSReadLine/archive/master.zip'
      ZipFolder = '*\PSReadLine'
      LicenseUri = 'https://raw.github.com/lzybkr/PSReadLine/master/License.txt'
      ModuleInfoUri = 'https://github.com/lzybkr/PSReadLine'
    }
    "Pester" = @{
      Name = 'Pester'
      Description = 'A BDD style testing tool for Powershell'
      Author = 'Pester Team'
      # Note the problem with this module is that I can't write a ZipFolder (the module is in the root)
      # And since there's no Pester.psd1, the module ends up in Pester-master
      DownloadUri = 'https://github.com/pester/Pester/archive/master.zip'
      LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
      ModuleInfoUri = 'https://github.com/Pester/Pester'
   }
  }
}