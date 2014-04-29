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
         Write-Verbose "Dictionary:`n $($InputObject|ft|out-string -width 110)"
         "@{{`n$t{0}`n}}" -f ($(
         ForEach($key in @($InputObject.Keys)) {
            Write-Verbose "Key: $key"
            if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
               "$key = " + (ConvertTo-Metadata $InputObject.($key))
            }
            else {
               "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
            }
         }) -split "`n" -join "`n$t")
      } 
      elseif($InputObject -is [System.Collections.IEnumerable]) {
         Write-Verbose "Enumarable"
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

        # The url where the module's package manifest will be uploaded (defaults to the download URI modified to ModuleName.psd1)
        [String]$PackageInfoUrl,

        # a URL or relative path to a web page about this module
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$ProjectUrl,
      
        # TODO: If set, require the license to be accepted during installation (not supported yet)
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]$RequireLicenseAcceptance,

        # An array of keyword tags for search
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String[]]$Tags,



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
            # TODO: change to a warning, and prompt to generate the manifest for them
            Write-Error "Module manifest not found: $ModuleManifestPath"
            return
        }

        # PrivateData has to be a hashtable.
        if($Manifest.PrivateData -and $Manifest.PrivateData -isnot [Hashtable]) {
            Write-Warning "Sorry, for the purposes of packaging, your Module manifest must use a Hashtable as the value of PrivateData. We add a '$PrivateDataKey' key to your PrivateData hashtable to store the additional module information which is needed for packaging."
            throw "Incompatible PrivateData - must be a Hashtable, please see docs."
        } elseif(!$Manifest.PrivateData) {
            $Manifest.PrivateData = @{$PrivateDataKey = @{}}
        } elseif(!$Manifest.PrivateData.$PrivateDataKey -or $Manifest.PrivateData -isnot [Hashtable]) {
            $Manifest.PrivateData.$PrivateDataKey = @{}
        }
        
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


        # Generate or update the PrivateData.PackageData hashtable
        $UpdatedPrivateData = $False
        [Hashtable]$PackageData = $Manifest.PrivateData
        foreach($Key in @($PSBoundParameters.Keys)) { 
            if($Key -in $PackageProperties) {
                Write-Verbose "Updating $Key in PackageProperties"
                $PackageData.$PrivateDataKey.$Key = $PSBoundParameters.$Key
                $Null = $PSBoundParameters.Remove($Key)
                $UpdatedPrivateData = $True
            }
        }
        $PSBoundParameters["PrivateData"] = $PackageData

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
                                [PSCustomObject]@{
                                    Name = $Item.Item1.Value
                                    Start = $Item.Item1.Extent.StartOffset
                                    Length = $Item.Item2.Extent.EndOffset - $Item.Item1.Extent.StartOffset
                                }
                            } elseif($Key -in $ModuleManifestProperties) {
                                if($Match = ([regex]"#\s*$Key\s*=.*").Match($Code)) {
                                    [PSCustomObject]@{  
                                        Name = $Key
                                        Start = $Match.Index
                                        Length = $Match.Length
                                    }
                                } else {
                                    [PSCustomObject]@{  
                                        Name = $Key
                                        Start = $Hashtable.Extent.EndOffset - 1
                                        Length = 0
                                    }
                                }
                            }
                        }
        $OrderedKeys = $OrderedKeys | Sort Start -Descending 

        foreach($Key in $OrderedKeys) {
            Write-Verbose "Replacing $($Key.Name) at $($Key.Start), $($Key.Length)"
            $Code = $Code.Remove($Key.Start, $Key.Length).Insert($Key.Start, "$($Key.Name) = $(ConvertTo-Metadata $PSBoundParameters.($Key.Name))`r`n")
        }

        Set-Content $ModuleManifestPath $Code.Trim()
    }
}

Export-ModuleMember -Function Export-Metadata, Import-Metadata, ConvertFrom-Metadata, ConvertTo-Metadata, Update-ModuleManifest

