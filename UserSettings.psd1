# You can edit this file using the ConfigData commands: Get-ConfigData and Set-ConfigData
# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder
# Note that the default InstallPaths here are the ones recommended by Microsoft:
# http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350
#
# Repositories: must be an array of hashtables with Type and Root
#   Optionally, Repositories may have a name (useful for filtering Find-Module)
#   and may include settings/parameters for the Repository's FindModule command

@{
  InstallPaths = @{
    CommonPath = '{ProgramFiles}\WindowsPowerShell\Modules'
    UserPath = '{Personal}\WindowsPowerShell\Modules'
  }
  Repositories = @(@{
    Type = 'File'
    Root = 'https://github.com/psget/psget/raw/master/Directory.xml'
    Name = 'PSGet'
    CacheTimeSeconds = 900
  },@{
    Type = 'Folder'
    Root = '\\PoshCode.org\DavWWWRoot\Modules'
    Name = 'PoshCode'
  },@{
    Type = 'GitHub'
    Root = 'https://api.github.com/search/code'
  },@{
    Type = 'NuGet'
    Root = 'https://www.nuget.org/api/v2/Packages'
    Name = 'NuGet'
    IncludePrerelease = $True
  },@{
    Type = 'NuGet'
    Root = 'https://chocolatey.org/api/v2/Packages'
    Name = 'Chocolatey'
    Tags = 'PowerShell', 'Module'
    SearchByDefault = $true
  })
}
