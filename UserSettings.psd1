# You can edit this file using the ConfigData commands: Get-ConfigData and Set-ConfigData
# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder
# Note that the default InstallPaths here are the ones recommended by Microsoft:
# http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350
#
# Repositories: must a hashtable of hashtables with Type and Root
#   The keys in the Repositories hashtable are the unique names, which can be used to filter Find-Module
#   The keys in the nested hashtables MUST include the TYPE and ROOT, and may include additional settings for the Repository's FindModule command

@{
  AuthorInfo = @{
    Copyright = 'Copyright (c) 2014 by Joel Bennett, all rights reserved.'
    Author = 'Joel Bennett'
    CompanyName = 'http://HuddledMasses.org'
  }
  InstallPaths = @{
    CommonPath = 'C:\Program Files\WindowsPowerShell\Modules'
    UserPath = 'C:\Users\Joel\Documents\WindowsPowerShell\Modules'
  }
  Repositories = @{
    Chocolatey = @{
      Root = 'https://chocolatey.org/api/v2'
      Tags = @('PowerShell','Module')
      Type = 'NuGet'
      SearchByDefault = $True
      PublishByDefault = $True
      ApiKey = '4322b657-9d22-4319-9012-1d179c21940c'
    }
    ConfigGallery = @{
      Root = 'https://msconfiggallery.cloudapp.net/api/v2'
      Type = 'NuGet'
      SearchByDefault = $True
      PublishByDefault = $True
      ApiKey = '4fe2e893-d4fc-4294-8e87-6a7c51cfe32e'
    }
    GitHub = @{
      Root = 'https://api.github.com/search/code'
      Type = 'GitHub'
    }
    NuGet = @{
      Root = 'https://www.nuget.org/api/v2/Packages'
      Type = 'NuGet'
      IncludePrerelease = $True
    }
    PSGet = @{
      Root = 'https://github.com/psget/psget/raw/master/Directory.xml'
      CacheTimeSeconds = 900
      Type = 'File'
    }
    PoshCode = @{
      Root = '\\PoshCode.org\DavWWWRoot\Modules'
      Type = 'Folder'
    }
  }
}
