# Constants -- these must be the same for all modules, they are dot-sourced into each module
# NOTE: these types are needed elsewhere (Packaging Module)
#       the types aren't needed for the installer
#       but they are part of the "packaging light" module, so here they are.
# This is what nuget uses for .nuspec, we use it for .moduleinfo ;)
$ManifestType            = "http://schemas.microsoft.com/packaging/2010/07/manifest"
# We need to make up a URL for the metadata psd1 relationship type
$ModuleMetadataType      = "http://schemas.poshcode.org/package/module-metadata"
$ModuleHelpInfoType      = "http://schemas.poshcode.org/package/help-info"
$PackageThumbnailType    = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"
# I'm not sure there's any benefit to extra types:
# CorePropertiesType is the .psmdcp
$CorePropertiesType      = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
$ModuleRootType          = "http://schemas.poshcode.org/package/module-root"
$ModuleContentType       = "http://schemas.poshcode.org/package/module-file"
$ModuleReleaseType       = "http://schemas.poshcode.org/package/module-release"
$ModuleLicenseType       = "http://schemas.poshcode.org/package/module-license"

# Because of a PowerShell Bug, we need to know where we can find an empty folder
foreach($possibility in @("CdBurning", "CommonDocuments", "CommonVideos", "CommonMusic", "CommonPictures", "MyVideos", "MyMusic", "MyPictures")) {
   try {
      $folder = [Environment]::GetFolderPath($possibility)
      if((Test-Path $folder) -and !(Get-ChildItem $folder)) {
         $EmptyPath = $folder
         break
      }
   } catch {}
}
if(!$EmptyPath) {
   $EmptyPath = [Environment]::GetFolderPath("SendTo")
}

# Our Extensions
$ModuleInfoFile          = "package.psd1"
$ModuleInfoExtension     = ".psd1"
$ModuleManifestExtension = ".psd1"
$ModulePackageExtension  = ".psmx"

if(!("System.IO.Packaging.Package" -as [Type])) {
    Add-Type -Assembly 'WindowsBase', 'PresentationFramework'
}