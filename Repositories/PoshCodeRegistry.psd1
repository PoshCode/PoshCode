@{
  LastUpdated = "2013-10-25T16:25:20Z"
  Modules = @{
    "PSAINT" = @{
      Name = 'PSAINT'
      Description = 'A PowerShell module for 3-As testing'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUrl = 'http://poshcode.org/Modules/PSAINT.packageInfo'
      LicenseUrl = 'http://www.apache.org/licenses/LICENSE-2.0'
      ProjectUrl = 'http://huddledmasses.org/arrange-act-assert-intuitive-testing/'
      RequiredModules = @(@{
        Name = 'Reflection'
        PackageInfoUrl = 'http://PoshCode.org/Modules/Reflection.packageInfo'
      })
    }
    "PoshCode" = @{
      Name = 'PoshCode'
      Description = 'PowerShell Packaging Module and Script Sharing'    
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUrl = 'http://poshcode.org/Modules/PoshCode.packageInfo'
      LicenseUrl = 'http://opensource.org/licenses/ms-pl'
      ProjectUrl = 'https://github.com/Jaykul/poshcode'
    }
    "Reflection" = @{
      Name = 'Reflection'
      Description = 'A .Net Framework Interaction Module for PowerShell'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUrl = 'http://poshcode.org/Modules/Reflection.packageInfo'
      ProjectUrl = 'http://huddledmasses.org/'
      LicenseUrl = 'license.txt'
      RequiredModules = @(@{
        Name = 'Autoload'
        PackageInfoUrl = 'http://PoshCode.org/Modules/Autoload.packageInfo'
      })
    }
    "Autoload" = @{
      Name = 'Autoload'
      Description = 'Autoload function like the Korn shell, and can inject functions into Modules'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUrl = 'http://poshcode.org/Modules/Autoload.packageInfo'
      LicenseUrl = 'license.txt'
      ProjectUrl = 'http://huddledmasses.org/'
    }
    "WASP" = @{
      Name = 'Wasp'
      Description = 'PowerShell Packaging Module'
      Author = 'Joel Bennett'
      AuthorEmail = 'Jaykul@HuddledMasses.org'

      PackageInfoUrl = 'http://poshcode.org/Modules/WASP.packageInfo'
      ProjectUrl = 'https://wasp.codeplex.com/'
      LicenseUrl = 'https://wasp.codeplex.com/license'
      RequiredModules = @(@{
        Name = 'Reflection'
        PackageInfoUrl = 'http://PoshCode.org/Modules/Reflection.packageInfo'
      })
    }
    #"VisioAutomation" = @{
    #  Name = "VisioAutomation"
    #  Description = "PowerShell Visio Automation"
    #  Author = 'Justin Rich'

    #  PackageInfoUrl="https://raw.github.com/jrich523/PSVA/master/VisioAutomation/VisioAutomation.packageInfo"
    #  ProjectUrl="https://github.com/jrich523/PSVA"
    #  LicenseUrl="http://opensource.org/licenses/ms-pl"
    #}
    #"NimblePowerShell" =  @{
    #  Name = "NimblePowerShell"
    #  Description = "Nimble Storage Module"
    #  Author = 'Justin Rich'

    #  PackageInfoUrl="https://raw.github.com/jrich523/NimblePowerShell/master/Nimble.packageInfo"
    #  ProjectUrl="https://github.com/jrich523/NimblePowerShell"
    #  LicenseUrl="http://opensource.org/licenses/ms-pl"
    #}
    "PSReadLine" = @{
      Name = 'PSReadLine'
      Description = 'Great command line editing in the PowerShell console host'
      Author = 'Jason Shirk'

      DownloadUrl = 'https://github.com/lzybkr/PSReadLine/blob/master/PSReadline.zip'
      ZipFolder = '*\PSReadLine'
      LicenseUrl = 'https://raw.github.com/lzybkr/PSReadLine/master/License.txt'
      ProjectUrl = 'https://github.com/lzybkr/PSReadLine'
    }
  }
}