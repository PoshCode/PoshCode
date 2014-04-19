###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Atom.psm1 defines the core commands for Atom Entries and Feeds
##

# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  Write-Warning "TESTING: No PoshCodeModuleRoot"
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1
# FULL # END FULL


# Code for generating Atom feed xml files
function Export-AtomFeed {
    [CmdletBinding()]
    param(
        # Specifies the path to save the feed to.
        [Parameter(Mandatory=$true, Position=0)]
        $Path,

        # Specifies the module info objects to export to the feed.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        # If set, output the atom file
        [Switch]$Passthru
    )
    begin { $data = @() }
    process { $data += @($InputObject) }
    end { 
        Set-Content $Path $($InputObject | ConvertTo-AtomFeed) 
        if($Passthru) {
            Get-Item $Path
        }
    }
}

function ConvertTo-AtomFeed {
    [CmdletBinding(DefaultParameterSetName="NuGet")]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        $InputObject,

        # The URL where this module package info feed will be hosted (may contain a single entry, or an entry per version)
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true, ParameterSetName="Hosted", HelpMessage="The url where the .packageInfo file will be hosted.")]
        $PackageInfoUrl,
        # The URL where the .nupkg package file will be hosted for downloading
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true, ParameterSetName="Hosted", HelpMessage="The url where the .nupkg package file will be hosted.")]
        $DownloadUrl,
        # The URL for the NuGet repository
        [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName="NuGet")]
        $RepositoryUrl
    )
    begin {
        $entries = @()
    }
    process {
        if(!$PackageInfoUrl -and $InputObject.PackageInfoUrl) {
            $PackageInfoUrl = $InputObject.PackageInfoUrl
        }
        if(!$DownloadUrl -and $InputObject.DownloadUrl) {
            $DownloadUrl = $InputObject.DownloadUrl
        }
        $Version = if($InputObject.Version) { $InputObject.Version } else { $InputObject.ModuleVersion }

        $ModuleName = if($InputObject.ModuleName){$InputObject.ModuleName}else{$InputObject.Name}

        $entries += "
        <entry>
            <id>$([System.Security.SecurityElement]::Escape($PackageInfoUrl))</id>
            <title type='text'>$([System.Security.SecurityElement]::Escape($ModuleName))</title>
            <summary type='text'>$([System.Security.SecurityElement]::Escape($InputObject.Description))</summary>
            <author><name>$([System.Security.SecurityElement]::Escape($InputObject.Author))</name></author>
            <content type='application/zip' src='$([uri]::EscapeUriString($DownloadUrl))' />
            <m:properties>
                <d:Version>$([System.Security.SecurityElement]::Escape($Version))</d:Version>
                $(if($InputObject.RequiredModules){
                    "<d:Dependencies>$([System.Security.SecurityElement]::Escape($(foreach($D in $InputObject.RequiredModules){ $D.ModuleName + ':'+ $D.ModuleVersion }) -join ':|'))</d:Dependencies>"
                })
                <!-- These are RECOMMENDED: -->
                <d:Copyright>$([System.Security.SecurityElement]::Escape($InputObject.Copyright))</d:Copyright>
                $(if($InputObject.ModuleIconUrl) {
                    "<d:IconUrl>$([System.Security.SecurityElement]::Escape($InputObject.ModuleIconUrl))</d:IconUrl>"
                } elseif($InputObject.IconUrl) {
                    "<d:IconUrl>$([System.Security.SecurityElement]::Escape($InputObject.IconUrl))</d:IconUrl>"
                })
                $(if($InputObject.LicenseUrl){
                    "<d:ProjectUrl>$([System.Security.SecurityElement]::Escape($InputObject.ProjectUrl))</d:ProjectUrl>"
                })
                $(if($InputObject.LicenseUrl){
                    "<d:RequireLicenseAcceptance m:type='Edm.Boolean'>$(($InputObject.RequireLicenseAcceptance -eq "true").ToString().ToLower())</d:RequireLicenseAcceptance>
                    <d:LicenseUrl>$([System.Security.SecurityElement]::Escape($InputObject.LicenseUrl))</d:LicenseUrl>"
                 })
                <d:Tags>$([System.Security.SecurityElement]::Escape(($InputObject.Tags -join ' ')))</d:Tags>
                $(
                if($InputObject.IsPrerelease -ne $null){
                    "<d:IsPrerelease m:type='Edm.Boolean'>$(($InputObject.IsPrerelease -eq "true").ToString().ToLower())</d:IsPrerelease>"
                })
            </m:properties>
        </entry>"

    }
    end {
        [xml]$doc = "<?xml version='1.0'?>
        <feed $(if($RepositoryUrl){"xml:base='$([uri]::EscapeUriString($RepositoryUrl))'"})
                xmlns='http://www.w3.org/2005/Atom' 
                xmlns:d='http://schemas.microsoft.com/ado/2007/08/dataservices' 
                xmlns:m='http://schemas.microsoft.com/ado/2007/08/dataservices/metadata'>

            <id>$([System.Security.SecurityElement]::Escape($PackageInfoUrl))</id>
            <title type='text'>Module Updates</title>
            <updated>$((Get-Date).ToUniversalTime().ToString('o'))</updated>
            $($entries -join "`n")
        </feed>"

        $StringWriter = New-Object System.IO.StringWriter
        $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter
        $xmlWriter.Formatting = "indented"
        $xmlWriter.Indentation = 2
        $xmlWriter.IndentChar = " "
        $doc.WriteContentTo($XmlWriter)
        $XmlWriter.Flush()
        $StringWriter.Flush()
        Write-Output $StringWriter.ToString()
    }
}

function Import-AtomFeed {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true, Position=0)]
        [Alias("PSPath")]
        [String]$Path,

        [int]$Count,

        [Switch]$Sortable,

        [Hashtable]$AdditionalData = @{}
    )
    process {
        ConvertFrom-AtomFeed -Input (Get-Content $Path -Delimiter ([char]0)) -Count:$Count -Sortable:$Sortable -AdditionalData:$AdditionalData
    }
}

function ConvertFrom-AtomFeed {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
        [String]$InputObject,

        [int]$Count,

        [Switch]$Sortable,

        [Hashtable]$AdditionalData = @{}
    )
    begin { $data = @() }
    process { $data += @($InputObject) }
    end {
        Write-Verbose "Read $($data.Count) items"
        [Xml]$Feed = $data -join ""

        if($Feed.Feed) {
            $FeedBase = $Feed.Feed.base
            $Entries = $Feed.Feed.Entry
        }
        if($Feed.Entry) {
            $FeedBase = $Feed.Entry.base
            $Entries = $Feed.Entry
        }

        $outCount = 0
        foreach($m in $Entries) {
            $outCount += 1
            if($Count -and ($outCount -gt $Count)) { break }
            $p = $m.properties
            Write-Verbose "Properties: $($p.InnerXml)"
            @{
                'Author'=if($m.author -and $m.author.name){$m.author.name}else{''}
                'Name'=if($m.title){$m.title.innertext}else{''}
                'Description'=if($p.Description -is [string]){$p.Description}else{''}
                'DownloadUrl'=if($m.content -and $m.content.src){$m.content.src}else{$null}
                'PackageType' = if($m.content -and $m.content.type){$m.content.type}else{$null}

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
                'Tags'=$p.Tags -split ' '
                # Unless these are explicitly true, they're false.
                'RequireLicenseAcceptance'=$p.RequireLicenseAcceptance -eq "true"
                'IsPrerelease'=$p.IsPrerelease -eq "true"

            } + $AdditionalData | ForEach-Object {
                if($Sortable) {
                    $_.SortableVersion = {
                        $N,$V=$_.Version -split '-'; $N=$N -split '\.'

                        @(for($i=0;$i-lt4;$i++){ 
                            "{0:d9}" -f $( if($N.Length -eq $i) {0} else { try{[int]$N[$i]}catch{0} })
                        }) +@( if($V){ $V } else { "z"*9 } ) -join "."
                    }
                }

                Write-Output $_
            }
        }
    }
}

<# Code for generating Nuspec xml files


function New-PackageFeed {
    #.Synopsis
    #   Generate a Module Version feed with the latest package info in it
    [CmdletBinding(DefaultParameterSetName="Hosted")]
    param(
        # The name of the module to add to the feed
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleName")]
        [String]$Name,

        # The version to add to the feed
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleVersion")]
        [String]$Version,

        # The Author to put in the feed
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        $Author=$Env:USERNAME,

        # The Description of the module to put in the feed
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        $Description,

        # The Project website for the module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        $ProjectUrl,

        # Searchable keywords to associate with this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string[]]$Tags,

        # The URL where this module package info feed will be hosted (may contain a single entry, or an entry per version)
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true, ParameterSetName="Hosted", HelpMessage="The url where the .packageInfo file will be hosted.")]
        $PackageInfoUrl,
        # The URL where the .nupkg package file will be hosted for downloading
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true, ParameterSetName="Hosted", HelpMessage="The url where the .nupkg package file will be hosted.")]
        $DownloadUrl,
        # The URL for the NuGet repository
        [Parameter(ValueFromPipelineByPropertyName=$true, ParameterSetName="NuGet")]
        $RepositoryUrl,

        # The copyright statement for this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        $Copyright,

        # The license URL for this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        $LicenseUrl,

        # An icon URL for this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias("IconUrl")]
        $ModuleIconUrl,

        # If set, the end user should be required to agree to the license before install (may not be enforced by unattended or console installs)
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [switch]$RequireLicenseAcceptance,

        # A list of required modules
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Array]$RequiredModules,

        # If set, the package is a pre-release (beta) version of the module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [switch]$IsPrerelease
    )
    process {

        $PackageInfoUrl = $( if($PackageInfoUrl){"$PackageInfoUrl"}else{"$RepositoryUrl/GetUpdates"} )

        # Generate a (partial) nuget package info entry:
        [xml]$doc = "<?xml version='1.0'?>
        <feed $(if($RepositoryUrl){"xml:base='$([uri]::EscapeUriString($RepositoryUrl))'"})
               xmlns='http://www.w3.org/2005/Atom' 
               xmlns:d='http://schemas.microsoft.com/ado/2007/08/dataservices' 
               xmlns:m='http://schemas.microsoft.com/ado/2007/08/dataservices/metadata'>

            <id>$([System.Security.SecurityElement]::Escape($PackageInfoUrl))</id>
            <title type='text'>Module Updates</title>
            <updated>$((Get-Date).ToUniversalTime().ToString('o'))</updated>

            <entry>
                <id>$([System.Security.SecurityElement]::Escape($PackageInfoUrl))</id>
                <title type='text'>$([System.Security.SecurityElement]::Escape($Name))</title>
                <summary type='text'>$([System.Security.SecurityElement]::Escape($Description))</summary>
                <author><name>$([System.Security.SecurityElement]::Escape($Author))</name></author>
                <content type='application/zip' src='$([uri]::EscapeUriString($DownloadUrl))' />
                <m:properties>
                    <d:Version>$([System.Security.SecurityElement]::Escape($Version))</d:Version>
                    $(if($RequiredModules){
                    "<d:Dependencies>$([System.Security.SecurityElement]::Escape($(foreach($D in $RequiredModules){ $D.ModuleName + ':'+ $D.ModuleVersion }) -join ':|'))</d:Dependencies>"
                    })
                    <!-- These are RECOMMENDED: -->
                    $(if($ModuleIconUrl){
                    "<d:IconUrl>$([System.Security.SecurityElement]::Escape($ModuleIconUrl))</d:IconUrl>"
                    })
                    <d:ProjectUrl>$([System.Security.SecurityElement]::Escape($ProjectUrl))</d:ProjectUrl>
                    <d:Copyright>$([System.Security.SecurityElement]::Escape($Copyright))</d:Copyright>
                    <d:RequireLicenseAcceptance m:type='Edm.Boolean'>$(([bool]$RequireLicenseAcceptance).ToString().ToLower())</d:RequireLicenseAcceptance>
                    <d:LicenseUrl>$([System.Security.SecurityElement]::Escape($LicenseUrl))</d:LicenseUrl>
                    <d:Tags>$([System.Security.SecurityElement]::Escape(($Tags -join ' ')))</d:Tags>
                    <d:IsPrerelease m:type='Edm.Boolean'>$(([bool]$IsPrerelease).ToString().ToLower())</d:IsPrerelease>
                </m:properties>
            </entry>
        </feed>"

        $StringWriter = New-Object System.IO.StringWriter
        $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter
        $xmlWriter.Formatting = "indented"
        $xmlWriter.Indentation = 2
        $xmlWriter.IndentChar = ' '
        $doc.WriteContentTo($XmlWriter)
        $XmlWriter.Flush()
        $StringWriter.Flush()
        Write-Output $StringWriter.ToString()
    }
}
# FULL # END FULL
#>

function Export-Nuspec {
    [CmdletBinding()]
    param(
        # Specifies the path to save the feed to.
        [Parameter(Mandatory=$true, Position=0)]
        $Path,

        # Specifies the module info objects to export to the feed.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        # If set, output the nuspec file
        [Switch]$Passthru
    )
    begin { $data = @() }
    process { $data += @($InputObject) }
    end { 
        Set-Content $Path $($InputObject |ConvertTo-Nuspec) 
        if($Passthru) {
            Get-Item $Path
        }
   }
}

function ConvertTo-Nuspec {
    [CmdletBinding(DefaultParameterSetName="NuGet")]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        $InputObject
    )
    process {
        $Id = if($InputObject.Name){ $InputObject.Name } else { $InputObject.Id }
        $Author = if($InputObject.Author) { $InputObject.Author } else { $InputObject.Authors }
        $Owners = if($InputObject.CompanyName) { $InputObject.CompanyName } else { $InputObject.Owners }
        $IconUrl = if($InputObject.ModuleIconUri) { $InputObject.ModuleIconUri } else { $InputObject.IconUrl }
        $Tags  = if(!$InputObject.Tags) { $ModulePackageKeyword -join ' ' } else {
           @(@($InputObject.Tags) + @($InputObject.Keywords) + $ModulePackageKeyword | Select-Object -Unique) -join ' '
        }
        # Generate a nuget manifest
        [xml]$doc = "<?xml version='1.0'?>
        <package xmlns='$NuGetNamespace'>
          <metadata>
            <id>$([System.Security.SecurityElement]::Escape($Id))</id>
            <version>$([System.Security.SecurityElement]::Escape($InputObject.Version))</version>
            <authors>$([System.Security.SecurityElement]::Escape($Author))</authors>
            <owners>$([System.Security.SecurityElement]::Escape($Owners))</owners>
            $(if($InputObject.LicenseUrl){
            "<licenseUrl>$([System.Security.SecurityElement]::Escape($InputObject.LicenseUrl))</licenseUrl>
            <requireLicenseAcceptance>$(([bool]$InputObject.RequireLicenseAcceptance).ToString().ToLower())</requireLicenseAcceptance>"
            })
            <projectUrl>$([System.Security.SecurityElement]::Escape($InputObject.ProjectUrl))</projectUrl>
            <iconUrl>$([System.Security.SecurityElement]::Escape($IconUrl))</iconUrl>
            <description>$([System.Security.SecurityElement]::Escape($InputObject.Description))</description>
            <releaseNotes>$([System.Security.SecurityElement]::Escape($InputObject.ReleaseNotes))</releaseNotes>
            <copyright>$([System.Security.SecurityElement]::Escape($InputObject.Copyright))</copyright>
            <tags>$([System.Security.SecurityElement]::Escape($Tags))</tags>
          </metadata>
        </package>"

        # Remove nodes without values (this is to clean up the "Url" nodes that aren't set)
        $($doc.package.metadata.GetElementsByTagName("*")) | 
           Where-Object { $_."#text" -eq $null } | 
           ForEach-Object { $null = $doc.package.metadata.RemoveChild( $_ ) }
    
        if( $InputObject.RequiredModules ) {
           $dependencies = $doc.package.metadata.AppendChild( $doc.CreateElement("dependencies", $NuGetNamespace) )
           foreach($req in $InputObject.RequiredModules) {
              $dependency = $dependencies.AppendChild( $doc.CreateElement("dependency", $NuGetNamespace) )
              if($req.Name) { $dependency.SetAttribute("id", $req.Name) }
              if($req.ModuleName) { $dependency.SetAttribute("id", $req.ModuleName) }
              if($req.Version) { $dependency.SetAttribute("version", $req.Version) }
              if($req.ModuleVersion) { $dependency.SetAttribute("version", $req.ModuleVersion) }
           }
        }

        $StringWriter = New-Object System.IO.StringWriter
        $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter
        $xmlWriter.Formatting = "indented"
        $xmlWriter.Indentation = 2
        $xmlWriter.IndentChar = " "
        $doc.WriteContentTo($XmlWriter)
        $XmlWriter.Flush()
        $StringWriter.Flush()
        Write-Output $StringWriter.ToString()
    }
}

function Import-Nuspec {
    #  .Synopsis
    #      Import NuSpec from a file path
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("PSPath")]
        [string]$Path
    )

    process {
        $ModuleInfo = $null
        if(!(Test-Path $Path)) {
            throw "File Not Found: $Path"
        }

        Write-Verbose "Importing nuget spec from `$Path: $Path"
        if(!(Test-Path $Path -PathType Leaf)) {
            $TempPath = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
            if(Test-Path $TempPath -PathType Leaf) {
                $Path = $TempPath
            }
        }

        if(Test-Path $Path -PathType Leaf) {
            $Content = Get-Content $Path -ErrorAction Stop -Delimiter ([char]0)
            try {
                ConvertFrom-Nuspec $Content
            } catch {
                $PSCmdlet.ThrowTerminatingError( $_ )
            }
        }
    }
}

function ConvertFrom-Nuspec {
   param(
      [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
      [String]$InputObject
   )
   process {
      $ErrorActionPreference = "Stop"
      $NugetManifest = ([Xml]$InputObject).package.metadata

      $NugetData = @{}
      if($NugetManifest.id)           { $NugetData.ModuleName    = $NugetManifest.id }
      if($NugetManifest.version)      { $NugetData.ModuleVersion = $NugetManifest.version }
      if($NugetManifest.authors)      { $NugetData.Author        = $NugetManifest.authors }
      if($NugetManifest.owners)       { $NugetData.CompanyName   = $NugetManifest.owners }
      if($NugetManifest.description)  { $NugetData.Description   = $NugetManifest.description }
      if($NugetManifest.copyright)    { $NugetData.Copyright     = $NugetManifest.copyright }
      if($NugetManifest.projectUrl)   { $NugetData.ProjectUrl    = $NugetManifest.projectUrl }
      if($NugetManifest.tags)         { $NugetData.Tags          = $NugetManifest.tags -split '[ ,]+' }
      if($NugetManifest.iconUrl)      { $NugetData.iconUrl       = $NugetManifest.iconUrl }
      if($NugetManifest.releaseNotes) { $NugetData.ReleaseNotes  = $NugetManifest.releaseNotes }

      if($NugetManifest.licenseUrl)   {
         $NugetData.LicenseUrl               = $NugetManifest.licenseUrl 
         $NugetData.RequireLicenseAcceptance = $NugetManifest.requireLicenseAcceptance -eq "True"
      }
  
      if($NugetManifest.dependencies) {
         $NugetData.RequiredModules = foreach($dep in $NugetManifest.dependencies.dependency) {
            @{ ModuleName = $dep.id; ModuleVersion = $dep.version }
         }
      }

      $NugetData
   }
}

