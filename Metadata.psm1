# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Configuration"
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
      $InputObject
   )
   begin { $data = @() }
   process { $data += @($InputObject) }
   end {
      # Avoid arrays when they're not needed:
      if($data.Count -eq 1) { $data = $data[0] }
      Set-Content -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata $data)) -Join "`n")
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
      if($InputObject -is [Int16] -or 
         $InputObject -is [Int32] -or 
         $InputObject -is [Int64] -or 
         $InputObject -is [Double] -or 
         $InputObject -is [Decimal] -or 
         $InputObject -is [Byte] ) { 
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

function ConvertTo-PSModuleInfo {
    #.Synopsis
    #  Internal function for objectifying ModuleInfo data (and RequiredModule values)
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)]
        $ModuleInfo,

        # Convert a top-level hashtable to an object before outputting it
        [switch]$AsObject
    )
    process {
        $ModuleInfo = $ModuleInfo | & { param([Parameter(ValueFromPipeline=$true)]$ModuleInfo)
            process {
                Write-Verbose ">> Adding Simple Names"

                if($ModuleInfo -is [Hashtable]) {
                    foreach($rm in @($ModuleInfo) + @($ModuleInfo.RequiredModules)) {
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
                    foreach($rm in @($ModuleInfo) + @($ModuleInfo.RequiredModules)) {
                        if($rm.ModuleName -and !$rm.Name) {
                            Add-Member -InputObject $rm -MemberType NoteProperty -Name Name -Value $rm.Name -ErrorAction SilentlyContinue
                        }
                        if($rm.ModuleVersion -and !$rm.Version) {
                            Add-Member -InputObject $rm -MemberType NoteProperty -Name Version -Value $rm.Version -ErrorAction SilentlyContinue
                        }
                        if($rm.RootModule -and !$rm.ModuleToProcess) {
                            Add-Member -InputObject $rm -MemberType NoteProperty -Name ModuleToProcess -Value $rm.RootModule -ErrorAction SilentlyContinue
                        }
                    }
                }
                $ModuleInfo
            }
        }

        if($AsObject -and ($ModuleInfo -is [Collections.IDictionary])) {
            if($ModuleInfo.RequiredModules) {
                $ModuleInfo.RequiredModules = @(foreach($Module in @($ModuleInfo.RequiredModules)) {
                    if($Module -is [String]) { $Module = @{ModuleName=$Module} }

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

            New-Object PSObject -Property $ModuleInfo | % {
                $_.PSTypeNames.Insert(0,"System.Management.Automation.PSModuleInfo")
                $_.PSTypeNames.Insert(0,"PoshCode.ModuleInfo.PSModuleInfo")
                $_
            }
        } else {
            $ModuleInfo
        }
    }
}

Export-ModuleMember -Function Export-Metadata, Import-Metadata, ConvertTo-PSModuleInfo #, ConvertFrom-Metadata, ConvertTo-Metadata
