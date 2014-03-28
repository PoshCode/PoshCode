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
            [xml]$content = $reader.ReadToEnd()
        } catch {
            [xml]$content= $wr.Content
        } finally {
            if($reader) { $reader.Close() }
        }
        $Global:XmlContent = $content 
        foreach($m in $content.feed.entry) {
            New-Object psobject -Property @{
                'Author'=$m.author.name
                'Name'=$m.title.innertext
                'Version' = $m.properties.Version
                'Description'=$m.summary.innertext
                # The PackageInfoUri doesn't exist for NuGet, you have to call GetUpdates():
                'PackageInfoUri'="https://www.nuget.org/api/v2/GetUpdates()?packageIds='$($m.title.innertext)'&versions='0.0'&includePrerelease=false&includeAllVersions=false"
                'DownloadUri'=$m.content.src
                'ModuleInfoUri'=$m.properties.ProjectUrl
                'LicenseUri'=$m.properties.LicenseUrl
               
                'Repository' = @{ NuGet = $Root }
            } | % {
                $_.pstypenames.Insert(0,'PoshCode.ModuleInfo')
                $_.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
                $_.pstypenames.Insert(0,'PoshCode.Search.NuGet.ModuleInfo')
                Write-Output $_
            } | Sort {
               $N,$V=$_.Version -split '-'; $N=$N -split '\.'

               @(for($i=0;$i-lt4;$i++){ 
                  "{0:d9}" -f $( if($N.Length -eq $i) {0} else { try{[int]$N[$i]}catch{0} })
               }) +@( if($V){ $V } else { "z"*9 } ) -join "."
            }
        }
    }
}