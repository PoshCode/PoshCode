# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Configuration"
###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Installation.psm1 defines the core commands for installing packages:
## Read-Module and Install-Module 
## It depends on the Configuration module and the Invoke-WebRequest cmdlet


# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  Write-Warning "TESTING: No PoshCodeModuleRoot"
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1
# FULL # END FULL

# Public Function
# This is a wrapper for Get-Module which uses Update-ModuleInfo to load the package manifest
# It doesn't support PSSession or CimSession, and it simply extends the output
function Read-Module {
   [CmdletBinding(DefaultParameterSetName='Loaded')]
   param(
      [Parameter(ParameterSetName='Available', Position=0, ValueFromPipeline=$true)]
      [Parameter(ParameterSetName='Loaded', Position=0, ValueFromPipeline=$true)]
      [string[]]
      ${Name},

      [Parameter(ParameterSetName='Available')]
      [Parameter(ParameterSetName='Loaded')]
      [switch]
      ${All},

      [Parameter(ParameterSetName='Available', Mandatory=$true)]
      [switch]
      ${ListAvailable},

      [Parameter(ParameterSetName='Available')]
      [switch]
      ${Refresh}
   )
   begin
   {
      ## Fix PowerShell Bug https://connect.microsoft.com/PowerShell/feedback/details/802030
      ## BUG: if Get-Module is working, but the pipeline somehow stops, the Push-Location in the end block never happens!
      # Push-Location $Script:EmptyPath

      try {
         $moduleName = $outBuffer = $null
         if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
         {
            $PSBoundParameters['OutBuffer'] = 1
         }

         if ($PSBoundParameters.TryGetValue('Name', [ref]$moduleName))
         {
            $PSBoundParameters['Name'] = @($moduleName | Where-Object { $_ -and !$_.EndsWith($ModulePackageExtension) })
            $moduleName | Where-Object { $_ -and $_.EndsWith($ModulePackageExtension) } | Get-ModulePackage 

            # If they passed (just) the name to a psmx, we need to set a fake name that couldn't possibly be a real module name
            if(($moduleName.Count -gt 0) -and ($PSBoundParameters['Name'].Count -eq 0)) {
               $PSBoundParameters['Name'] = " "
            }
         } else {
            $PSBoundParameters['Name'] = "*"
         }

         Write-Verbose "Get-Module $($moduleName -join ', ')"

         if($PSBoundParameters['Name'] -ne " ") {
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Module',  [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters | Update-ModuleInfo}
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
         }
      } catch {
         throw
      }
   }

   process
   {
      try {
         if ($PSBoundParameters.TryGetValue('Name', [ref]$moduleName))
         {
            $PSBoundParameters['Name'] = $moduleName | Where-Object { !$_.EndsWith($ModulePackageExtension) }
            $moduleName | Where-Object { $_.EndsWith($ModulePackageExtension) } | Get-ModulePackage
         }

         if($steppablePipeline -and $PSBoundParameters['Name'] -ne " ") {
            $steppablePipeline.Process($_)
         }
      } catch {
         throw
      }
   }

   end
   {
      # Pop-Location
      try {
         if($steppablePipeline -and $PSBoundParameters['Name'] -ne " ") {
            $steppablePipeline.End()
         }
      } catch {
         throw
      }
   }
   <#
      .ForwardHelpTargetName Get-Module
      .ForwardHelpCategory Cmdlet
   #>
}

# Private Function Called by Read-Module when you explicitly pass it a psmx file
# Basically the same as Read-Module, but for working with Package (psmx) files 
# TODO: Make this work for simple .zip files if they have a "package.psd1" file in them.
#       That way, we can use it for source zips from GitHub etc.
# TODO: Make this work for nuget packages (parse the xml, and if they have a module, parse it's maifest)
function Get-ModulePackage {
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

            ## First load the package metadata if there is one (that has URLs in it)
            $Manifest = @($Package.GetRelationshipsByType( $PackageMetadataType ))[0]
            $NugetManifest = @($Package.GetRelationshipsByType( $ManifestType ))[0]
            $ModuleManifest = @($Package.GetRelationshipsByType( $ModuleMetadataType ))[0]

            if(!$Manifest -or !$Manifest.TargetUri) {
               $DownloadUri = @($Package.GetRelationshipsByType( $PackageDownloadType ))[0]
               $ManifestUri = @($Package.GetRelationshipsByType( $PackageManifestType ))[0]
               if((!$ManifestUri -or !$ManifestUri.TargetUri) -and (!$DownloadUri -or !$DownloadUri.TargetUri)) {
                  Write-Warning "This is not a full PoshCode Package, it has not specified the manifest nor a download Url"
               }
               $PackageManifest = @{}
            } else {
               $Part = $Package.GetPart( $Manifest.TargetUri )
               if(!$Part) {
                  Write-Warning "This file is not a valid PoshCode Package, the specified Package manifest is missing at $($Manifest.TargetUri)"
                  $PackageManifest = @{}
               } else {
                  Write-Verbose "Reading Package Manifest From Package: $($Manifest.TargetUri)"
                  $PackageManifest = Import-ManifestStream ($Part.GetStream())
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
                  if($NuGetManifest = Import-NuGetStream ($Part.GetStream())) {
                     $PackageManifest = Update-Dictionary $NuGetManifest $PackageManifest
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
               if($ModuleManifest = Import-ManifestStream ($Part.GetStream())) {
                  ## If we got the module manifest, update the PackageManifest
                  $PackageManifest = Update-Dictionary $ModuleManifest $PackageManifest
               }
            }
            New-Object PSObject -Property $PackageManifest
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

# Internal function for additionally loading the package manifest
function Update-ModuleInfo {
   [CmdletBinding()]
   param(
       [Parameter(ValueFromPipeline=$true)]
       $ModuleInfo
   )
   process {
      Write-Verbose "> Updating ModuleInfo $($ModuleInfo.GetType().Name)"
      # On PowerShell 2, Modules that aren't loaded have little information, and we need to Import-Metadata
      # Modules that aren't loaded have no SessionState. If their path points at a PSD1 file, load that
      if(($ModuleInfo -is [System.Management.Automation.PSModuleInfo]) -and !$ModuleInfo.SessionState -and [IO.Path]::GetExtension($ModuleInfo.Path) -eq $ModuleManifestExtension) {
         $ExistingModuleInfo = $ModuleInfo
         $ModuleInfo = $ModuleInfo.Path
      }

      if(($ModuleInfo -is [string]) -and (Test-Path $ModuleInfo)) {
         $ModuleManifestPath = Convert-Path $ModuleInfo

         try {
            if(!$ExistingModuleInfo) {
               $ModuleInfo = Import-Metadata $ModuleManifestPath -AsObject
            } else {
               $ModuleInfo = Import-Metadata $ModuleManifestPath
               Write-Verbose "Update-ModuleInfo merging manually-loaded metadata to existing ModuleInfo:`n$($ExistingModuleInfo | Format-List | Out-String)"
               $ModuleInfo = Update-Dictionary $ExistingModuleInfo $ModuleInfo
               Write-Verbose "Result of merge:`n$($ModuleInfo | Format-List | Out-String)"
            }
            $ModuleInfo = $ModuleInfo | Add-Member NoteProperty Path $ModuleManifestPath -Passthru -Force
            $ModuleInfo = $ModuleInfo | Add-Member NoteProperty ModuleManifestPath $ModuleManifestPath -Passthru -Force
            if(!$ModuleInfo.ModuleBase) {
               $ModuleInfo = $ModuleInfo | Add-Member NoteProperty ModuleBase (Split-Path $ModuleManifestPath) -Passthru -Force
            }
            $ModuleInfo = $ModuleInfo | Add-Member NoteProperty PSPath ("{0}::{1}" -f $ModuleManifestPath.Provider, $ModuleManifestPath.ProviderPath) -Passthru -Force
         } catch {
            $ModuleInfo = $null
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unable to parse Module Manifest", "InvalidResult", $_) )
         }
      } else {
         $ModuleInfo = Add-SimpleNames $ModuleInfo
      }

      if($ModuleInfo) {
         $ModuleBase = Split-Path $ModuleInfo.Path
         $PackageInfoPath = Join-Path (Split-Path $ModuleInfo.Path) "Package.psd1"
         $ModuleManifestPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf).psd1"
         $NugetManifestPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf).nuspec"

         if(Test-Path $NugetManifestPath) {
            try {
               $reader = [IO.File]::Open($NugetManifestPath, "Open", "Read", "Read")
               $NugetInfo = Import-NugetStream -Stream $reader
               $ModuleInfo = Update-Dictionary $ModuleInfo $NugetInfo
            } catch {
               $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unable to parse Nuget Manifest", "InvalidResult", $_) )
            } finally {
               $reader.close()
            }
         }

         ## This is the PoshCode metadata file: Package.psd1
         # Since we're not using anything else, we won't add the aliases...
         if(Test-Path $PackageInfoPath) {
            Write-Verbose "Loading package info from $PackageInfoPath"
            try {
               $PackageInfo = Import-Metadata $PackageInfoPath
            } catch {
               $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unable to parse Package Manifest", "InvalidResult", $_) )
            }
            if($PackageInfo) {
               Write-Verbose "Update Dictionary with PackageInfo"
               $PackageInfo.ModuleManifestPath = $ModuleManifestPath
               Update-Dictionary $ModuleInfo $PackageInfo
            } else {
               Write-Verbose "Add ModuleManifestPath (Package Manifest not found)."
               Update-Dictionary $ModuleInfo @{ModuleManifestPath = $ModuleManifestPath}
            }
         } else {
            $ModuleInfo
         }
      }
   }
}

# Internal function for making sure we have Name, ModuleName, Version, and ModuleVersion properties
function Add-SimpleNames {
   param(
      [Parameter(ValueFromPipeline=$true)]
      $ModuleInfo)
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

# Internal function to updates dictionaries or ModuleInfo objects with extra metadata
# This is the guts of Update-ModuleInfo and Get-ModulePackage
# It is currently hard-coded to handle the RequiredModules nested array of hashtables
# But it ought to be extended to handle objects, hashtables, and arrays, with a specified key
function Update-Dictionary {
   param(
      $Authoritative,
      $Additional,
      [string[]]$KeyName = @("Name","ModuleName")
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
               # The only reason to bother with RequiredModules is if they have a PackageManifestUri
               foreach($depInfo in @($Additional.RequiredModules | Where-Object { $_.PackageManifestUri })) {
                  $name = $depInfo.Name
                  Write-Verbose "Additional Requires: $name"
                  # If this Required Module is already listed, then just add the uri
                  # Otherwise should we add it? (as a hashtable with the info we have?)
                  if($rmNames -contains $name) {
                     foreach($required in $Authoritative.RequiredModules) {
                        if(($required -is [string]) -and ($required -eq $name)) {
                           $Authoritative.RequiredModules[([Array]::IndexOf($Authoritative.RequiredModules,$required))] = $depInfo
                        } elseif($required.Name -eq $name) {
                           Write-Verbose "Authoritative also Requires $name - adding PackageManifestUri ($($depInfo.PackageManifestUri))"
                           if($required -is [System.Collections.IDictionary]) {
                              Write-Verbose "Required is a Hashtable, adding PackageManifestUri: $($depInfo.PackageManifestUri)"
                              if(!$required.Contains("PackageManifestUri")) {
                                 $required.Add("PackageManifestUri", $depInfo.PackageManifestUri)
                              }
                           } else {
                              Add-Member -InputObject $required -Type NoteProperty -Name "PackageManifestUri" -Value $depInfo.PackageManifestUri -ErrorAction SilentlyContinue
                              Write-Verbose "Required is an object, added PackageManifestUri: $($required | FL * | Out-String | % TrimEnd )"
                           }
                        }
                     }
                  } else {
                     Write-Warning "Mismatch in RequiredModules: Package manifest specifies $name"
                  }
               }
            }
            default {
               ## We only add properties, never replace, so hide errors
               if($Authoritative -is [System.Collections.IDictionary]) {
                  if(!$Authoritative.Contains($prop.Name)) {
                     $Authoritative.Add($prop.Name, $prop.Value)
                  }
               } else {
                  if(!$Authoritative.($prop.Name) -or ($Authoritative.($prop.Name).Count -eq 0)) {
                     Add-Member -in $Authoritative -type NoteProperty -Name $prop.Name -Value $prop.Value -Force -ErrorAction SilentlyContinue
                  }
               }            
            }
         }
      }
      $Authoritative | Add-SimpleNames
   }
}

function Import-NugetStream {
   param(
      [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
      [System.IO.Stream]$stream,

      # Convert a top-level hashtable to an object before outputting it
      [switch]$AsObject
   )
   try {
      $reader = New-Object System.IO.StreamReader $stream
      # This gets the package info
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
   $NugetManifest = ([Xml]$ManifestContent).package.metadata
   $NugetData = @{}
   if($NugetManifest.id)         { $NugetData.ModuleName    = $NugetManifest.id }
   if($NugetManifest.version)    { $NugetData.ModuleVersion = $NugetManifest.version }
   if($NugetManifest.authors)    { $NugetData.Author        = $NugetManifest.authors }
   if($NugetManifest.owners)     { $NugetData.CompanyName   = $NugetManifest.owners }
   if($NugetManifest.description){ $NugetData.Description   = $NugetManifest.description }
   if($NugetManifest.copyright)  { $NugetData.Copyright     = $NugetManifest.copyright }
   if($NugetManifest.licenseUrl) { $NugetData.LicenseUri    = $NugetManifest.licenseUrl }
   if($NugetManifest.projectUrl) { $NugetData.ModuleInfoUri = $NugetManifest.projectUrl }
   if($NugetManifest.tags)       { $NugetData.Keywords      = $NugetManifest.tags -split ',' }

   if($AsObject) {
      New-Object PSObject -Property $NugetData
   } else {
      $NugetData
   }
}


# Internal Function for parsing Module and Package Manifest Streams from Get-ModulePackage
# This is called twice from within Get-ModulePackage (and from nowhere else)
function Import-ManifestStream {
   #  .Synopsis
   #  Import a manifest from an IO Stream
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
   Import-Metadata $ManifestContent -AsObject:$AsObject
}


# These functions are just simple helpers for use in data sections (see about_data_sections) and .psd1 files (see ConvertFrom-Metadata)
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
      [string]$Path,

      # Convert a top-level hashtable to an object before outputting it
      [switch]$AsObject
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
         $ModuleInfo = ConvertFrom-Metadata $Path | Add-SimpleNames
      } catch {
         $PSCmdlet.ThrowTerminatingError( $_ )
      }

      if($ModuleInfo -and $AsObject) {
         $ModuleInfo | % { 
            $_.RequiredModules = foreach($M in @($_.RequiredModules)) { 
               if($M -is [String]) { $M = @{ModuleName=$M} }
               New-Object PSObject -Property $M | % {
                  $_.PSTypeNames.Insert(0,"System.Management.Automation.PSModuleInfo")
                  $_.PSTypeNames.Insert(0,"PoshCode.ModuleInfo.PSModuleInfo")
                  $_
               }
            }

            New-Object PSObject -Property $_ } | % {
            $_.PSTypeNames.Insert(0,"System.Management.Automation.PSModuleInfo")
            $_.PSTypeNames.Insert(0,"PoshCode.ModuleInfo.PSModuleInfo")
            $_
         }
      } else {
         Write-Output $ModuleInfo
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

   process {
      $data += @($InputObject)
   }

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
         if(!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(),"psd1")
            Set-Content -Path $Path $InputObject
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
         Write-Host (Get-PSCallStack | Out-String) -ForegroundColor Cyan
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
      [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
      $InputObject
   )
   begin { $t = "  " }

   process {
      if($InputObject -is [Int16] -or 
         $InputObject -is [Int32] -or 
         $InputObject -is [Int64] -or 
         $InputObject -is [Double] -or 
         $InputObject -is [Decimal] -or 
         $InputObject -is [Byte] -or
         $InputObject -is [Version] ) { 
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
      elseif($InputObject -is [String])  {
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

Export-ModuleMember -Function Read-Module, Update-ModuleInfo, Import-Metadata, Export-Metadata, ConvertFrom-Metadata, ConvertTo-Metadata
