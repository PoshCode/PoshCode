PoshCode Packaging Module (BETA)
===============================

#### PoshCode Modules for Packaging, Searching, Fetching

PoshCode's purpose is (and has always been) to make it easier to distribute modules (and scripts) over the internet or within local networks.  **With this new module we are focusing on making it easy to distribute modules without explaining module installation to your users.**  Additionally, we're supporting the automatic installation of dependencies, so that you can distribute  modules which have a dependency on other modules without worrying about how your users will find those modules.

The PoshCode Module Package format (.psmx) provides URIs as part of the package manifest: a _ReleaseUri_ to check for updates, a _LicenseUri_ to view the software license/eula, and _ProjectUri_ for the module's homepage. However, it also provides the _ReleaseURI_s for any dependencies. This allows tools (like our module) to not only check for updates, but also download dependencies automatically.

> It is our intention to provide a _module registry_ on PoshCode.org (rather than a repository). The idea is that module authors/developers can post metadata about their module which will allow people to find it, without needing to upload the module to yet another repository. Specifically, we would collect the author's name, the module name (and GUID), and the URI's for the package feed, as well as the license, help info, and project website URIs. This will allow users to search the registry to _find_ modules, but will also allow developers to continue hosting those modules wherever they like, without having to update the PoshCode site with each release.

PoshCode Packaging
------------------

The main Packaging module contains the New-ModulePackage and the Get-ModuleInfo and Update-ModuleInfo commands.  Theses commands are the core commands needed for **creating** module packages and the .moduleInfo files which are embedded in them. They depend on XAML serialization of some types which must be defined in C#, and so are kept separate from the more important commands for extracting packages (which do not require the binary assembly).

### Installation

The Installation submodule is the most important *part of the Packaging Module*, in a sense, it's the "*Packaging Lite*" module. It contains the commands for fetching modules from the internet and extracting them locally, as well as a light version of the Get-ModuleInfo command. This ***(will soon)*** includes the ability to fetch dependencies and check for updates.

You can bootstrap install the current release of the Packaging module in PowerShell 3 by using Invoke-Expression and Invoke-WebRequest like this:

```posh
IEX (IWR http://PoshCode.org/Install).Content
```

PowerShell 2 requires a little more code to download the install script:

```posh
IEX (New-Object Net.WebClient).DownloadString("http://PoshCode.org/Install")
```

The key feature of the Installation submodule is that it can be invoked as a script (using iex on it's contents) to install the main module, but can also serve itself as a light version of the Packaging module, suitable for end users that don't ever need to create packages, or that need to avoid creating the binary assemblies used by the main Packaging module.

#### The current PoshCode Packaging module release supports:

* Creating and Updating .moduleinfo xml manifests for modules (from .psd1 info)
* Reading .moduleinfo (or .psd1) manifests to present information about a module
* Creating packages (.psmx files) from modules (with .moduleinfo embedded)
* Reading .moduleinfo manifests directly from a package (without extracting)
* Installing (extracting) packages to your local system
  * Downloading packages from the web
  * Installing packages from local file paths or urls
  * Checking dependencies (and downloading them if they have URLs and are needed)
  * Skipping downloads of dependencies if they are installed already or the package is available
* Configuration of the paths used for installing by default
* Validation (warns if not) that install paths are in PSModulePath


Note: this module is still in **beta** and may cause loss of data (from your .psd1 files, or modules which you choose to *overwrite* on install) when used -- please make copies before testing!

Additional Modules
------------------

There are actually a couple of sub-modules in this project which are fairly important, and which we hope will be generally useful for other module developers:

### InvokeWeb

The Invoke-Web command is a PowerShell 2 compatible advanced function which implements most of the functionality of Invoke-WebRequest, along with the ability to accept self-signed certificates as valid for ssl/tls connections, and some additional features.

It does not (yet) wrap the results in a container, and defaults to saving the output to file (which I happen to think of as a _feature_, rather than a missing feature).

### Configuration

These commands could be useful for any module which needs to store key=value pairs on disk. The Get-ConfigData and Set-ConfigData commands allow you to read a simple key=value file just the way that ConvertFrom-StringData does, except they have a couple of very useful features: 

1. There is no need to double-up on backslashes (\\)
2. Windows Special Folders can be used by name in the values, like {MyDocuments}

The Get-SpecialFolder command allows you to get a hashtable of all the special folder names and values (so you can see what {tokens} are available), or to look up a specific special folder name to get the path.

The one thing that we **still want to do** for it is to add support for reading/writing from the user's AppData folder if the module is ReadOnly (i.e.: if you're not elevated, and the module is installed to a common location, the config should read the global location but overwrite those valuess with ones in the user's AddData folder).


Major TODO Items:
=================

If you want to help, I could use help in verious areas, please contact me to let me know that you'll work on one so we don't double up :)

The simplest (but most important) thing that you can do is to just test the module, and file issues here on GitHub.

The biggest thing you can do is to write Test Case scripts for me. There are some examples in the Tests.ps1 file, but we need a lot more (I would use my PSAINT module for tests, but I don't really care too much).

- Write test cases involving weird paths: UNC folders, PSDrives, self-signed https servers (probably not supported yet)
- Write test cases for the ModulePackage cmdlets
- Write test cases for the ModuleInfo cmdlets
- Write test cases for the Invoke-Web cmdlet

Additionally, I've got a fairly long task list that starts with these items:

- A format for update feeds
  - Determine the feed format, considering NuGet atom and HelpInfoUri
  - Write Update-Module(Package?) to check for updates
  - Generate the feed during New-ModulePackage
- Support for downgrading (I need thoughts on how this should behave)
- Support for SxS versions (I need thoughts on how this could work)
- Write .Example sections for the major external functions from the modules. Please be sure they are also added (with verification) as test cases in Tests.ps1
- Code Review Update-ModuleInfo (I think it's still missing some parameters for updates, and it's definitely missing support for removing items from psd1)
