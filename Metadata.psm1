###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Metadata.psm1 defines the core commands for Atom Entries and Feeds
##

# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  Write-Warning "TESTING: No PoshCodeModuleRoot"
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1
# FULL # END FULL

# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Module "Atom"
Import-Module $PoshCodeModuleRoot\Atom.psm1

# Import and Export are the external functions. 
function Import-Metadata {
   <#
      .Synopsis
         Creates a data object from the items in a Manifest file
   #>
   [CmdletBinding()]
   param(
      [Parameter(ValueFromPipeline=$true, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath")]
      [string]$Path
   )

   process {
      $ModuleInfo = $null
      if(Test-Path $Path) {
         Write-Verbose "Importing Metadata file from `$Path: $Path"
         if(!(Test-Path $Path -PathType Leaf)) {
            $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
         }
      }

      try {
         ConvertFrom-Metadata $Path
      } catch {
         $PSCmdlet.ThrowTerminatingError( $_ )
      }
   }
}

function Export-Metadata {
    <#
      .Synopsis
         A metadata export function that works like json
      .Description
         Converts simple objects to psd1 data files
         Exportable data is limited the rules of data sections (see about_Data_Sections)

         The only things exportable are Strings and Numbers, and Arrays or Hashtables where the values are all strings or numbers.
         NOTE: Hashtable keys must be simple strings or numbers
         NOTE: Simple dynamic objects can also be exported (they come back as PSObject)
    #>
    [CmdletBinding()]
    param(
        # Specifies the path to the PSD1 output file.
        [Parameter(Mandatory=$true, Position=0)]
        $Path,

        # comments to place on the top of the file (to explain it's settings)
        [string[]]$CommentHeader,

        # Specifies the objects to export as metadata structures.
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
        # Avoid arrays when they're not needed:
        if($data.Count -eq 1) { $data = $data[0] }
        Set-Content -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata $data)) -Join "`n")
        if($Passthru) {
            Get-Item $Path
        }
    }
}

# At this time there's not a lot of value in exporting the ConvertFrom/ConvertTo functions
# Private Functions (which could be exported)

function ConvertFrom-Metadata {
   [CmdletBinding()]
   param(
      [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
      [Alias("PSPath")]
      $InputObject,
      $ScriptRoot = '$PSScriptRoot'
   )
   begin {
      [string[]]$ValidCommands = "PSObject", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", "Join-Path"
      [string[]]$ValidVariables = "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot","PSCulture","PSUICulture","True","False","Null"
   }
   process {
      $EAP, $ErrorActionPreference = $EAP, "Stop"
      $Tokens = $Null; $ParseErrors = $Null

      if($PSVersionTable.PSVersion -lt "3.0") {
         Write-Verbose "$InputObject"
         if(!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Set-Content -Path $Path $InputObject
            $InputObject = $Path
         } elseif(!"$InputObject".EndsWith($ModuleManifestExtension)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Copy-Item "$InputObject" "$Path"
            $InputObject = $Path
         }
         $Result = $null
         Import-LocalizedData -BindingVariable Result -BaseDirectory (Split-Path $InputObject) -FileName (Split-Path $InputObject -Leaf) -SupportedCommand $ValidCommands
         return $Result
      }

      if(Test-Path $InputObject -ErrorAction SilentlyContinue) {
         $AST = [System.Management.Automation.Language.Parser]::ParseFile( (Convert-Path $InputObject), [ref]$Tokens, [ref]$ParseErrors)
         $ScriptRoot = Split-Path $InputObject
      } else {
         $ScriptRoot = $PoshCodeModuleRoot
         $OFS = "`n"
         $InputObject = "$InputObject" -replace "# SIG # Begin signature block(?s:.*)"
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($InputObject, [ref]$Tokens, [ref]$ParseErrors)
      }

      if($ParseErrors -ne $null) {
         $ParseException = New-Object System.Management.Automation.ParseException (,[System.Management.Automation.Language.ParseError[]]$ParseErrors)
         $PSCmdlet.ThrowTerminatingError((New-Object System.Management.Automation.ErrorRecord $ParseException, "Metadata Error", "ParserError", $InputObject))
      }

      if($scriptroots = @($Tokens | Where-Object { ("Variable" -eq $_.Kind) -and ($_.Name -eq "PSScriptRoot") } | ForEach-Object { $_.Extent } )) {
         $ScriptContent = $Ast.ToString()
         for($r = $scriptroots.count - 1; $r -ge 0; $r--) {
            $ScriptContent = $ScriptContent.Remove($scriptroots[$r].StartOffset, ($scriptroots[$r].EndOffset - $scriptroots[$r].StartOffset)).Insert($scriptroots[$r].StartOffset,'$ScriptRoot')
         }
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
      }

      $Script = $AST.GetScriptBlock()
      $Script.CheckRestrictedLanguage( $ValidCommands, $ValidVariables, $true )

      $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

      try {
         $Script.InvokeReturnAsIs(@())
      }
      finally {    
         $ErrorActionPreference = $EAP
         $ExecutionContext.SessionState.LanguageMode = $Mode
      }
   }
}

function ConvertTo-Metadata {
   [CmdletBinding()]
   param(
      $InputObject
   )
   begin { $t = "  " }

   process {
      if($InputObject -eq $Null) {

      } elseif( $InputObject -is [Int16] -or 
                $InputObject -is [Int32] -or 
                $InputObject -is [Int64] -or 
                $InputObject -is [Double] -or 
                $InputObject -is [Decimal] -or 
                $InputObject -is [Byte] )
      {
         # Write-Verbose "Numbers"
         "$InputObject" 
      }
      elseif($InputObject -is [bool])  {
         # Write-Verbose "Boolean"
         if($InputObject) { '$True' } else { '$False' }
      }
      elseif($InputObject -is [DateTime])  {
         # Write-Verbose "DateTime"
         "DateTime '{0}'" -f $InputObject.ToString('o')
      }
      elseif($InputObject -is [DateTimeOffset])  {
         # Write-Verbose "DateTime"
         "DateTimeOffset '{0}'" -f $InputObject.ToString('o')
      }
      elseif($InputObject -is [String] -or
             $InputObject -is [Version])  {
         # Write-Verbose "String"
         "'$InputObject'" 
      }
      elseif($InputObject -is [System.Collections.IDictionary]) {
         # Write-Verbose "Dictionary:`n $($InputObject|ft|out-string -width 110)"
         "@{{`n$t{0}`n}}" -f ($(
         ForEach($key in @($InputObject.Keys)) {
            # Write-Verbose "Key: $key"
            if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
               "$key = " + (ConvertTo-Metadata $InputObject.($key))
            }
            else {
               "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
            }
         }) -split "`n" -join "`n$t")
      } 
      elseif($InputObject -is [System.Collections.IEnumerable]) {
         # Write-Verbose "Enumerable"
         "@($($(ForEach($item in @($InputObject)) { ConvertTo-Metadata $item }) -join ','))"
      }
      elseif($InputObject -is [Guid]) {
         # Write-Verbose "GUID:"
         "Guid '$InputObject'"
      }
      elseif($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
         # Write-Verbose "Dictionary"

         "PSObject @{{`n$t{0}`n}}" -f ($(
            ForEach($key in $InputObject | Get-Member -Type Properties | Select -Expand Name) {
               if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
                  "$key = " + (ConvertTo-Metadata $InputObject.($key))
               }
               else {
                  "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
               }
            }
         ) -split "`n" -join "`n$t")
      } 
      else {
         Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
         "'{0}'" -f $InputObject.ToString()
      }
   }
}

# These functions are simple helpers for use in data sections (see about_data_sections) and .psd1 files (see ConvertFrom-Metadata)
function PSObject {
   <#
      .Synopsis
         Creates a new PSCustomObject with the specified properties
      .Description
         This is just a wrapper for the PSObject constructor with -Property $Value
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The hashtable of properties to add to the created objects
   #>
   param([hashtable]$Value)
   New-Object System.Management.Automation.PSObject -Property $Value 
}

function Guid {
   <#
      .Synopsis
         Creates a GUID with the specified value
      .Description
         This is basically just a type cast to GUID.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The GUID value.
   #>   
   param([string]$Value)
   [Guid]$Value
}

function DateTime {
   <#
      .Synopsis
         Creates a DateTime with the specified value
      .Description
         This is basically just a type cast to DateTime, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The DateTime value, preferably from .Format('o'), the .Net round-trip format
   #>   
   param([string]$Value)
   [DateTime]$Value
}

function DateTimeOffset {
   <#
      .Synopsis
         Creates a DateTimeOffset with the specified value
      .Description
         This is basically just a type cast to DateTimeOffset, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The DateTimeOffset value, preferably from .Format('o'), the .Net round-trip format
   #>    
   param([string]$Value)
   [DateTimeOffset]$Value
}

function Set-ModuleManifest {
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
        [System.Collections.IDictionary]
        ${PrivateData},


        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias("Version")]
        [ValidateNotNull()]
        [version]
        ${ModuleVersion},


        # Choose one category from the list:
        [ValidateSet("Active Directory", "Applications", "App-V", "Backup and System Restore", "Databases", "Desktop Management", "Exchange", "Group Policy", "Hardware", "Interoperability and Migration", "Local Account Management", "Logs and monitoring", "Lync", "Messaging & Communication", "Microsoft Dynamics", "Multimedia", "Networking", "Office", "Office 365", "Operating System", "Other Directory Services", "Printing", "Remote Desktop Services", "Scripting Techniques", "Security", "Servers", "SharePoint", "Storage", "System Center", "UE-V", "Using the Internet", "Windows Azure", "Windows Update")]
        [String]$Category,

        # a URL or relative path to an icon for the module in gif/jpg/png form
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$IconUrl,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$IsPrerelease,

        # The url to a license
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$LicenseUrl,

        # a URL or relative path to a web page about this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$ProjectUrl,
      
        # TODO: If set, require the license to be accepted during installation (not supported yet)
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$RequireLicenseAcceptance,

        # An array of keyword tags for search
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String[]]$Tags,


        # This is a PoshCode extension to the module packaging format which allows you to specify the feed where version updates will be published
        # The expected value is a url where an atom feed will be available, such as this one for PowerBot
        # https://msconfiggallery.cloudapp.net/api/v2/GetUpdates()?packageIds='PowerBot'&versions='0.0'&includePrerelease=false&includeAllVersions=false
        [String]$PackageInfoUrl,



        # Automatically increment the module version number
        [Switch]$IncrementVersionNumber,

        # If set, overwrite existing files without prompting
        [Switch]$Force,

        [Switch]$NewOnly,

        [switch]${PassThru}

    )
    begin {
        $ModuleManifestProperties = 'AliasesToExport', 'Author', 'ClrVersion', 'CmdletsToExport', 'CompanyName', 'Copyright', 'DefaultCommandPrefix', 'Description', 'DotNetFrameworkVersion', 'FileList', 'FormatsToProcess', 'FunctionsToExport', 'Guid', 'HelpInfoUri', 'ModuleList', 'ModuleVersion', 'NestedModules', 'PowerShellHostName', 'PowerShellHostVersion', 'PowerShellVersion', 'PrivateData', 'ProcessorArchitecture', 'RequiredAssemblies', 'RequiredModules', 'ModuleToProcess', 'ScriptsToProcess', 'TypesToProcess', 'VariablesToExport'
        $PackageProperties = 'Category', 'IconUrl', 'IsPrerelease', 'LicenseUrl', 'PackageInfoUrl', 'ProjectUrl', 'RequireLicenseAcceptance', 'Tags'
        if(!(Test-Path variable:RejectAllOverwriteOnModuleInfo)){
            $RejectAllOverwriteOnModuleInfo = $false
            $ConfirmAllOverwriteOnModuleInfo = $false
        }
    }
    process {

        $ErrorActionPreference = "Stop"
        $Manifest = Get-Module $Name -ListAvailable
        $Null = $PSBoundParameters.Remove("Name")

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
            $RootModuleName = Split-Path $Manifest.Path -Leaf 
            if($Force -or $PSCmdlet.ShouldContinue("Generate the module manifest?`n$ModuleManifestPath","Module manifest not found for $RootModuleName")) {
                Write-Warning "Generating Manifest: '$ModuleManifestPath'"
                # We're just trying to make a placeholder, we'll update it afterward
                $ModuleManifest = $Manifest | ConvertToHashtable $ModuleManifestProperties -IgnoreEmptyProperties
                # New-ModuleManifest can't handle Hashtables in PrivateData
                $ModuleManifest.Remove('PrivateData')
                Push-Location (Split-Path $Manifest.Path)
                $ModuleToProcess = Resolve-Path $Manifest.Path -Relative
                Pop-Location

                New-ModuleManifest -Path $ModuleManifestPath @ModuleManifest -ModuleToProcess $ModuleToProcess
                # Reread it, because we probably got guid/version/author/description/copyright etc.
                $Manifest = Get-Module $Name -ListAvailable
            } else { return }
        }

        # PrivateData has to be a hashtable.
        if($Manifest.PrivateData -and $Manifest.PrivateData -isnot [Hashtable]) {
            Write-Warning "Sorry, for the purposes of packaging, your Module manifest must use a Hashtable as the value of PrivateData. We add a '$PackageDataKey' key to your PrivateData hashtable to store the additional module information which is needed for packaging."
            throw "Incompatible PrivateData - must be a Hashtable, please see docs."
        } elseif(!$Manifest.PrivateData -and $PrivateData) {
            $Manifest.PrivateData = $PrivateData
        } elseif(!$Manifest.PrivateData) {
            $Manifest.PrivateData = @{$PackageDataKey = @{}}
        } elseif(!$Manifest.PrivateData.$PackageDataKey -or $Manifest.PrivateData -isnot [Hashtable]) {
            $Manifest.PrivateData.Add($PackageDataKey, @{})
        }elseif($Manifest.PrivateData -and $PrivateData) {
            # Wipe the current PrivateData but keep the PackageData if there isn't any in the new PrivateData
            if(!$PrivateData.ContainsKey($PackageDataKey) -and $Manifest.PrivateData.ContainsKey($PackageDataKey)) {
                $PrivateData.$PackageDataKey = $Manifest.PrivateData.$PackageDataKey
            }
            $Manifest.PrivateData = $PrivateData
        }
        # Generate or update the PrivateData.PackageData hashtable
        $UpdatedPrivateData = $False
        [Hashtable]$PrivateCopy = $Manifest.PrivateData
        foreach($Key in @($PSBoundParameters.Keys)) { 
            if($Key -in $PackageProperties) {
                Write-Verbose "Updating $Key in PackageProperties"
                $PrivateCopy.$PackageDataKey.$Key = $PSBoundParameters.$Key
                $Null = $PSBoundParameters.Remove($Key)
                $UpdatedPrivateData = $True
            }
        }
        $PSBoundParameters["PrivateData"] = $PrivateCopy
        
        # Deal with setting or incrementing the module version
        if($IncrementVersionNumber -or $ModuleVersion -or $Manifest.Version -le [Version]"0.0") {
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
            # TODO: Figure out a way to get rid of ONE of these throughout PoshCode stuff
            $PSBoundParameters["ModuleVersion"] = $PackageVersion
            $PSBoundParameters["Version"] = $PackageVersion
        }

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
        

        # Ok, now get the current module manifest and figure out what's in it
        $Tokens = $Null; $ParseErrors = $Null
        $AST = [System.Management.Automation.Language.Parser]::ParseFile( (Convert-Path $ModuleManifestPath), [ref]$Tokens, [ref]$ParseErrors)
        $Hashtable = $Ast.Find( { param($a) $a -is [System.Management.Automation.Language.HashtableAst] }, $false )
        # Get the module manifest as a string
        [string]$Code = $Ast.ToString()

        #Requires -Version 4.0
        [String[]]$ParameterKeys = $Hashtable.KeyValuePairs.Item1.Value
        
        $OrderedKeys = foreach($Key in $PSBoundParameters.Keys) { 
                            if($Key -in $ParameterKeys) { 
                                $Item = $Hashtable.KeyValuePairs | Where-Object { $_.Item1.Value -eq $Key }
                                [PSCustomObject]@{
                                    Name = $Item.Item1.Value
                                    Display = "Replacing {0} at line {1} col {2}" -f $Item.Item1.Value, $Item.Item1.Extent.StartLineNumber, $Item.Item1.Extent.StartColumnNumber
                                    Start = $Item.Item1.Extent.StartOffset
                                    Length = $Item.Item2.Extent.EndOffset - $Item.Item1.Extent.StartOffset
                                }
                            } elseif($Key -in $ModuleManifestProperties) {
                                if($Match = ([regex]"#\s*$Key\s*=.*").Match($Code)) {
                                    [PSCustomObject]@{  
                                        Name = $Key
                                        Display = "Replacing {0} at index {1} in {2}" -f $Key, $Match.Index, $Match.Value
                                        Start = $Match.Index
                                        Length = $Match.Length
                                    }
                                } else {
                                    [PSCustomObject]@{  
                                        Name = $Key
                                        Display = "Inserting {0} at the end of the file" -f $Key
                                        Start = $Hashtable.Extent.EndOffset - 1
                                        Length = 0
                                    }
                                }
                            }
                        }
        $OrderedKeys = $OrderedKeys | Sort Start -Descending 

        # Put our new values into the module manifest in string form ... 
        foreach($Key in $OrderedKeys) {
            Write-Verbose "Replacing $($Key.Display)"
            $Code = $Code.Remove($Key.Start, $Key.Length).Insert($Key.Start, "$($Key.Name) = $(ConvertTo-Metadata $PSBoundParameters.($Key.Name))`r`n")
        }

        Set-Content $ModuleManifestPath $Code.Trim()
        if($Passthru) {
            Get-Item $ModuleManifestPath
        }
    }
}

function New-ModuleManifest {
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', HelpUri='http://go.microsoft.com/fwlink/?LinkID=141555')]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    ${Path},

    [AllowEmptyCollection()]
    [System.Object[]]
    ${NestedModules},

    [guid]
    ${Guid} = [Guid]::NewGuid(),

    [AllowEmptyString()]
    [string]
    ${Author},

    [AllowEmptyString()]
    [string]
    ${CompanyName},

    [AllowEmptyString()]
    [string]
    ${Copyright},

    [AllowEmptyString()]
    [string]
    [Alias('ModuleToProcess')]
    ${RootModule},

    [ValidateNotNull()]
    [version]
    ${ModuleVersion},

    [Parameter(Mandatory=$true, Position=1, ValueFromRemainingArguments=$true)]
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
    ${DefaultCommandPrefix})

begin
{
    if(!${GUID} -or [GUID]::Empty -eq ${GUID}) {
        $PSBoundParameters['GUID'] = ${GUID} = [GUID]::NewGuid()
    }
    if(!${ModuleVersion} -or ([Version]'0.0.0.0') -ge ${ModuleVersion}) {
        $PSBoundParameters['ModuleVersion'] = $ModuleVersion = [Version]'1.0'
    }
    $ConfigChanged = $False
    if(!${Author}) {
        $ConfigData = Get-ConfigData
        if(!$ConfigData.AuthorInfo.Author) {
            $ConfigData.AuthorInfo.Author = Read-Host "Please enter your full name for the module info"
            $ConfigChanged = $True
            if(!$ConfigData.AuthorInfo.Author) {
                $ConfigData.AuthorInfo.Author = $Env:UserName
            }
        }
        $PSBoundParameters['Author'] = $Author = $ConfigData.AuthorInfo.Author
    }

    if(!${CompanyName}) {
        if(!$ConfigData) { $ConfigData = Get-ConfigData }
        if(!$ConfigData.AuthorInfo.CompanyName) {
            $ConfigChanged = $True
            $ConfigData.AuthorInfo.CompanyName = Read-Host "Enter a Company Name for the module info (or a web address) or leave blank for none:"
        }
        $PSBoundParameters['CompanyName'] = $CompanyName = $ConfigData.AuthorInfo.CompanyName
    }

    if(!$Copyright) {
        if(!$ConfigData) { $ConfigData = Get-ConfigData }
        if(!$ConfigData.AuthorInfo.Copyright) {
            $Year = [DateTime]::Now.Year
            if($CompanyName -and $CompanyName -notmatch "://") {
                $Copyright = "Copyright (c) ${Year} by ${CompanyName}, all rights reserved."
            } else {
                $Copyright = "Copyright (c) ${Year} by ${Author}, all rights reserved."
            }
            $ConfigChanged = $True
            $ConfigData.AuthorInfo.Copyright = Read-Host "Enter a copyright statement, or press enter to accept: `"$Copyright`""
            if(!$ConfigData.AuthorInfo.Copyright) {
                $ConfigData.AuthorInfo.Copyright = $Copyright
            }
        }
        $PSBoundParameters['Copyright'] = $Copyright = $ConfigData.AuthorInfo.Copyright
    }

    if($ConfigChanged) { Set-ConfigData $ConfigData }

    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Core\New-ModuleManifest', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters }
        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process
{
    try {
        $steppablePipeline.Process($_)
    } catch {
        throw
    }

    # Force manifests to be compatible with PowerShell 2, since we can
    $Content = Get-Content $Path -Delimiter ([char]0)
    $Content = $Content -replace "(?m)^RootModule = ","ModuleToProcess = "
    Set-Content $Path -Value $Content
}

end
{
    try {
        $steppablePipeline.End()
    } catch {
        throw
    }
}
<#

.ForwardHelpTargetName Microsoft.PowerShell.Core\New-ModuleManifest
.ForwardHelpCategory Cmdlet

#>
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
         $ModuleManifestPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf)$ModuleManifestExtension"

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

         ConvertTo-PSModuleInfo $ModuleInfo -AsObject 
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

function ConvertTo-PSModuleInfo {
    #.Synopsis
    #  Internal function for objectifying ModuleInfo data (and RequiredModule values)
    [CmdletBinding(DefaultParameterSetName="Hashtable")]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true)]
        $ModuleInfo,

        $AddonInfo = $ModuleInfo.PrivateData.$PackageDataKey,

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

Export-ModuleMember -Function Export-Metadata, Import-Metadata, ConvertFrom-Metadata, ConvertTo-Metadata, Set-ModuleManifest, New-ModuleManifest, Get-ModuleInfo, ConvertTo-PSModuleInfo
