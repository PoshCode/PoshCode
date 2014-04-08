# You can edit this file using the ConfigData commands: Get-ConfigData and Set-ConfigData
# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder
# Note that the default InstallPaths here are the ones recommended by Microsoft:
# http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350
#
# Repositories: must a hashtable of hashtables with Type and Root
#   The keys in the Repositories hashtable are the unique names, which can be used to filter Find-Module
#   The keys in the nested hashtables MUST include the TYPE and ROOT, and may include additional settings for the Repository's FindModule command

@{
    InstallPaths = @{
        CommonPath = '{ProgramFiles}\WindowsPowerShell\Modules'
        UserPath = '{Personal}\WindowsPowerShell\Modules'
    }
    Repositories = @{
        PSGet = @{
            Type = 'File'
            Root = 'https://github.com/psget/psget/raw/master/Directory.xml'
            CacheTimeSeconds = 900
        }
        PoshCode = @{
            Type = 'Folder'
            Root = '\\PoshCode.org\DavWWWRoot\Modules'
        }
        GitHub = @{
            Type = 'GitHub'
            Root = 'https://api.github.com/search/code'
        }
        NuGet = @{
            Type = 'NuGet'
            Root = 'https://www.nuget.org/api/v2/Packages'
            IncludePrerelease = $True
        }
        Chocolatey = @{
            Type = 'NuGet'
            Root = 'https://chocolatey.org/api/v2/Packages'
            Name = 'Chocolatey'
            Tags = 'PowerShell', 'Module'
            SearchByDefault = $true
        }
    }
}
