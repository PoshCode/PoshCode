# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Configuration"
###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Installation.psm1 defines the core commands for installing packages:
## Get-ModuleInfo and Install-Module 
## It depends on the Configuration module and the Invoke-WebRequest cmdlet

# FULL # BEGIN FULL: Don't include this in the installer script
. $PSScriptRoot\Constants.ps1

# Public Function
# This is a wrapper for Get-Module which uses Update-ModuleInfo to load the package manifest
# It simply extends the output of Get-Module with anything from package.psd1
function Get-Module {
   [CmdletBinding(DefaultParameterSetName='Loaded', HelpUri='http://go.microsoft.com/fwlink/?LinkID=141552')]
   param(
      [Parameter(ParameterSetName='PsSession', Position=0, ValueFromPipeline=$true)]
      [Parameter(ParameterSetName='Available', Position=0, ValueFromPipeline=$true)]
      [Parameter(ParameterSetName='CimSession', Position=0, ValueFromPipeline=$true)]
      [Parameter(ParameterSetName='Loaded', Position=0, ValueFromPipeline=$true)]
      [string[]]
      ${Name},

      [Parameter(ParameterSetName='Available')]
      [Parameter(ParameterSetName='Loaded')]
      [switch]
      ${All},

      [Parameter(ParameterSetName='PsSession')]
      [Parameter(ParameterSetName='CimSession')]
      [Parameter(ParameterSetName='Available', Mandatory=$true)]
      [switch]
      ${ListAvailable},

      [Parameter(ParameterSetName='CimSession')]
      [Parameter(ParameterSetName='Available')]
      [Parameter(ParameterSetName='PsSession')]
      [switch]
      ${Refresh},

      [Parameter(ParameterSetName='PsSession', Mandatory=$true)]
      [ValidateNotNull()]
      [System.Management.Automation.Runspaces.PSSession]
      ${PSSession},

      [Parameter(ParameterSetName='CimSession', Mandatory=$true)]
      [ValidateNotNull()]
      [Microsoft.Management.Infrastructure.CimSession]
      ${CimSession},

      [Parameter(ParameterSetName='CimSession')]
      [ValidateNotNull()]
      [uri]
      ${CimResourceUri},

      [Parameter(ParameterSetName='CimSession')]
      [ValidateNotNullOrEmpty()]
      [string]
      ${CimNamespace}
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
         }

         $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Module',  [System.Management.Automation.CommandTypes]::Cmdlet)
         $scriptCmd = {& $wrappedCmd @PSBoundParameters | Update-ModuleInfo }
         $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
         $steppablePipeline.Begin($PSCmdlet)
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

         $steppablePipeline.Process($_)
      } catch {
         throw
      }
   }

   end
   {
      # Pop-Location
      try {
         $steppablePipeline.End()
      } catch {
         throw
      }
   }
   <#
      .ForwardHelpTargetName Get-Module
      .ForwardHelpCategory Cmdlet
   #>
}
# FULL # END FULL

# Private Function Called by Get-Module when you explicitly pass it a psmx file
# Basically the same as Get-Module, but for working with Package (psmx) files 
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

            ## First load the package manifest (which has URLs in it)
            $Manifest = @($Package.GetRelationshipsByType( $ManifestType ))[0]
            if(!$Manifest -or !$Manifest.TargetUri) {
               Write-Warning "This file is not a valid PoshCode Package, it has not specified the manifest"
               return
            }
            $Part = $Package.GetPart( $Manifest.TargetUri )
            if(!$Part) {
               Write-Warning "This file is not a valid PoshCode Package, it has no manifest at $($Manifest.TargetUri)"
               return
            }
            Write-Verbose "Reading Manifest: $($Manifest.TargetUri)"
            $PackageManifest = Import-ManifestStream ($Part.GetStream())

            ## Now load the module manifest (which has everything else in it)
            $Manifest = @($Package.GetRelationshipsByType( $ModuleMetadataType ))[0]
            if(!$Manifest -or !$Manifest.TargetUri) {
               Write-Warning "This file is not a valid PoshCode Package, it has not specified the manifest"
               return
            }
            if($Part = $Package.GetPart( $Manifest.TargetUri )) {
               Write-Verbose "Reading Manifest: $($Manifest.TargetUri)"
               if($ModuleManifest = Import-ManifestStream ($Part.GetStream())) {
                  ## If we got the module manifest, update the PackageManifest
                  $PackageManifest = Update-Dictionary $ModuleManifest $PackageManifest
               }
            }
            Write-Output $PackageManifest
         } catch [Exception] {
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
         } finally {
            $Package.Close()
            $Package.Dispose()
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
      if(($ModuleInfo -is [string]) -and (Test-Path $ModuleInfo)) {
         $ModuleManifestPath = Resolve-Path $ModuleInfo
         Write-Verbose "Get-ModuleManifest: $ModuleManifestPath"
         $ModuleInfo = Get-ModuleManifest $ModuleManifestPath
         Write-Verbose "Get-ModuleManifest: $ModuleInfo"
         $ModuleInfo.ModuleManifestPath = $ModuleInfo.Path = $ModuleManifestPath 
         $ModuleInfo.PSPath = "{0}::{1}" -f $ModuleManifestPath.Provider, $ModuleManifestPath.ProviderPath
      } else {
         $ModuleInfo = Add-SimpleNames $ModuleInfo
      }
      if($ModuleInfo) {
         $PackageInfoPath = Join-Path (Split-Path $ModuleInfo.Path) "Package.psd1"
         $ModuleBase = Split-Path $ModuleInfo.Path
         $ModuleManifestPath = Join-Path $ModuleBase "$(Split-Path $ModuleBase -Leaf).psd1"

         ## This is the PoshCode metadata file: Package.psd1
         # Since we're not using anything else, we won't add the aliases...
         if(Test-Path $PackageInfoPath) {
            Write-Verbose "Loading package info from $PackageInfoPath"
            $PackageInfo = Get-ModuleManifest $PackageInfoPath
            if($PackageInfo) {
               $PackageInfo.ModuleManifestPath = $ModuleManifestPath
               Update-Dictionary $ModuleInfo $PackageInfo
            } else {
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
      foreach($rm in $ModuleInfo.RequiredModules) {
         if($rm.Name) {
            Add-Member -InputObject $rm -MemberType ScriptProperty -Name ModuleName -Value { $this.Name } -ErrorAction SilentlyContinue
         } elseif($rm.ModuleName) {
            Add-Member -InputObject $rm -MemberType ScriptProperty -Name Name -Value { $this.ModuleName } -ErrorAction SilentlyContinue
         }
         if($rm.Version) {
            Add-Member -InputObject $rm -MemberType ScriptProperty -Name ModuleVersion -Value { $this.Version } -ErrorAction SilentlyContinue
         } elseif($rm.ModuleVersion) {
            Add-Member -InputObject $rm -MemberType ScriptProperty -Name Version -Value { $this.ModuleVersion } -ErrorAction SilentlyContinue
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
               # The only reason to bother with RequiredModules is if they have a ModuleInfoUri
               foreach($depInfo in @($Additional.RequiredModules | Where-Object { $_.ModuleInfoUri })) {
                  $name = $depInfo.Name
                  Write-Verbose "Additional Requires: $name"
                  # If this Required Module is already listed, then just add the uri
                  # Otherwise should we add it? (as a hashtable with the info we have?)
                  if($rmNames -contains $name) {
                     foreach($required in $Authoritative.RequiredModules) {
                        if(($required -is [string]) -and ($required -eq $name)) {
                           $Authoritative.RequiredModules[($Authoritative.RequiredModules.IndexOf($required))] = $depInfo
                        } elseif($required.Name -eq $name) {
                           Write-Verbose "Authoritative also Requires $name - adding ModuleInfoUri ($($depInfo.ModuleInfoUri))"
                           if($required -is [System.Collections.IDictionary]) {
                              Write-Verbose "Required is a Hashtable, adding ModuleInfoUri: $($depInfo.ModuleInfoUri)"
                              if(!$required.Contains("ModuleInfoUri")) {
                                 $required.Add("ModuleInfoUri", $depInfo.ModuleInfoUri)
                              }
                           } else {
                              Add-Member -InputObject $required -Type NoteProperty -Name "ModuleInfoUri" -Value $depInfo.ModuleInfoUri -ErrorAction SilentlyContinue
                              Write-Verbose "Required is an object, added ModuleInfoUri: $($required | FL * | Out-String | % TrimEnd )"
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
                  Add-Member -in $Authoritative -type NoteProperty -Name $prop.Name -Value $prop.Value -ErrorAction SilentlyContinue
               }            
            }
         }
      }
      $Authoritative
   }
}

# Internal Function for parsing Module and Package Manifest Streams from Get-ModulePackage
# This is called twice from within Get-ModulePackage (and from nowhere else)
function Import-ManifestStream {
   #  .Synopsis
   #  Import a manifest from an IO Stream
   param(
      [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
      [System.IO.Stream]$stream
   )   
   try {
      $reader = New-Object System.IO.StreamReader $stream
      # This gets the ModuleInfo
      Get-ModuleManifest ($reader.ReadToEnd())
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
}

# Internal Function for parsing Module and Package Manifests
function Get-ModuleManifest {
   #  .Synopsis
   #  Parse a module manifest the best way we can.
   param(
      [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
      [string]$Manifest
   )
   begin {
      $ValidTokens = "GroupStart", "GroupEnd", "Member", "Operator", "String", "Comment", "NewLine", "StatementSeparator"
      $ParseErrors = $Null
   }
   process {
      # When we have a file, use Import-LocalizedData (via Import-PSD1)
      if(Test-Path $Manifest) {
         Write-Verbose "Importing Module Manifest From Path: $Manifest"
         if(!(Test-Path $Manifest -PathType Leaf)) {
            $Manifest = Join-Path $Manifest ((Split-Path $Manifest -Leaf) + $ModuleInfoExtension)
         }
         $Manifest = Convert-Path $Manifest
         Import-PSD1 $Manifest -ErrorAction "SilentlyContinue"

      # Otherwise, use the Tokenizer and Invoke-Expression with a "Data" section
      } else {
         Write-Verbose "Importing Module Manifest From Content: $($Manifest.Length)"
         $Tokens = [System.Management.Automation.PSParser]::Tokenize($Manifest,[ref]$ParseErrors)
         if($ParseErrors -ne $null) {
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord "Parse error reading package manifest", "Parse Error", "InvalidData", $ParseErrors) )
            return
         }
         if($InvalidTokens = $Tokens | Where-Object { $ValidTokens -notcontains $_.Type }){
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord "Invalid Tokens found when parsing package manifest", "Parse Error", "InvalidData", $InvalidTokens) )
            return
         }
         # Even with this much protection, Invoke-Expression makes me nervous, which is why I try to avoid it.
         Invoke-Expression "Data { ${Manifest} } "
      }
   }
}

# Internal function. This is a wrapper for Import-LocalizedData to make it easier to (mis)use ;)
# This is HALF the functionality of Get-ModuleManifest (this part gets called for files)
# NOTE: Even internally, we should call Get-ModuleManifest instead of Import-PSD1
function Import-PSD1 {
   [CmdletBinding()]
   param(
      # [Parameter(Position=0)]
      # [Alias('Variable')]
      # [ValidateNotNullOrEmpty()]
      # [string]
      # ${BindingVariable},

      # [Parameter(Position=1)]
      # [string]
      # ${UICulture},

      # [string]
      # ${BaseDirectory},

      [Parameter(Position=0)]
      [string]
      ${FileName},

      [string[]]
      ${SupportedCommand}
   )

   begin
   {
      if($Folder = Split-Path $FileName) {
         $PsBoundParameters["FileName"] = [IO.Path]::GetFileName($FileName)
         $PsBoundParameters.Add("BaseDirectory", $Folder)
      }
      try {
         Write-Verbose $($PsBoundParameters|OUt-String)
         $outBuffer = $null
         if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
         {
            $PSBoundParameters['OutBuffer'] = 1
         }
         $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Import-LocalizedData', [System.Management.Automation.CommandTypes]::Cmdlet)
         $scriptCmd = {& $wrappedCmd @PSBoundParameters | Add-SimpleNames }
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
   }

   end
   {
      try {
         $steppablePipeline.End()
      } catch {
         throw
      }
   }
}

