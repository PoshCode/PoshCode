# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}
# FULL # END FULL

function FindModule {
    [CmdletBinding()]
    param(
        # Term to Search for (defaults to find "all" modules)
        [string]$SearchTerm,

        # Search for modules published by a particular author.
        [string]$Author,

        # Search for a specific module.
        [string]$ModuleName,

        # Search for an exact version
        [string]$Version,

        [string[]]$Tags,

        [switch]$IncludePrerelease,

        [Parameter(Mandatory=$true)]
        $Root
    )
    Begin {
        $uri = [uri]$Root
        #web based
        if($uri.Scheme -match "http")
        {
            $content = Read-NuGetEntry ([xml](Invoke-WebRequest $root | Select-Object -ExpandProperty content))
        }
        #file based
        else
        {
            [xml]$content = Get-Content $Root
        }
    }
    
    process {
      if($ModuleName)
        {
            #using match to make it a little more flexible
            $content = $content | Where-Object { $_.name -match $ModuleName}
            Write-Verbose "Filtering by ModuleName: $ModuleName"
        }
        elseif($SearchTerm)
        {
            #which fields? all?
            
            Write-Verbose "Filtering by SearchTerm: $SearchTerm"
        }
        if($Author)
        {
            #using match to be more flexible
            $content = $content | Where-Object {$_.Author -match $Author}
            Write-Verbose "Filtering by Author: $Author"
        }
        if($Version)
        {
            #any need to convert to version object?
            if($Version -ne '*')
            {    
                $content = $content | Where-Object {$_.version -eq $Version}
                Write-Verbose "Filtering by Version: $version"
            }
            else
            {
                Write-Verbose "Wildcard provided, returning all versions"
            }
        }
        else
        {
            Write-Verbose "Returning all versions"
        }
        
        if(!$IncludePrerelease)
        {
            $content = $content | Where-Object {-not $_.IsPrerelease}
            Write-Verbose "Excluding Prerelease modules"  
        }
        else
        {
            Write-Verbose "Including prerelease modules"
        }

        #add type name and output
        $content | ForEach-Object {$_.pstypenames.Insert(0,'PoshCode.Search.File.NuGet.ModuleInfo') }
        Write-Output $content
        
    }
}