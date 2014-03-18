# Constants -- these must be the same for all modules, they are dot-sourced into each module
# NOTE: these types are needed elsewhere (Packaging Module)
#       the types aren't needed for the installer
#       but they are part of the "packaging light" module, so here they are.

# Nuget XML Schema namespace
$NuGetNamespace          = "http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd"
# This is what nuget uses for .nuspec
$ManifestType            = "http://schemas.microsoft.com/packaging/2010/07/manifest"
# We need to make up a URL for the metadata psd1 relationship type
$ModuleMetadataType      = "http://schemas.poshcode.org/package/module-metadata"
$PackageMetadataType     = "http://schemas.poshcode.org/package/package-metadata"
$ModuleHelpInfoType      = "http://schemas.poshcode.org/package/help-info"
$PackageThumbnailType    = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"
# I'm not sure there's any benefit to extra types:
# CorePropertiesType is the .psmdcp
$CorePropertiesType      = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
$ModuleRootType          = "http://schemas.poshcode.org/package/module-root"
$ModuleLicenseType       = "http://schemas.poshcode.org/package/module-license"

$ModuleProjectType       = "http://schemas.poshcode.org/package/project"
$PackageDownloadType     = "http://schemas.poshcode.org/package/release"
$PackageManifestType     = "http://schemas.poshcode.org/package/manifest"

$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $(if($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $MyInvocation.MyCommand }) -Parent
}

# Because of a PowerShell Bug, we need to know where we can find a completely empty folder.
$EmptyPath = $PSMPSettings = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PowerShell Package Manager"
if(Test-Path $EmptyPath) {
    while(Get-ChildItem $EmptyPath) {
       $EmptyPath = New-Item -Force -ItemType Directory -Path (Join-Path $EmptyPath "__EMPTY__") | Convert-Path
    }
} else {
   $EmptyPath = New-Item -Force -ItemType Directory -Path $EmptyPath | Convert-Path
}

# Our Extensions
$NuSpecManifestExtension = ".nuspec"
$ModuleInfoFile          = "package.psd1"
$ModuleInfoExtension     = ".psd1"
$ModuleManifestExtension = ".psd1"
# Perhaps we should use NuGet's extension now that I've added the nuget manifest
# Using .nupkg instead of .psmx 
# 1) prevents us from having a custom icon
# 2) allows NuGet to find/process our packages
# 3) allows us to find/process their packages 
$ModulePackageExtension  = ".nupkg"

if(!("System.IO.Packaging.Package" -as [Type])) {
    Add-Type -Assembly 'WindowsBase', 'PresentationFramework'
}
