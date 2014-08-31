$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { Split-Path $_.Value -Parent }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
}

Import-Module $PoshCodeModuleRoot\Atom.psm1
if(!(Get-Command Invoke-WebReques[t] -ErrorAction SilentlyContinue)){
  Import-Module $PoshCodeModuleRoot\InvokeWeb
}

function Convert-Wildcard {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        $Field,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        $Text,

        [Switch]$Contains
    )
    process {
        if(![System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Text)) {
            $Text = $Text.ToLowerInvariant()
            if($Contains) {
                "indexof(tolower($Field),'$Text') ge 0"
            } else {
                "tolower($Field) eq '$Text'"
            }
        } else {
            $Text -split "\[.*?]|\?|\*" | Where-Object { $_.Length } | Convert-Wildcard $Field -Contains
        }
    }
}


function FindModule {
    [CmdletBinding()]
    param(
        # Term to Search for (defaults to find "all" modules)
        [string]$SearchTerm,

        # Search for modules published by a particular author.
        [string]$Author,

        # Search for a specific module.
        [string]$Name,

        # Search for an exact version
        [string]$Version,

        [string[]]$Tags,

        [switch]$IncludePrerelease,

        [Parameter(Mandatory=$true)]
        $Root
    )
    process {
        $filters = @()

        if($Name)
        {
            $filters += Convert-Wildcard Id $Name
            Write-Verbose "Filtering by ModuleName: $Name"
        } elseif($SearchTerm) {
            $filters += "(" + (@(
                Convert-Wildcard Id $SearchTerm -Contains
                Convert-Wildcard Tags $SearchTerm -Contains
                Convert-Wildcard Description $SearchTerm -Contains
            ) -join ' or ') + ")"
            Write-Verbose "Filtering by SearchTerm: $SearchTerm"
        }
        if($Tags -and $Tags.Length -gt 0) {
            $filters += $Tags | Convert-Wildcard Tags -Contains
            Write-Verbose "Filtering by SearchTerm: $Tag"
        }
        if($Author)
        {
            $filters += Convert-Wildcard Authors $Author -Contains
        }
        if($Version)
        {
            if($Version -ne '*'){
                $filters += Convert-Wildcard Version $Version
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
      
        $wr = Invoke-WebRequest "$Root/Packages" -Body @{'$filter'=$filter; '$orderby'='Published desc' } 
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

        ConvertFrom-AtomFeed $Content -AdditionalData @{ SourceUri = $Root; SourceType = "NuGet" } | 
            Where {
                $(  if($Name)
                    {
                        $_.Name -like $Name
                    } elseif($SearchTerm) {
                        $_.Id -like $SearchTerm -or $_.Tags -like $SearchTerm -or $_.Description -like $SearchTerm
                    } else { $true }
                ) -and $(
                    if($Tags -and $Tags.Length -gt 0) {
                        $(foreach($p in $Tags){ foreach($t in $_.Tags) { $t -like $p } }) -contains $true
                    } else { $true }
                ) -and $(
                    if($Author)
                    {
                        $_.Author -like $Author
                    } else { $true }
                ) -and $(
                    if($Version)
                    {
                        $_.Version -like $Version
                    } else { $true }
                )
            }
    }
}



function PushModule {
    [CmdletBinding()]
    param(
        # The file you want to publish
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$Package,

        # Search for modules published by a particular author.
        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        $Root
    )
    process {
        [Byte[]]$Bytes = Get-Content $Package -Encoding Byte
        $Response = Invoke-WebRequest -Uri "$Root/package/" -Method "PUT" -ContentType "application/octet-stream" -Body $Bytes -Headers @{"X-NuGet-ApiKey" = $APIKey}
        $Response | Select StatusCode, StatusDescription
    }
}
Export-ModuleMember -Function FindModule, PushModule
