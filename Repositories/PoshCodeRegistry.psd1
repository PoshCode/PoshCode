@{
  LastUpdated = "2013-10-25T16:25:20Z"
  Modules = @{
    "PSAINT" = @{
      Name = 'PSAINT'
      Description = 'A PowerShell module for 3-As testing'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUri = 'http://poshcode.org/Modules/PSAINT.packageInfo'
      LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
      ModuleInfoUri = 'http://huddledmasses.org/arrange-act-assert-intuitive-testing/'
      RequiredModules = @(@{
        Name = 'Reflection'
        PackageInfoUri = 'http://PoshCode.org/Modules/Reflection.packageInfo'
      })
    }
    "PoshCode" = @{
      Name = 'PoshCode'
      Description = 'PowerShell Packaging Module and Script Sharing'    
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUri = 'http://poshcode.org/Modules/PoshCode.packageInfo'
      LicenseUri = 'http://opensource.org/licenses/ms-pl'
      ModuleInfoUri = 'https://github.com/Jaykul/poshcode'
    }
    "Reflection" = @{
      Name = 'Reflection'
      Description = 'A .Net Framework Interaction Module for PowerShell'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUri = 'http://poshcode.org/Modules/Reflection.packageInfo'
      ModuleInfoUri = 'http://huddledmasses.org/'
      LicenseUri = 'license.txt'
      RequiredModules = @(@{
        Name = 'Autoload'
        PackageInfoUri = 'http://PoshCode.org/Modules/Autoload.packageInfo'
      })
    }
    "Autoload" = @{
      Name = 'Autoload'
      Description = 'Autoload function like the Korn shell, and can inject functions into Modules'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUri = 'http://poshcode.org/Modules/Autoload.packageInfo'
      LicenseUri = 'license.txt'
      ModuleInfoUri = 'http://huddledmasses.org/'
    }
    "WASP" = @{
      Name = 'Wasp'
      Description = 'PowerShell Packaging Module'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUri = 'http://poshcode.org/Modules/WASP.packageInfo'
      ModuleInfoUri = 'https://wasp.codeplex.com/'
      LicenseUri = 'https://wasp.codeplex.com/license'
      RequiredModules = @(@{
        Name = 'Reflection'
        PackageInfoUri = 'http://PoshCode.org/Modules/Reflection.packageInfo'
      })
    }
    #"VisioAutomation" = @{
    #  Name = "VisioAutomation"
    #  Description = "PowerShell Visio Automation"
    #  Author = 'Justin Rich'

    #  PackageInfoUri="https://raw.github.com/jrich523/PSVA/master/VisioAutomation/VisioAutomation.packageInfo"
    #  ModuleInfoUri="https://github.com/jrich523/PSVA"
    #  LicenseUri="http://opensource.org/licenses/ms-pl"
    #}
    #"NimblePowerShell" =  @{
    #  Name = "NimblePowerShell"
    #  Description = "Nimble Storage Module"
    #  Author = 'Justin Rich'

    #  PackageInfoUri="https://raw.github.com/jrich523/NimblePowerShell/master/Nimble.packageInfo"
    #  ModuleInfoUri="https://github.com/jrich523/NimblePowerShell"
    #  LicenseUri="http://opensource.org/licenses/ms-pl"
    #}
    "PSReadLine" = @{
      Name = 'PSReadLine'
      Description = 'Great command line editing in the PowerShell console host'
      Author = 'Jason Shirk'

      DownloadUri = 'https://github.com/lzybkr/PSReadLine/blob/master/PSReadline.zip'
      ZipFolder = '*\PSReadLine'
      LicenseUri = 'https://raw.github.com/lzybkr/PSReadLine/master/License.txt'
      ModuleInfoUri = 'https://github.com/lzybkr/PSReadLine'
    }
  }
}