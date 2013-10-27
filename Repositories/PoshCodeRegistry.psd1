@{
  "PSAINT" = @{
    Name = 'PSAINT'
    Description = 'A PowerShell module for 3-As testing'
    Author = 'Joel Bennett'
    AuthorEmail = 'Jaykul@HuddledMasses.org'

    PackageManifestUri = 'http://poshcode.org/Modules/PSAINT.psd1'
    LicenseUri = 'license.txt'
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
}