@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'Packaging.psm1'

# Version number of this module.
ModuleVersion = '4.0.1.6'

# ID used to uniquely identify the PoshCode module
GUID = '88c6579a-27b2-41c8-86c6-cd23acb791e9'

# Author of this module
Author = 'Joel "Jaykul" Bennett <Jaykul@HuddledMasses.org>'

# Description of the functionality provided by this module
Description = 'PoshCode Module for PowerShell Module Packaging and Script Sharing'

# Company or vendor of this module
CompanyName = 'http://HuddledMasses.org'

# Copyright statement for this module
Copyright = 'Copyright (c) 2013 by Joel Bennett, all rights reserved.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = '2.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '2.0'

# Processor architecture (None, X86, Amd64) required by this module
ProcessorArchitecture = 'None'

# Modules that must be imported into the global environment prior to importing this module
#RequiredModules = @('PoshCode\Configuration.psm1', 'PoshCode\Installation.psm1', 'PoshCode\Scripts.psm1', 'PoshCode\InvokeWeb.psm1')

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = 'WindowsBase', 'PresentationFramework'

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @('PoshCode.types.ps1xml')

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @('PoshCode.format.ps1xml')

# List of all modules packaged with this module.
ModuleList = @('Metadata', 'Atom', 'ModuleInfo', 'Configuration', 'Installation', 'InvokeWeb', 'Packaging', 'Scripts', 'Repository')

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# Note: We do not specify InvokeWeb -- That should only be imported if the test in the Installation module fails
NestedModules = @('Metadata.psm1', 'Atom.psm1', 'ModuleInfo.psm1', 'Configuration.psm1', 'Installation.psm1', 'Scripts.psm1', 'Repository.psm1')

# List of all files packaged with this module
FileList = 'PoshCode.packageInfo', 'PoshCode.psd1', 'Constants.ps1', 'Metadata.psm1', 'Atom.psm1', 
           'ModuleInfo.psm1', 'Configuration.psm1', 'Installation.psm1', 'Packaging.psm1', 'Scripts.psm1', 'Repository.psm1',
           'InvokeWeb.psm1', 'UserSettings.psd1',
           # Repository Modules
           'Repositories\GitHub.psm1', 'Repositories\Folder.psm1', 'Repositories\NuGet.psm1', 'Repositories\File.psm1',
           # Format and Type Files
           'PoshCode.format.ps1xml', 'PoshCode.types.ps1xml',
           # Docs
           'README.md'

# Functions to export from this module
FunctionsToExport = 'Install-Module', 'Find-Module', 'Update-Module',
                    'Compress-Module', 'Set-ModuleInfo', 'Get-ModuleInfo', 
                    # 'Import-Metadata', 'Export-Metadata', # 'Test-ExecutionPolicy', 
                    'Get-ConfigData', 'Set-ConfigData', 'Get-SpecialFolder', 
                    'Get-PoshCode', 'Send-PoshCode'

# Aliases to export from this module
AliasesToExport = '*'

}
