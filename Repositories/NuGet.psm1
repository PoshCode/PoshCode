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
            Read-NuGetEntry ([xml]$reader.ReadToEnd())
        } catch {
            Read-NuGetEntry ([xml]$wr.Content)
        } finally {
            if($reader) { $reader.Close() }
        }
    }
}

function Read-NuGetEntry {
    [CmdletBinding(DefaultParameterSetName="Entries")]
    param(
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0,ParameterSetName="Entries",Mandatory=$true)]
        [System.Xml.XmlNode]$Entry,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Base,

        [Switch]$Sortable
    )
    process {
        if($Entry.Feed) {
            $FeedBase = $Entry.Feed.base
            $Entries = $Entry.Feed.Entry
        }
        if($Entry.Entry) {
            $FeedBase = $Entry.Entry.base
            $Entries = $Entry.Entry
        }       
        
        foreach($m in $Entries) {
            $p = $m.properties
            @{
                'Author'=if($m.author -and $m.author.name){$m.author.name}else{''}
                'Name'=if($m.title){$m.title.innertext}else{''}
                'Description'=if($m.summary){$m.summary.innertext}else{''}
                'DownloadUrl'=if($m.content -and $m.content.src){$m.content.src}else{$null}

                'PackageInfoUrl'= $(if(!$FeedBase) { $m.id } else {
                    # The PackageInfoUrl doesn't exist for NuGet, you have to call GetUpdates():
                    "${FeedBase}GetUpdates()?packageIds='$(if($m.title){$m.title.innertext}else{''})'&versions='0.0'&includePrerelease=false&includeAllVersions=false"
                })
                
                'RequiredModules'=if(!$m.Dependencies) {$null} else {
                    @($m.Dependencies -split '\|' | % { $N,$V,$Null = $_ -split ':'; @{ModuleName=$N; ModuleVersion=$V} })
                }

                'Version' = $p.Version
                'ProjectUrl'=$p.ProjectUrl
                'Copyright'=$p.Copyright
                'LicenseUrl'=$p.LicenseUrl
                'RequireLicenseAcceptance'=[bool]$p.RequireLicenseAcceptance
                'Tags'=$p.Tags -split ' '
                'IsPrerelease'=[bool]$p.IsPrerelease

                'Repository' = @{ NuGet = $Root }
            } | ForEach-Object {
                if($Sortable) {
                    $_.SortableVersion = {
                        $N,$V=$_.Version -split '-'; $N=$N -split '\.'

                        @(for($i=0;$i-lt4;$i++){ 
                            "{0:d9}" -f $( if($N.Length -eq $i) {0} else { try{[int]$N[$i]}catch{0} })
                        }) +@( if($V){ $V } else { "z"*9 } ) -join "."
                    }
                }
                $output = New-Object psobject -Property $_

                $output.pstypenames.Insert(0,'PoshCode.ModuleInfo')
                $output.pstypenames.Insert(0,'PoshCode.Search.ModuleInfo')
                $output.pstypenames.Insert(0,'PoshCode.Search.NuGet.ModuleInfo')
                Write-Output $output
            }
        }
    }
}

