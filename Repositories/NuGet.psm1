$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { Split-Path $_.Value -Parent }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
}

Import-Module $PoshCodeModuleRoot\Atom.psm1

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
    process {
        $filters = @()

        if($ModuleName)
        {
            $ModuleName = $ModuleName.ToLowerInvariant()
            $filters += "tolower(Id) eq '$ModuleName'"
            Write-Verbose "Filtering by ModuleName: $ModuleName"
        } elseif($SearchTerm) {
            # Currently, we don't "search" we just 
            $SearchTerm = $SearchTerm.ToLowerInvariant()
            $filters += "indexof(tolower(Id),'$SearchTerm') ge 0"
            Write-Verbose "Filtering by SearchTerm: $SearchTerm"
        }
        if($Author)
        {
            $Author = $Author.ToLowerInvariant()
            $filters += "tolower(Authors) eq '$Author'"
        }
        if($Version)
        {
            if($Version -ne '*'){
                $Version = $Version.ToLowerInvariant()
                $filters += "tolower(Version) eq '$Version'"
            }
        } else {
            $filters += "IsLatestVersion"
        }
        if(!$IncludePrerelease) {
            $filters += "not IsPrerelease"
        }

        $filter = $filters -join " and "

       #$search = "{1}Packages()?`$filter=tolower(Id)+eq+'{0}'&`$orderby=Id" -f $NuGetPackageId.ToLower(), $Source
    
        Write-Verbose "`$orderby=LastUpdated&`$filter=${filter}"
      
        $wr = Invoke-WebRequest $Root -Body @{'$filter'=$filter; '$orderby'='Published desc' } 
        # Read the data using the right character set, because Invoke-WebRequest doesn't
        try {
            $null = $wr.RawContentStream.Seek(0,"Begin")
            $reader = New-Object System.IO.StreamReader $wr.RawContentStream, $wr.BaseResponse.CharacterSet
            $Content = $reader.ReadToEnd()
        } catch {
            $Content = $wr.Content
        } finally {
            if($reader) { $reader.Close() }
        }

        ConvertFrom-AtomFeed $Content -AdditionalData @{ Repository = $Root } | % {

            $output = New-Object psobject -Property $_

            $output.pstypenames.Insert(0,'PoshCode.ModuleInfo')
            $output.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
            $output.pstypenames.Insert(0,'PoshCode.Search.NuGet.ModuleInfo')
            Write-Output $output 
        }
    }
}

Export-ModuleMember -Function FindModule
