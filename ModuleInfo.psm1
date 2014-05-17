###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## ModuleInfo.psm1 defines the core commands for reading packages and modules:
## Get-ModuleInfo, Import-Metadata, Export-Metadata
## It depends on the Configuration module and the Invoke-WebRequest cmdlet


# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  Write-Warning "TESTING: No PoshCodeModuleRoot"
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1

# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Atom", "Metadata"
Import-Module $PoshCodeModuleRoot\Atom.psm1
Import-Module $PoshCodeModuleRoot\Metadata.psm1

# FULL # END FULL


function Update-ModuleManifest {
    <#
      .Synopsis
         Creates or updates Module manifest (.psd1), package manifest (.nuspec) and data files (.packageInfo) for a module.
      .Description
         Creates a package manifest with the mandatory and optional properties
    #>   
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [string[]]
        ${Author},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [version]
        ${ClrVersion},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [Alias("Owner")]
        [string]
        ${CompanyName},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [string]
        ${Copyright},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [string]
        ${Description},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [version]
        ${DotNetFrameworkVersion},



        [AllowNull()]
        [string]
        ${DefaultCommandPrefix},

        [AllowEmptyCollection()]
        [string[]]
        ${FunctionsToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${AliasesToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${VariablesToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${CmdletsToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${TypesToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${FormatsToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${ScriptsToProcess},



        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyCollection()]
        [string[]]
        ${FileList},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [guid]
        ${Guid},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [string]
        ${HelpInfoUri},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyCollection()]
        [System.Object[]]
        ${ModuleList},

        # The name of the module to create a new package manifest(s) for
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyCollection()]
        [System.Object[]]
        ${NestedModules},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PowerShellHostName},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [version]
        ${PowerShellHostVersion},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [version]
        ${PowerShellVersion},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [System.Reflection.ProcessorArchitecture]
        ${ProcessorArchitecture},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyCollection()]
        [string[]]
        ${RequiredAssemblies},

        # The Required modules is a hashtable of ModuleName=PackageInfoUrl, or an array of module names, etc
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [System.Object[]]
        ${RequiredModules},

        [Alias('ModuleToProcess')]
        [AllowEmptyString()]
        [string]
        ${RootModule},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [System.Object]
        ${PrivateData},


        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias("Version")]
        [ValidateNotNull()]
        [version]
        ${ModuleVersion},




        # TODO: If set, require the license to be accepted during installation (not supported yet)
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$RequireLicenseAcceptance,

        # The url to a license
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$LicenseUrl,

        # The url where the module package will be uploaded
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$DownloadUrl,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$IsPrerelease,

        # a URL or relative path to a web page about this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$ProjectUrl,
      
        # The url where the module's package manifest will be uploaded (defaults to the download URI modified to ModuleName.psd1)
        [String]$PackageInfoUrl,

        # An array of keyword tags for search
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String[]]$Tags,

        # a URL or relative path to an icon for the module in gif/jpg/png form
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$IconUri,




        # Choose one category from the list:
        [ValidateSet("Active Directory", "Applications", "App-V", "Backup and System Restore", "Databases", "Desktop Management", "Exchange", "Group Policy", "Hardware", "Interoperability and Migration", "Local Account Management", "Logs and monitoring", "Lync", "Messaging & Communication", "Microsoft Dynamics", "Multimedia", "Networking", "Office", "Office 365", "Operating System", "Other Directory Services", "Printing", "Remote Desktop Services", "Scripting Techniques", "Security", "Servers", "SharePoint", "Storage", "System Center", "UE-V", "Using the Internet", "Windows Azure", "Windows Update")]
        [String]$Category,




        # Automatically increment the module version number
        [Switch]$IncrementVersionNumber,

        # If set, overwrite existing files without prompting
        [Switch]$Force,

        [Switch]$NewOnly,

        [switch]${PassThru}

    )
    begin {
        $ModuleManifestProperties = 'AliasesToExport', 'Author', 'ClrVersion', 'CmdletsToExport', 'CompanyName', 'Copyright', 'DefaultCommandPrefix', 'Description', 'DotNetFrameworkVersion', 'FileList', 'FormatsToProcess', 'FunctionsToExport', 'Guid', 'HelpInfoUri', 'ModuleList', 'ModuleVersion', 'NestedModules', 'PowerShellHostName', 'PowerShellHostVersion', 'PowerShellVersion', 'PrivateData', 'ProcessorArchitecture', 'RequiredAssemblies', 'RequiredModules', 'ModuleToProcess', 'ScriptsToProcess', 'TypesToProcess', 'VariablesToExport', 'Passthru'
        $PoshCodeProperties = 'ModuleName','ModuleVersion','Author','Copyright','Description','ProjectUrl','IconUri','Tags','PackageInfoUrl','DownloadUrl','RepositoryUrl','LicenseUrl','RequireLicenseAcceptance','RequiredModules','IsPrerelease'
        $NuGetProperties = 'Name','Version','Author','CompanyName','LicenseUrl','ProjectUrl','IconUri','RequireLicenseAcceptance','Description','ReleaseNotes','Copyright','Tags','RequiredModules'
        if(!(Test-Path variable:RejectAllOverwriteOnModuleInfo)){
            $RejectAllOverwriteOnModuleInfo = $false
            $ConfirmAllOverwriteOnModuleInfo = $false
        }
    }
    end {

        $ErrorActionPreference = "Stop"
        $Manifest = Get-Module $Name -ListAvailable

        if(-not $Manifest)
        {
            $PSCmdlet.ThrowTerminatingError( (New-Error -Type System.ArgumentException "Can't find the module '$Name'" ModuleNotAvailable InvalidArgument $Name) )
        }
        elseif(@($Manifest).Count -gt 1)
        {
            $PSCmdlet.ThrowTerminatingError( (New-Error -Type System.ArgumentException "Found more than one module matching '$Name', please specify a full path instead." ModuleNotAvailable InvalidArgument $Name) )
        }

        
        # Double check there's already a manifest...
        [String]$ModuleManifestPath = $Manifest.Path
        if(!$ModuleManifestPath.EndsWith($ModuleManifestExtension)) {
            Write-Debug "Module Path isn't a module manifest path"
            $ModuleManifestPath = Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $ModuleManifestExtension)
            if(!(Test-Path $ModuleManifestPath)) {
                Write-Debug "Module Manifest not found: $ModuleManifestPath"
                $ModuleManifestPath = [IO.Path]::ChangeExtension($Manifest.Path, $ModuleManifestExtension)
            }
        }
        if(!(Test-Path $ModuleManifestPath)) {
            # TODO: change to a warning, and prompt to generate the manifest for them
            Write-Error "Module manifest not found: $ModuleManifestPath"
            return
        }

        # PrivateData has to be a hashtable.
        if($Manifest.PrivateData -and $Manifest.PrivateData -isnot [Hashtable]) {
            Write-Warning "Sorry, for the purposes of packaging, your Module manifest must use a Hashtable as the value of PrivateData. We add a '$PackageDataKey' key to your PrivateData hashtable to store the additional module information which is needed for packaging."
            throw "Incompatible PrivateData - must be a Hashtable, please see docs."
        }
        
        # Deal with setting or incrementing the module version
        if($IncrementVersionNumber -or $ModuleVersion -or $Manifest.Version -le "0.0") {
            [Version]$OldVersion = $Manifest.Version
            if($ModuleVersion) {
                Write-Debug "Setting Module Version from parameter $ModuleVersion"
                [Version]$PackageVersion = $ModuleVersion 
            } elseif($Manifest.Version -gt "0.0") {
                [Version]$PackageVersion = $Manifest.Version
            } else {
                Write-Warning "Module Version not specified properly, incrementing to 1.0"
                [Version]$OldVersion = [Version]$PackageVersion = "0.0"
            }
           
            if($IncrementVersionNumber -or $PackageVersion -le "0.0") {
                if($PackageVersion.Revision -ge 0) {
                    $PackageVersion = New-Object Version $PackageVersion.Major, $PackageVersion.Minor, $PackageVersion.Build, ($PackageVersion.Revision + 1)
                } elseif($PackageVersion.Build -ge 0) {
                    $PackageVersion = New-Object Version $PackageVersion.Major, $PackageVersion.Minor, ($PackageVersion.Build + 1)
                } elseif($PackageVersion.Minor -gt 0) {
                    $PackageVersion = New-Object Version $PackageVersion.Major, ($PackageVersion.Minor + 1)
                } else {
                    $PackageVersion = New-Object Version ($PackageVersion.Major + 1), 0
                }

                # Fix Urls
                $OldNameRegex = [regex]::escape($Name) + "(?:\.\d+){2,4}"
                $NewName = "${Name}.${PackageVersion}"
                if($Manifest.DownloadUrl -and !$DownloadUrl) {
                    $PSBoundParameters["DownloadUrl"] = $Manifest.DownloadUrl -replace $OldNameRegex, $NewName
                }
                if($Manifest.PackageInfoUrl -and !$PackageInfoUrl) {
                    $PSBoundParameters["PackageInfoUrl"] = $Manifest.PackageInfoUrl -replace $OldNameRegex, $NewName
                }
            }
        }

        # TODO: Figure out a way to get rid of ONE of these throughout PoshCode stuff
        $PSBoundParameters["ModuleVersion"] = $PackageVersion
        $PSBoundParameters["Version"] = $PackageVersion

        # Normalize RequiredModules to an array of hashtables
        # Required modules can be specified like any of the following:
        # -RequiredModules "ModuleOne"
        # -RequiredModules @{ModuleName="PowerBot"; ModuleVersion="1.0" }
        # -RequiredModules "ModuleOne", "ModuleTwo", "ModuleThree"
        # -RequiredModules @("ModuleOne", @{ModuleName="PowerBot"; ModuleVersion="1.0"} )
        # But it's always treated as an array, so the question is: did they pass in module names, or hashtables?
        if($RequiredModules -or @($Manifest.RequiredModules).Count -gt 0) {
            if(!$RequiredModules -and @($Manifest.RequiredModules).Count -gt 0) {
                $RequiredModules = @($Manifest.RequiredModules)
            }
            $RequiredModules = foreach($Module in $RequiredModules) {
                if($Module -is [String]) { 
                    $Module
                }
                else {
                    $M = @{}
                    if($Module.ModuleName) {
                        $M.ModuleName = $Module.ModuleName
                    } elseif( $Module.Name ) {
                        $M.ModuleName = $Module.Name
                    } else {
                        Write-Warning ("RequiredModules is a " + $RequiredModules.GetType().FullName + " and this Module is a " + $Module.GetType().FullName)
                        Write-Debug (($Module | Get-Member | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n")
                        throw "The RequiredModules must be an array of module names or an array of ModuleInfo hashtables or objects (which must have a ModuleName key and optionally a ModuleVersion and PackageInfoUrl)"
                    }

                    if($Module.ModuleVersion) {
                        $M.ModuleVersion = $Module.ModuleVersion
                    } elseif( $Module.Version ) {
                        $M.ModuleVersion = $Module.Version
                    }

                    if($Module.ModuleGuid) {
                        $M.ModuleGuid = $Module.ModuleGuid
                    } elseif( $Module.Guid ) {
                        $M.ModuleGuid = $Module.Guid
                    }

                    #if($Module.PackageInfoUrl) {
                    #    $M.PackageInfoUrl = $Module.PackageInfoUrl
                    #} elseif($Prop = $Module | Get-Member *Url -Type Property | Select-Object -First 1) {
                    #    $M.PackageInfoUrl = $Module.($Prop.Name)
                    #}

                    $M
                }
            }
            $PSBoundParameters["RequiredModules"] = $RequiredModules
        }


        $PoshCodeProperties = 'ProjectUrl','IconUrl','Tags','PackageInfoUrl','DownloadUrl','RepositoryUrl','LicenseUrl','RequireLicenseAcceptance','RequiredModules','IsPrerelease'
        $NuGetProperties = 'Name','Version','Author','CompanyName','LicenseUrl','ProjectUrl','IconUrl','RequireLicenseAcceptance','Description','ReleaseNotes','Copyright','Tags','RequiredModules'

        # Generate or update the PrivateData hashtable. 
        [Hashtable]$PackageData = $Manifest.PrivateData.$PackageDataKey
        


        # Get the current module manifest
        $Tokens = $Null; $ParseErrors = $Null
        $AST = [System.Management.Automation.Language.Parser]::ParseFile( (Convert-Path $ModuleManifestPath), [ref]$Tokens, [ref]$ParseErrors)
        $Hashtable = $Ast.Find( { param($a) $a -is [System.Management.Automation.Language.HashtableAst] }, $false )
        [string]$Code = $Ast.ToString()

        #Requires -Version 4.0
        [String[]]$ParameterKeys = $Hashtable.KeyValuePairs.Item1.Value
        
        $OrderedKeys = foreach($Key in $PSBoundParameters.Keys) { 
                            if($Key -in $ParameterKeys) { 
                                $Item = $Hashtable.KeyValuePairs | Where-Object { $_.Item1.Value -eq $Key }
                                @{  Name = $Item.Item1.Value
                                    Start = $Item.Item1.Extent.StartOffset
                                    Length = $Item.Item2.Extent.EndOffset - $Item.Item1.Extent.StartOffset
                                }
                            } elseif($Match = ([regex]"#\s*$Key\s*=.*").Match($Code)) {
                                @{  Name = $Key
                                    Start = $Match.Index
                                    Length = $Match.Length
                                }
                            } else {
                                @{  Name = $Key
                                    Start = $Hashtable.Extent.EndOffset - 1
                                    Length = 0
                                }
                            }
                        }
        $OrderedKeys = $OrderedKeys | Sort Start

        foreach($Key in $OrderedKeys) {
                $Code = $Code.Remove($Start, $Length).Insert($Start, "$Key = $(ConvertTo-Metadata $PSBoundParameters.$Key)\n")
        }

        Set-Content $ModuleManifestPath $Code
    }
}





function Set-ModuleInfo {
    <#
      .Synopsis
         Creates or updates Module manifest (.psd1), package manifest (.nuspec) and data files (.packageInfo) for a module.
      .Description
         Creates a package manifest with the mandatory and optional properties
    #>   
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        # The name of the module to create a new package manifest(s) for
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline='True', ValueFromPipelineByPropertyName='True')]
        [String]$Name,

        [AllowEmptyCollection()]
        [System.Object[]]
        ${NestedModules},

        [guid]
        ${Guid},

        [AllowEmptyString()]
        [string[]]
        ${Author},

        [AllowEmptyString()]
        [Alias("Owner")]
        [string]
        ${CompanyName},

        [AllowEmptyString()]
        [string]
        ${Copyright},

        [Alias('ModuleToProcess')]
        [AllowEmptyString()]
        [string]
        ${RootModule},

        [Alias("Version")]
        [ValidateNotNull()]
        [version]
        ${ModuleVersion},

        [AllowEmptyString()]
        [string]
        ${Description},

        [System.Reflection.ProcessorArchitecture]
        ${ProcessorArchitecture},

        [version]
        ${PowerShellVersion},

        [version]
        ${ClrVersion},

        [version]
        ${DotNetFrameworkVersion},

        [string]
        ${PowerShellHostName},

        [version]
        ${PowerShellHostVersion},

        # The Required modules is a hashtable of ModuleName=PackageInfoUrl, or an array of module names, etc
        [System.Object[]]
        ${RequiredModules},

        [AllowEmptyCollection()]
        [string[]]
        ${TypesToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${FormatsToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${ScriptsToProcess},

        [AllowEmptyCollection()]
        [string[]]
        ${RequiredAssemblies},

        [AllowEmptyCollection()]
        [string[]]
        ${FileList},

        [AllowEmptyCollection()]
        [System.Object[]]
        ${ModuleList},

        [AllowEmptyCollection()]
        [string[]]
        ${FunctionsToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${AliasesToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${VariablesToExport},

        [AllowEmptyCollection()]
        [string[]]
        ${CmdletsToExport},

        [AllowNull()]
        [System.Object]
        ${PrivateData},

        [AllowNull()]
        [string]
        ${HelpInfoUri},

        [switch]
        ${PassThru},

        [AllowNull()]
        [string]
        ${DefaultCommandPrefix},

        # The url where the module package will be uploaded
        [String]$DownloadUrl,
      
        # The url where the module's package manifest will be uploaded (defaults to the download URI modified to ModuleName.psd1)
        [String]$PackageInfoUrl,

        # The url to a license
        [String]$LicenseUrl,

        # If set, require the license to be accepted during installation (not supported yet)
        [Switch]$RequireLicenseAcceptance,

        # Choose one category from the list:
        [ValidateSet("Active Directory", "Applications", "App-V", "Backup and System Restore", "Databases", "Desktop Management", "Exchange", "Group Policy", "Hardware", "Interoperability and Migration", "Local Account Management", "Logs and monitoring", "Lync", "Messaging & Communication", "Microsoft Dynamics", "Multimedia", "Networking", "Office", "Office 365", "Operating System", "Other Directory Services", "Printing", "Remote Desktop Services", "Scripting Techniques", "Security", "Servers", "SharePoint", "Storage", "System Center", "UE-V", "Using the Internet", "Windows Azure", "Windows Update")]
        [String]$Category,

        # An array of keyword tags for search
        [String[]]$Tags,

        # a URL or relative path to your personal avatar in gif/jpg/png form
        [String]$AuthorAvatarUri,
        
        # the address for your your company website
        [String]$CompanyUri,

        # a URL or relative path to your corporate logo in gif/jpg/png form
        [String]$CompanyIconUri,

        # a URL or relative path to a web page about this module
        [String]$ProjectUrl,

        # a URL or relative path to an icon for the module in gif/jpg/png form
        [String]$IconUrl,

        # a web URL for a bug tracker or support forum, or a mailto: address for the author/support team.
        [String]$SupportUri,

        # Automatically increment the module version number
        [Switch]$IncrementVersionNumber,

        # If set, overwrite existing files without prompting
        [Switch]$Force,

        [Switch]$NewOnly
    )
    begin {
        $ModuleManifestProperties = 'AliasesToExport', 'Author', 'ClrVersion', 'CmdletsToExport', 'CompanyName', 'Copyright', 'DefaultCommandPrefix', 'Description', 'DotNetFrameworkVersion', 'FileList', 'FormatsToProcess', 'FunctionsToExport', 'Guid', 'HelpInfoUri', 'ModuleList', 'ModuleVersion', 'NestedModules', 'PowerShellHostName', 'PowerShellHostVersion', 'PowerShellVersion', 'PrivateData', 'ProcessorArchitecture', 'RequiredAssemblies', 'RequiredModules', 'ModuleToProcess', 'ScriptsToProcess', 'TypesToProcess', 'VariablesToExport', 'Passthru'
        $PoshCodeProperties = 'ModuleName','ModuleVersion','Author','Copyright','Description','ProjectUrl','IconUrl','Tags','PackageInfoUrl','DownloadUrl','RepositoryUrl','LicenseUrl','RequireLicenseAcceptance','RequiredModules','IsPrerelease'
        $NuGetProperties = 'Name','Version','Author','CompanyName','LicenseUrl','ProjectUrl','IconUrl','RequireLicenseAcceptance','Description','ReleaseNotes','Copyright','Tags','RequiredModules'
        if(!(Test-Path variable:RejectAllOverwriteOnModuleInfo)){
            $RejectAllOverwriteOnModuleInfo = $false
            $ConfirmAllOverwriteOnModuleInfo = $false
        }
    }
    process {
        $ErrorActionPreference = "Stop"
        $Manifest = Get-ModuleInfo $Name | Select-Object * -First 1
        if(!$Manifest) {
            $Manifest = Get-ModuleInfo $Name -ListAvailable | Select-Object * -First 1
        }

        $Path = "$($Manifest.ModuleManifestPath)"
        if(!$Path.EndsWith($ModuleManifestExtension) -or !(Test-Path $Path)){ 
            Write-Debug "Manifest file not found: $Path"
            $Path = "$($Manifest.Path)"
            if(!$Path.EndsWith($ModuleManifestExtension) -or !(Test-Path $Path)){ 
                Write-Debug "Not a manifest file: $Path"
                $Path = Join-Path $Manifest.ModuleBase ($Path + $ModuleManifestExtension)
                if(!(Test-Path $Path)){ 
                     Write-Debug "Manifest file not found: $Path"
                     $Path = [IO.Path]::ChangeExtension($Manifest.Path, $ModuleManifestExtension)
                }
            }
        }
        if(Test-Path $Path) {
            Write-Debug "ImportModuleInfo. Manifest: $Path"

            $Manifest = ImportModuleInfo $Path
        } else {
            Write-Warning "No Manifest file: $Path"

            # When loading a module without an existing manifest, punt
            $ModuleManifestProperties = @('Copyright', 'ModuleToProcess','ModuleVersion')
        }

        Write-Debug ("Loaded $Name " + (($Manifest | Format-List * | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n"))

        if(@($Manifest).Count -gt 1) {
            Write-Error "Found more than one module matching '$Name', please Import-Module the one you want to work with and try again"
            $Manifest
        }

        if(!$Manifest) {
            throw "Couldn't find module $Name"
        }

        if($ModuleVersion) {
            Write-Debug "Setting Module Version from parameter $ModuleVersion"
            [Version]$PackageVersion = $ModuleVersion 
        } elseif($Manifest.Version -gt "0.0") {
            [Version]$PackageVersion = $Manifest.Version
        } else {
            Write-Warning "Module Version not specified properly, incrementing to 1.0"
            [Version]$OldVersion = [Version]$PackageVersion = "0.0"
        }

        if($IncrementVersionNumber -or $ModuleVersion -or $Manifest.Version -le "0.0") {
            [Version]$OldVersion = $Manifest.Version
            if($IncrementVersionNumber -or $PackageVersion -le "0.0") {
                if($PackageVersion.Revision -ge 0) {
                    $PackageVersion = New-Object Version $PackageVersion.Major, $PackageVersion.Minor, $PackageVersion.Build, ($PackageVersion.Revision + 1)
                } elseif($PackageVersion.Build -ge 0) {
                    $PackageVersion = New-Object Version $PackageVersion.Major, $PackageVersion.Minor, ($PackageVersion.Build + 1)
                } elseif($PackageVersion.Minor -gt 0) {
                    $PackageVersion = New-Object Version $PackageVersion.Major, ($PackageVersion.Minor + 1)
                } else {
                    $PackageVersion = New-Object Version ($PackageVersion.Major + 1), 0
                }

                # Fix Urls

                $OldNameRegex = [regex]::escape($Name) + "(?:\.\d+){2,4}"
                $NewName = "${Name}.${PackageVersion}"
                if($Manifest.DownloadUrl -and !$DownloadUrl) {
                    $PSBoundParameters["DownloadUrl"] = $Manifest.DownloadUrl -replace $OldNameRegex, $NewName
                }
                if($Manifest.PackageInfoUrl -and !$PackageInfoUrl) {
                    $PSBoundParameters["PackageInfoUrl"] = $Manifest.PackageInfoUrl -replace $OldNameRegex, $NewName
                }
            }
        }

        # TODO: Figure out a way to get rid of one of these throughout PoshCode stuff
        $PSBoundParameters["ModuleVersion"] = $PackageVersion
        $PSBoundParameters["Version"] = $PackageVersion

        # Normalize RequiredModules to an array of hashtables
        if(!$RequiredModules -and @($Manifest.RequiredModules).Count -gt 0) {
            $RequiredModules = @($Manifest.RequiredModules)
        }
        if($RequiredModules){
            # Required modules can be specified like any of the following:
            # -RequiredModules "ModuleOne"
            # -RequiredModules @{ModuleName="PowerBot"; ModuleVersion="1.0" }
            # -RequiredModules "ModuleOne", "ModuleTwo", "ModuleThree"
            # -RequiredModules @( @{ModuleName="PowerBot"; ModuleVersion="1.0"; PackageInfoUrl="https://raw.github.com/Jaykul/PowerBot/master/PowerBot.packageInfo"}, ... )
            # But it's always treated as an array, so the question is: did they pass in module names, or hashtables?
            $RequiredModules = foreach($Module in $RequiredModules) {
                if($Module -is [String]) { 
                    @{ModuleName=$Module} 
                } 
                else {
                    $M = @{}
                    if($Module.ModuleName) {
                        $M.ModuleName = $Module.ModuleName
                    } elseif( $Module.Name ) {
                        $M.ModuleName = $Module.Name
                    } else {
                        Write-Warning ("RequiredModules is a " + $RequiredModules.GetType().FullName + " and this Module is a " + $Module.GetType().FullName)
                        Write-Debug (($Module | Get-Member | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n")
                        throw "The RequiredModules must be an array of module names or an array of ModuleInfo hashtables or objects (which must have a ModuleName key and optionally a ModuleVersion and PackageInfoUrl)"
                    }

                    if($Module.ModuleVersion) {
                        $M.ModuleVersion = $Module.ModuleVersion
                    } elseif( $Module.Version ) {
                        $M.ModuleVersion = $Module.Version
                    }

                    if($Module.ModuleGuid) {
                        $M.ModuleGuid = $Module.ModuleGuid
                    } elseif( $Module.Guid ) {
                        $M.ModuleGuid = $Module.Guid
                    }

                    if($Module.PackageInfoUrl) {
                        $M.PackageInfoUrl = $Module.PackageInfoUrl
                    } elseif($Prop = $Module | Get-Member *Url -Type Property | Select-Object -First 1) {
                        $M.PackageInfoUrl = $Module.($Prop.Name)
                    }

                    $M 
                }
            }
            $PSBoundParameters["RequiredModules"] = $RequiredModules
        }

        foreach($Key in $PSBoundParameters.Keys) {
            Write-Debug "Should update from parameter ${Key}: $($Manifest.$Key) = $($PSBoundParameters.$Key)?"
            if(($PSBoundParameters.$Key -is [Array]) -or $Manifest.$Key -ne $PSBoundParameters.$Key) {
                Write-Verbose "Update Module Manifest ${Key}: $($Manifest.$Key)"
                $Manifest = Add-Member -InputObject $Manifest -Name $Key -MemberType NoteProperty -Value $PSBoundParameters.$Key -Force -PassThru 
            }
        }
        ## Warn users about missing URLs
        if(!$Manifest.DownloadUrl) {
            Write-Warning "The DownloadUrl property is not set. This package will only work for upgrade if hosted by a nuget server such as Chocolatey.org"
        } elseif(!$Manifest.PackageInfoUrl) {
            Write-Warning "The PackageInfoUrl property is not set. This package will require the user to download the full package to check for an upgrade unless it's hosted by a nuget server."
        }


        Write-Debug ("Exporting $Name " + (($Manifest | Format-List * | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n"))

        $ModuleManifestPath = Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $ModuleManifestExtension)
        $PackageInfoPath = Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $PackageInfoExtension)
        $NuSpecPath = Join-Path $Manifest.ModuleBase ($($Manifest.Name) + $NuSpecManifestExtension)

        Write-Verbose "Calculated paths:`nPackageInfoPath: $packageInfoPath`nNuSpecPath:     $NuSpecPath`nModuleManifest:  $ModuleManifestPath"

        if($PSCmdlet.ShouldProcess("Generating module manifest $ModuleManifestPath", "Generate .psd1 ($ModuleManifestPath)?", "Generating module manifest for $($Manifest.Name) v$($Manifest.Version)" )) {
            if($Force -Or !(Test-Path $ModuleManifestPath -ErrorAction SilentlyContinue) -Or (!$NewOnly -and $PSCmdlet.ShouldContinue("The manifest '$ModuleManifestPath' already exists, do you want to wipe and replace it?", "Generating manifest for $($Manifest.Name) v$($Manifest.Version)", [ref]$ConfirmAllOverwriteOnModuleInfo, [ref]$RejectAllOverwriteOnModuleInfo))) {
                # All the parameters, except "Path"
                $ModuleManifest = $Manifest | ConvertToHashtable $ModuleManifestProperties -IgnoreEmptyProperties
                # Fix the Required Modules for New-ModuleManifest
                if( $ModuleManifest.RequiredModules ) {
                    $ModuleManifest.RequiredModules = $ModuleManifest.RequiredModules | % { 
                        $null = $_.Remove("PackageInfoUrl"); 
                        if(!$_.ContainsKey("ModuleVersion")) {  $_.ModuleName } else { $_ }
                    }
                }
            
                # New-ModuleManifest can't handle Hashtables
                if($ModuleManifest.PrivateData -isnot [Hashtable]) {
                    New-ModuleManifest -Path $ModuleManifestPath @ModuleManifest
                    # Force manifests to be compatible with PowerShell 2
                    $Content = Get-Content $ModuleManifestPath -Delimiter ([char]0)
                    $Content = $Content -replace "(?m)^RootModule = ","ModuleToProcess = "
                    Set-Content $ModuleManifestPath -Value $Content
                } else {
                    $ModuleManifest | Export-Metadata -Path $ModuleManifestPath
                }
            }
        }

        if($PSCmdlet.ShouldProcess("Generating package info $PackageInfoPath", "Generate .packageInfo ($PackageInfoPath)?", "Generating package info for $($Manifest.Name) v$($Manifest.Version)" )) {
            if($Force -Or !(Test-Path $PackageInfoPath -ErrorAction SilentlyContinue) -Or (!$NewOnly -and $PSCmdlet.ShouldContinue("The packageInfo '$PackageInfoPath' already exists, do you want to wipe and replace it?", "Generating packageInfo for $($Manifest.Name) v$($Manifest.Version)", [ref]$ConfirmAllOverwriteOnModuleInfo, [ref]$RejectAllOverwriteOnModuleInfo))) {
                Write-Verbose "Exporting PackageInfo file: $PackageInfoPath"
                $PoshCode = $Manifest | ConvertToHashtable $PoshCodeProperties
                Write-Debug $($PoshCodeProperties -join ', ')
                Write-Debug ("Exporting $Name Info " + (($PoshCode | Format-Table | Out-String -Stream | %{ $_.TrimEnd() }) -join "`n"))
                # TODO: Export-AtomFeed
                $PoshCode | Export-AtomFeed -Path $PackageInfoPath -Passthru:$Passthru
            }
        }

        if($PSCmdlet.ShouldProcess("Generating nuget spec file $NuSpecPath", "Generate .nuspec ($NuSpecPath)?", "Generating nuget spec for $($Manifest.Name) v$($Manifest.Version)" )) {
            if($Force -Or !(Test-Path $NuSpecPath -ErrorAction SilentlyContinue) -Or (!$NewOnly -and $PSCmdlet.ShouldContinue("The nuspec '$NuSpecPath' already exists, do you want to wipe and replace it?", "Generating nuspec for $($Manifest.Name) v$($Manifest.Version)", [ref]$ConfirmAllOverwriteOnModuleInfo, [ref]$RejectAllOverwriteOnModuleInfo))) {
                #$NuGetSpec = $Manifest | Get-Member $NuGetProperties -Type Properties | ForEach-Object {$H=@{}}{ $H.($_.Name) = $Manifest.($_.Name) }{$H}
                Write-Verbose "Exporting NuSpec file: $NuSpecPath"
                $Manifest | Export-Nuspec -Path $NuSpecPath -Passthru:$Passthru
            }
        }
    }
}

# Public Function
# This is a wrapper for Get-Module which uses ImportModuleInfo to load the package manifest
# It doesn't support PSSession or CimSession, and it simply extends the output
function Get-ModuleInfo {
   # .Synopsis
   #    Get enhanced information about a Module or Package
   # .Description
   #    This is a wrapper for Get-Module which includes the information in the nuget spec and atom packageInfo entry 
   [CmdletBinding(DefaultParameterSetName='Loaded')]
   param(
      # Gets only modules with the specified names or name patterns. 
      # Wildcards are permitted. You can also pipe the names to Get-ModuleInfo. 
      # You can also specify the path to a module or package.
      [Parameter(ParameterSetName='Available', Position=0, ValueFromPipeline=$true)]
      [Parameter(ParameterSetName='Loaded', Position=0, ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [Alias("ModuleName")][string[]]
      ${Name},

      # Gets all installed modules. Get-ModuleInfo works just like Get-Module, it gets the modules in paths listed in the PSModulePath environment variable.
      # Without this parameter, Get-ModuleInfo gets only the modules that are both listed in the PSModulePath environment variable, and that are loaded in the current session. 
      [Parameter(ParameterSetName='Available', Mandatory=$true)]
      [switch]
      ${ListAvailable},

      # Force rereading the module manifest: 
      # NOTE: this may result in information that's out of sync with an imported module.
      # It's usually better to re-import the module with -Force
      [Switch]${Force}
   )
   begin
   {
      ## Fix PowerShell Bug https://connect.microsoft.com/PowerShell/feedback/details/802030
      ## BUG: if Get-Module is working, but the pipeline somehow stops, the Push-Location in the end block never happens!
      # Push-Location $Script:EmptyPath

      #try {
         $moduleName = $outBuffer = $null
         if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
         {
            $PSBoundParameters['OutBuffer'] = 1
         }

         if($PSBoundParameters.ContainsKey("Force")) {
            $null = $PSBoundParameters.Remove("Force") 
         }

         if ($PSBoundParameters.TryGetValue('Name', [ref]$moduleName))
         {
            $PSBoundParameters['Name'] = @($moduleName | Where-Object { $_ -and !$_.EndsWith($ModulePackageExtension) })
            $moduleName | Where-Object { $_ -and $_.EndsWith($ModulePackageExtension) } | ReadModulePackageInfo

            # If they passed (just) the name to a package, we need to set a fake name that couldn't possibly be a real module name
            if(($moduleName.Count -gt 0) -and ($PSBoundParameters['Name'].Count -eq 0)) {
               $PSBoundParameters['Name'] = " "
            }
         } else {
            $PSBoundParameters['Name'] = "*"
         }

         $Fake = $(foreach($key in $PSBoundParameters.Keys) { "-${key} $($PSBoundParameters.$key -join ',')" }) -join ' '
         Write-Verbose "Get-Module $Fake"

         # DO NOT REFACTOR TO IsNullOrWhiteSpace (that's .net 4 only)
         if($PSBoundParameters['Name'] -and ($PSBoundParameters['Name'] -replace '\s+').Length -gt 0) {
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Module',  [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters | ImportModuleInfo -Force:$Force}
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
         }
      #} catch {
      #   $PSCmdlet.ThrowTerminatingError( $_ )
      #}
   }

   process
   {
      #try {
         if ($PSBoundParameters.TryGetValue('Name', [ref]$moduleName))
         {
            $PSBoundParameters['Name'] = $moduleName | Where-Object { !$_.EndsWith($ModulePackageExtension) }
            $moduleName | Where-Object { $_.EndsWith($ModulePackageExtension) } | ReadModulePackageInfo
         }

         if($steppablePipeline -and $PSBoundParameters['Name'] -ne " ") {
            $steppablePipeline.Process($_)
         }
      #} catch {
      #   $PSCmdlet.ThrowTerminatingError( $_ )
      #}
   }

   end
   {
      # Pop-Location
      #try {
         if($steppablePipeline -and $PSBoundParameters['Name'] -ne " ") {
            $steppablePipeline.End()
         }
      #} catch {
      #   $PSCmdlet.ThrowTerminatingError( $_ )
      #}
   }
}

# Private Function Called by Get-ModuleInfo when you pass it the path to a package file instead of a module name.
# Basically this is the implementation of Get-ModuleInfo for working with compressed packages
# TODO: Make this work for simple .zip files if they have a ".packageInfo" or ".nuspec" file in them.
#       That way, we can use it for source zips from GitHub etc.
function ReadModulePackageInfo {
    # .Synopsis
    # Try reading the module manifest from the package
    [CmdletBinding()]
    param(
        # Path to a package to get information about
        [Parameter(ValueFromPipeline=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [Alias("PSPath")]
        [string[]]$ModulePath
    )
    process {
        foreach($mPath in $ModulePath) {
            try {
                $Package = [System.IO.Packaging.Package]::Open( (Convert-Path $mPath), [IO.FileMode]::Open, [System.IO.FileAccess]::Read )

                if(!@($Package.GetParts())) {
                    Write-Warning "File is not a valid Package, but may be a valid module zip. $mPath"
                    return
                }

                ## First load the package metadata if there is one (that has URLs in it)
                $Manifest = @($Package.GetRelationshipsByType( $PackageMetadataType ))[0]
                $NugetManifest = @($Package.GetRelationshipsByType( $ManifestType ))[0]
                $ModuleManifest = @($Package.GetRelationshipsByType( $ModuleMetadataType ))[0]

                if(!$Manifest -or !$Manifest.TargetUri) {
                    $DownloadUrl = @($Package.GetRelationshipsByType( $PackageDownloadType ))[0]
                    $ManifestUri = @($Package.GetRelationshipsByType( $PackageInfoType ))[0]
                    if((!$ManifestUri -or !$ManifestUri.TargetUri) -and (!$DownloadUrl -or !$DownloadUrl.TargetUri)) {
                        Write-Warning "This is not a full PoshCode Package, it has not specified the manifest nor a download Url"
                    }
                    $PackageInfo = @{}
                } else {
                    $Part = $Package.GetPart( $Manifest.TargetUri )
                    if(!$Part) {
                        Write-Warning "This file is not a valid PoshCode Package, the specified Package manifest is missing at $($Manifest.TargetUri)"
                        $PackageInfo = @{}
                    } else {
                        Write-Verbose "Reading Package Manifest From Package: $($Manifest.TargetUri)"
                        $PackageInfo = ImportNugetStream ($Part.GetStream())
                    }
                }

                if(!$NugetManifest -or !$NugetManifest.TargetUri) {
                    Write-Warning "This is not a NuGet Package, it does not specify a nuget manifest"
                } else {
                    $Part = $Package.GetPart( $NugetManifest.TargetUri )
                    if(!$Part) {
                        Write-Warning "This file is not a valid NuGet Package, the specified nuget manifest is missing at $($NugetManifest.TargetUri)"
                    } else {
                        Write-Verbose "Reading NuGet Manifest From Package: $($NugetManifest.TargetUri)"
                        if($NuGetManifest = ImportNugetStream ($Part.GetStream())) {
                            $PackageInfo = UpdateDictionary $NuGetManifest $PackageInfo
                        }
                    } 
                }

                ## Now load the module manifest (which has everything else in it)
                if(!$ModuleManifest -or !$ModuleManifest.TargetUri) {
                    # Try finding it by name
                    if($Package.PackageProperties.Title) {
                        $IdenfierModuleManifest = ($Package.PackageProperties.Title + $ModuleManifestExtension)
                    } else {
                        $IdenfierModuleManifest = ($Package.PackageProperties.Identifier + $ModuleManifestExtension)
                    }
                    $Part = $Package.GetParts() | Where-Object { (Split-Path $_.Uri -Leaf) -eq $IdenfierModuleManifest } | Sort-Object {$_.Uri.ToString().Length} | Select-Object -First 1
                } else {
                    $Part = $Package.GetPart( $ModuleManifest.TargetUri )
                }

                if(!$Part) {
                    Write-Warning "This package does not appear to be a PowerShell Module, can't find Module Manifest $IdenfierModuleManifest"
                } else {
                    Write-Verbose "Reading Module Manifest From Package: $($ModuleManifest.TargetUri)"
                    if($ModuleManifest = ImportManifestStream ($Part.GetStream())) {
                        ## If we got the module manifest, update the PackageInfo
                        $PackageInfo = UpdateDictionary $ModuleManifest $PackageInfo
                    }
                }
                ConvertTo-PSModuleInfo $PackageInfo
            } catch [Exception] {
                $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
                $Package.Close()
                # # ZipPackage doesn't contain a method named Dispose (causes error in PS 2)
                # # For the Package class, Dispose and Close perform the same operation
                # # There is no reason to call Dispose if you call Close, or vice-versa.
                # $Package.Dispose()
            }
        }
    }
}

        # Internal Functions for parsing Module and Package Manifest Streams from ReadModulePackageInfo
        # This is called twice from within ReadModulePackageInfo (and from nowhere else)
        function ImportManifestStream {
           #  .Synopsis
           #    Import a manifest from an IO Stream
           param(
              [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
              [System.IO.Stream]$stream,

              # Convert a top-level hashtable to an object before outputting it
              [switch]$AsObject
           )   
           try {
              $reader = New-Object System.IO.StreamReader $stream
              # This gets the ModuleInfo
              $ManifestContent = $reader.ReadToEnd()
           } catch [Exception] {
              $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
           } finally {
              if($reader) {
                 $reader.Close()
                 $reader.Dispose()
              }
              if($stream) {
                 $stream.Close()
                 $stream.Dispose()
              }
           }
           ConvertFrom-Metadata $ManifestContent | ConvertTo-PSModuleInfo -AsObject:$AsObject
        }

        # This is called once from within ReadModulePackageInfo (and from nowhere else)
        function ImportNugetStream {
           #  .Synopsis
           #      Import NuSpec from an IO Stream
           param(
              [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
              [System.IO.Stream]$stream,

              # Convert a top-level hashtable to an object before outputting it
              [switch]$AsObject
           )   
           try {
              $reader = New-Object System.IO.StreamReader $stream
              # This gets the ModuleInfo
              $NugetContent = $reader.ReadToEnd()
           } catch [Exception] {
              $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
           } finally {
              if($reader) {
                 $reader.Close()
                 $reader.Dispose()
              }
              if($stream) {
                 $stream.Close()
                 $stream.Dispose()
              }
           }
           ConvertFrom-Nuspec $NugetContent | ConvertTo-PSModuleInfo -AsObject:$AsObject
        }

# Internal function for loading the package manifests
function ImportModuleInfo {
   [CmdletBinding()]
   param(
       [Parameter(ValueFromPipeline=$true)]
       $ModuleInfo,
       # Forces (re)loading the manifest even for imported modules.
       # This is useful for when you change the manifest and then call Get-ModuleInfo without re-importing the module.
       [Switch]$Force
   )
   process {
      Write-Verbose "> Updating ModuleInfo $($ModuleInfo.GetType().Name)"
      # On PowerShell 2, Modules that aren't loaded have little information, and we need to Import-Metadata
      # Modules that aren't loaded have no SessionState. If their path points at a PSD1 file, load that
      if($Force -or (($ModuleInfo -is [System.Management.Automation.PSModuleInfo]) -and !$ModuleInfo.SessionState -and [IO.Path]::GetExtension($ModuleInfo.Path) -eq $ModuleManifestExtension)) {
         $ExistingModuleInfo = $ModuleInfo | ConvertToHashtable
         $ExistingModuleInfo.RequiredModules = $ExistingModuleInfo.RequiredModules | ConvertToHashtable Name, Version

         if($ExistingModuleInfo.ModuleManifestPath -and (Test-Path $ExistingModuleInfo.ModuleManifestPath)) {
            $ModuleInfo = $ExistingModuleInfo.Path = $ExistingModuleInfo.ModuleManifestPath
         } elseif(Test-Path ([IO.Path]::ChangeExtension($ModuleInfo.Path,$ModuleManifestExtension))) {
            $ModuleInfo = $ExistingModuleInfo.Path = [IO.Path]::ChangeExtension($ModuleInfo.Path,$ModuleManifestExtension)
         }
      }

      if(($ModuleInfo -is [string]) -and (Test-Path $ModuleInfo)) {
         $ModuleManifestPath = Convert-Path $ModuleInfo

         try {
            if(!$ExistingModuleInfo) {
               Write-Verbose "ImportModuleInfo manually loading metadata from $ModuleManifestPath"
               $ModuleInfo = Import-Metadata $ModuleManifestPath | ConvertTo-PSModuleInfo
            } else {
               Write-Verbose "ImportModuleInfo merging manually-loaded metadata from $ModuleManifestPath"
               $ModuleInfo = Import-Metadata $ModuleManifestPath | ConvertTo-PSModuleInfo
               Write-Debug "Existing ModuleInfo:`n$($ExistingModuleInfo | Format-List * | Out-String)"
               Write-Debug "Module Manifest ModuleInfo:`n$($ModuleInfo | Format-List * | Out-String)"
               # Because the module wasn't already loaded, we can't trust it's RequiredModules
               if(!$ExistingModuleInfo.RequiredModules -and $ModuleInfo.RequiredModules) {
                  $ExistingModuleInfo.RequiredModules = $ModuleInfo.RequiredModules
               }
               $ModuleInfo = UpdateDictionary $ExistingModuleInfo $ModuleInfo -ForceProperties Version
               Write-Debug "Result of merge:`n$($ModuleInfo | Format-List * | Out-String)"
               

            }
            $ModuleInfo.Path = $ModuleManifestPath
            $ModuleInfo.ModuleManifestPath = $ModuleManifestPath
            if(!$ModuleInfo.ModuleBase) {
               $ModuleInfo.ModuleBase = (Split-Path $ModuleManifestPath)
            }
            $ModuleInfo.PSPath = "{0}::{1}" -f $ModuleManifestPath.Provider, $ModuleManifestPath.ProviderPath
         } catch {
            $ModuleInfo = $null
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unable to parse Module Manifest", "InvalidResult", $_) )
         }
      }

      if($ModuleInfo) {
         $ModuleBase = Split-Path $ModuleInfo.Path
         $PackageInfoPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf)$PackageInfoExtension"
         $ModuleManifestPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf)$ModuleManifestExtension"
         $NugetManifestPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf)$NuSpecManifestExtension"

         # Modules that are actually loaded have the info of the current module as the "RequiredModule"
         # Which means the VERSION is whatever version happens to be AVAILABLE and LOADED on the box.
         # Instead of the REQUIREMENT that's documented in the module manifest
         if($ModuleInfo -isnot [Hashtable] -and $ModuleInfo.RequiredModules) {
            $RequiredManifestsWithVersions = (Import-Metadata $ModuleManifestPath).RequiredModules | Where { $_.ModuleVersion }

            for($i=0; $i -lt @($ModuleInfo.RequiredModules).Length; $i++) {
               $ReqMod = @($ModuleInfo.RequiredModules)[$i]
               foreach($RMV in $RequiredManifestsWithVersions) {
                  if($ReqMod.Name -eq $RMV.Name) {
                     Add-Member -InputObject ($ModuleInfo.RequiredModules[$i]) -Type NoteProperty -Name "Version" -Value $RMV.ModuleVersion -Force
                  }
               }
            }
         }

         if(Test-Path $NugetManifestPath) {
            Write-Verbose "Loading package info from $NugetManifestPath"
            try {
               $NugetInfo = Import-Nuspec $NugetManifestPath
            } catch {
               $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unable to parse Nuget Manifest", "InvalidResult", $_) )
            }
            if($NugetInfo){
               Write-Verbose "Update Dictionary with NugetInfo"
               $ModuleInfo = UpdateDictionary $ModuleInfo $NugetInfo
            }
         }

         ## This is the PoshCode metadata file: ModuleName.packageInfo
         # Since we're not using anything else, we won't add the aliases...
         if(Test-Path $PackageInfoPath) {
            Write-Verbose "Loading package info from $PackageInfoPath"
            try {
               $PackageInfo = Import-AtomFeed $PackageInfoPath -Count 1 | ConvertTo-PSModuleInfo
            } catch {
               $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unable to parse Package Manifest", "InvalidResult", $_) )
            }
            if($PackageInfo) {
               Write-Verbose "Update Dictionary with PackageInfo"
               $PackageInfo.ModuleManifestPath = $ModuleManifestPath
               UpdateDictionary $ModuleInfo $PackageInfo | ConvertTo-PSModuleInfo -AsObject
            } else {
               Write-Verbose "Add ModuleManifestPath (Package Manifest not found)."
               UpdateDictionary $ModuleInfo @{ModuleManifestPath = $ModuleManifestPath} | ConvertTo-PSModuleInfo -AsObject
            }
         } else {
            ConvertTo-PSModuleInfo $ModuleInfo -AsObject 
         }
      }
   }
}

# Internal function to updates dictionaries or ModuleInfo objects with extra metadata
# This is the guts of ImportModuleInfo and ReadModulePackageInfo
# It is currently hard-coded to handle a nested array of hashtables for RequiredModules 
# But it ought to be extended to handle objects, hashtables, and arrays, and with a specified key
function UpdateDictionary {
   param(
      $Authoritative,
      $Additional,
      [string[]]$ForceProperties
   )
   process {
      ## TODO: Rewrite this generically to deal with arrays of hashtables based on a $KeyField parameter
      foreach($prop in $Additional.GetEnumerator()) {
         #    $value = $(
         #       if($Value -isnot [System.Collections.IDictionary] -and $Value -is [System.Collections.IList]) {
         #          foreach($value in $prop.Value) { $value }
         #       } else { $prop.Value }
         #    )
         #    if($Value -is [System.Collections.IDictionary]) {
         #    ....

         # So far we only have special handling for RequiredModules:
         Write-Verbose "Updating $($prop.Name)"
         switch($prop.Name) {

            "RequiredModules" {
               # Sometimes, RequiredModules are just strings (the name of a module)
               [string[]]$rmNames = $Authoritative.RequiredModules | ForEach-Object { if($_ -is [string]) { $_ } else { $_.Name } }
               Write-Verbose "Module Requires: $($rmNames -join ',')"
               # Here, we only need to update the PackageInfoUrl if we can find one
               foreach($depInfo in @($Additional.RequiredModules | Where-Object { $_.PackageInfoUrl })) {
                  $name = $depInfo.Name
                  Write-Verbose "Additional Requires: $name"
                  # If this Required Module is already listed, then just add the uri
                  # Otherwise should we add it? (as a hashtable with the info we have?)
                  if($rmNames -contains $name) {
                     foreach($required in $Authoritative.RequiredModules) {
                        if(($required -is [string]) -and ($required -eq $name)) {
                           $Authoritative.RequiredModules[([Array]::IndexOf($Authoritative.RequiredModules,$required))] = $depInfo
                        } elseif($required.Name -eq $name) {
                           Write-Verbose "Authoritative also Requires $name - adding PackageInfoUrl ($($depInfo.PackageInfoUrl))"
                           if($required -is [System.Collections.IDictionary]) {
                              Write-Verbose "Required is a Hashtable, adding PackageInfoUrl: $($depInfo.PackageInfoUrl)"
                              if(!$required.Contains("PackageInfoUrl")) {
                                 $required.Add("PackageInfoUrl", $depInfo.PackageInfoUrl)
                              }
                           } else {
                              Add-Member -InputObject $required -Type NoteProperty -Name "PackageInfoUrl" -Value $depInfo.PackageInfoUrl -ErrorAction SilentlyContinue
                              Write-Verbose "Required is an object, added PackageInfoUrl: $($required | FL * | Out-String | % TrimEnd )"
                           }
                        }
                     }
                  } else {
                     Write-Warning "Mismatch in RequiredModules: Package manifest specifies $name"
                     Write-Debug (Get-PSCallStack |Out-String)
                  }
               }
            }
            default {
               ## We only add properties, never replace, so hide errors
               if($Authoritative -is [System.Collections.IDictionary]) {
                  if(!$Authoritative.Contains($prop.Name) -or $ForceProperties -contains $prop.Name) {
                     $Authoritative.($prop.Name) = $prop.Value
                  }
               } else {
                  if(!$Authoritative.($prop.Name) -or ($Authoritative.($prop.Name).Count -eq 0) -or $ForceProperties -contains $prop.Name) {
                     Add-Member -in $Authoritative -type NoteProperty -Name $prop.Name -Value $prop.Value -Force -ErrorAction SilentlyContinue
                  }
               }            
            }
         }
      }
      $Authoritative
   }
}

function ConvertToHashtable {
    #.Synopsis
    #   Converts an object to a hashtable (with the specified properties), optionally discarding empty properties
    #.Example
    #   $Hash = Get-Module PoshCode | ConvertToHashtable -IgnoreEmptyProperties
    #   New-ModuleManifest -Path .\PoshCode.psd1 @Hash
    #
    #   Demonstrates the most common reason for converting an object to a hashtable: splatting
    #.Example
    #   Get-Module PoshCode | ConvertToHashtable -IgnoreEmpty | %{ New-ModuleManifest -Path .\PoshCode.psd1 @_ }
    #
    #   Demonstrates the most common reason for converting an object to a hashtable: splatting
    param(
        # The input object to convert to a hashtable 
        [Parameter(ValueFromPipeline=$true)]
        $InputObject,

        # The properties to convert (a list, or wildcards). Defaults to all properties
        [Parameter(Position=0)]
        [String[]]$Property = "*",

        # If set, all selected properties are included. By default, empty properties are discarded
        [Switch]$IgnoreEmptyProperties
    )
    begin   { $Output=@{} } 
    end     { if($Output.Count){ $Output } } 
    process {
        $Property = Get-Member $Property -Input $InputObject -Type Properties | % { $_.Name }
        foreach($Name in $Property) {
            if(!$IgnoreEmptyProperties -or (($InputObject.$Name -ne $null) -and (@($InputObject.$Name).Count -gt 0) -and ($InputObject.$Name -ne ""))) {
                $Output.$Name = $InputObject.$Name 
            }
        }
    }
}

function ConvertTo-PSModuleInfo {
    #.Synopsis
    #  Internal function for objectifying ModuleInfo data (and RequiredModule values)
    [CmdletBinding(DefaultParameterSetName="Hashtable")]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true)]
        $ModuleInfo,

        $AddonInfo, 

        # Convert a top-level hashtable to an object before outputting it
        [Parameter(ParameterSetName="AsObject", Mandatory=$true)]
        [switch]$AsObject,

        [Parameter(ParameterSetName="AsObject")]
        [string[]]$PSTypeNames = $("System.Management.Automation.PSModuleInfo", "PoshCode.ModuleInfo.PSModuleInfo")
    )
    process {
        foreach($MI in @($ModuleInfo)) {
            if($AddonInfo) { $MI = UpdateDictionary $MI $AddonInfo -ForceProperties $AddonInfo.Keys}

            Write-Verbose ">> Adding Simple Names"

            if($MI -is [Hashtable]) {
                foreach($rm in @($MI) + @($MI.RequiredModules)) {
                    if($rm -is [string]) {
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name ModuleName -Value $rm -Passthru -ErrorAction SilentlyContinue
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name Name -Value $rm -Passthru -ErrorAction SilentlyContinue
                    }
                    if($rm.ModuleName -and !$rm.Name) {
                        $rm.Name = $rm.ModuleName
                    }
                    if($rm.ModuleVersion -and !$rm.Version) {
                        $rm.Version = $rm.ModuleVersion
                    }
                    if($rm.RootModule -and !$rm.ModuleToProcess) {
                        $rm.ModuleToProcess = $rm.RootModule
                    }
                }
            } else {
                foreach($rm in @($MI) + @($MI.RequiredModules)) {
                    if($rm -is [string]) {
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name ModuleName -Value $rm -Passthru -ErrorAction SilentlyContinue
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name Name -Value $rm -Passthru -ErrorAction SilentlyContinue
                    }
                    if($rm.ModuleName -and !$rm.Name) {
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name Name -Value $rm.ModuleName -Passthru -ErrorAction SilentlyContinue
                    }
                    if($rm.ModuleVersion -and !$rm.Version) {
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name Version -Value $rm.Version -Passthru -ErrorAction SilentlyContinue
                    }
                    if($rm.RootModule -and !$rm.ModuleToProcess) {
                        $rm = Add-Member -InputObject $rm -MemberType NoteProperty -Name ModuleToProcess -Value $rm.RootModule -Passthru -ErrorAction SilentlyContinue
                    }
                }
            }
        

            if($AsObject -and ($MI -is [Collections.IDictionary])) {
                if($MI.RequiredModules) {
                    $MI.RequiredModules = @(foreach($Module in @($MI.RequiredModules)) {
                        if($Module -is [String]) { $Module = @{Name=$Module; ModuleName=$Module} }

                        if($Module -is [Hashtable] -and $Module.Count -gt 0) {
                            Write-Debug ($Module | Format-List * | Out-String)
                            New-Object PSObject -Property $Module | % {
                                $_.PSTypeNames.Insert(0,"System.Management.Automation.PSModuleInfo")
                                $_.PSTypeNames.Insert(0,"PoshCode.ModuleInfo.PSModuleInfo")
                                $_
                            }
                        } else {
                            $Module
                        }
                    })
                }

                foreach($output in New-Object PSObject -Property $MI){
                    foreach($type in $PSTypeNames) {
                        $output.PSTypeNames.Insert(0,$type)
                    }
                    $output
                }
            } else {
                $MI
            }
        }
    }
}

Export-ModuleMember -Function Get-ModuleInfo, Set-ModuleInfo, ConvertTo-PSModuleInfo
