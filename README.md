PoshCode Packaging Module (BETA)
===============================

PoshCode's purpose is (and has always been) to make it easier to distribute modules (and scripts) over the internet or within local networks.  **With this new project we are focusing on making it easy to distribute modules without explaining module installation to your users.**  Additionally, we're supporting the automatic installation of dependencies, so that you can distribute modules which have a dependency on other modules without worrying about how your users will find those modules.

#### *tl;dr:* Execute the following command to install the Packaging module:

```posh
\\PoshCode.org\Modules\Install
```

Note: that sometimes fails because Windows' WebDAV is a bit slow making initial connections. Usually running it again will work (or opening the root `\\PoshCode.org\Modules` in explorer before running the command in PowerShell) but you can always run this instead (NOTE it overwrites `PC.ps1` in your current path):

```posh
iwr http://PoshCode.org/Modules/Install.ps1 -OutF PC.ps1; .\PC; rm .\PC.ps1
```

If you're trying to distribute a module, you can have users install the Packaging module at the same time as they install your module. For instance, if you've published your module on your website (I have one published here: http://poshcode.org/Modules/WASP.psd1) you can point users at the package manifest or at the actual module psmx package:

#### Install your module by url

```posh
\\PoshCode.org\Modules\Install http://poshcode.org/Modules/WASP.psd1
```

#### Download the module and install it by file path

That is, download the psmx file and run the install script against that file:

```posh
\\PoshCode.org\Modules\Install ~\Downloads\WASP-2.0.0.6.psmx
```

Of course, in order to distribute your module, you should create a psmx module package first. This may require you to create a module manifest (which you should already have done) and a package manifest (which is a second psd1 file named "package.psd1" which contains the ModuleName, ModuleVersion and four URLs, plus optionally, information about required modules). If you have the PoshCode module and your module both installed on your computer (and you already have the psd1), you can get started by just running the command:

#### To create a module package:

```posh
Compress-Module YourModuleName
```


About PoshCode Packages and Manifests
=====================================

The PoshCode _Module Package_ format (.psmx) is based on Microsoft's [System.IO.Packaging](http://msdn.microsoft.com/en-us/library/system.io.packaging.aspx), and is essentially a .zip with your module manifest and the "package.psd1" manifest.

The package manifest includes several URIs (which are not allowed in the module manifest): 

* _PackageManifestUri_ where the package.psd1 will be hosted to check for updates (usually renamed to the module name)
* _DownloadUri_ for the actual module package (mandatory in the version you upload to the PackageManifestUri)
* _LicenseUri_ to view the software license/eula
* _ProjectUri_ for the module's homepage

At least at first, there will not be a central hosting repository (the equivalent of NuGet.org).  We are instead focusing on allowing distribution of modules through any web site that can host psmx and psd1 files (e.g. GitHub/BitBucket/etc). One core requirement is to support distributing a module on one repository/website that has dependencies on modules which are hosted on a different repository. This means that PoshCode modules must also have the _PackageManifestUri_s for their dependencies in the package manifest (You're allowed an array of RequiredModules where each has a Name and PackageManifestUri). This allows tools (like the PoshCode module) to not only check for updates, but also _download dependencies automatically_.

> It is our intention to provide at least a _module registry_ on PoshCode.org (a listing of modules and where they are hosted). The idea is that module authors/developers can post metadata about their module which will allow people to find it, without needing to upload the module to yet another repository. Specifically, we would collect the author's name, the module name (and GUID), and the URI's for the package feed, license, help info, and website URIs. This will allow users to search the registry to _find_ modules, but will also allow developers to continue hosting those modules wherever they like, without having to update the PoshCode site with each release.

#### The current PoshCode Packaging module release supports:

* Creating packages (.psmx files) from modules (with the package.psd1 embedded)
* Reading .psd1 manifests directly from a package (without extracting to disk)
* Installing (extracting) packages to your local system
   * Downloading packages from the web
   * Installing packages from local file paths or urls
   * Checking dependencies (and downloading them if they have URLs and are not already installed)
   * Skipping downloads of dependencies if they are installed already or the package is available
* Checking for new versions of any installed modules (using the package.psd1 manifest)
   * Downloading updated packages from the web
   * Removing the old module _folder_ and installing the new module
      * UNIMPLEMENTED CONCERN: Preserve settings or config files in modules when upgrading
* Configuration of the paths used for installing by default
* Validation (warns if not) that install paths are in PSModulePath


Note: this module is currently in **alpha** and may cause loss of data!
Specifically, you should back up your modules before attempting upgrades, and you should read messages carefully when being prompted for deletes and overwrites. If you're promted to delete or overwrite when you're not expecting it, _please capture the full message and submit it as an issue or discussion thread_.


The PoshCode Module
-------------------

The main PoshCode module contains four new submodules: Packaging, Installation, ModuleInfo and Configuration. It also still has the Scripts module which made up the bulk of the original PoshCode module (including the ability to search for and download script files from PoshCode.org) and an InvokeWeb module which is conditionally loaded in PowerShell 2 which adds a simplified Invoke-WebRequest function.

I will also be adding the NewModule.psm1 module shortly commands for generating modules from scripts, and generating and testing package manifests.


### Installation

The Installation submodule is the most important *part of the PoshCode Module*. It contains the Install-Module and Upgrade-Module commands, and is really the only part that end-users will need. It depends, however, on the Configuration Submodule, the ModuleInfo submodule, and the Invoke-WebRequest command.  In other words, it requires everything else except the packaging module, and gives users the ability to fetch modules from the internet and extract them to the right place locally, including the ability to automatically fetch dependencies and check for updates. 

NOTE: Install-Module should even work with simple .zip files, and is the core of a script: Install.ps1 which can not only install _itself_, but any other module package (and which can be re-generated by using the NEW-InstallScript.ps1 script).


### Packaging

The Compress-Module command is in the Packaging submodule, it is the core command needed for **creating** module packages.

### ModuleInfo

ModuleInfo contains Read-Module: a wrapper for the built-in Get-Module command, which can also load a psd1 directly by path, or read from a module package. There are many other functions in this module also, but they are used internally by the Read-Module command (and other modules within PoshCode), not exported for users.

### Configuration

The configuration submodule contains the Get and Set ConfigData, Get-SpecialFolder, as well as Select-ModulePath and Test-ExecutionPolicy which are used during initial install of the PoshCode module itself. The ConfigData and SpecialFolder commands are used to persist the location where you want to install your modules and load it during installs.

These commands could be useful for any module which needs to store key=value pairs on disk. The Get-ConfigData and Set-ConfigData commands allow you to read a simple key=value file just the way that ConvertFrom-StringData does, except they have a couple of very useful features: 

1. There is no need to double-up on backslashes (\\)
2. Windows Special Folders can be used by name in the values, like {MyDocuments}

The Get-SpecialFolder command allows you to get a hashtable of all the special folder names and values (so you can see what {tokens} are available), or to look up a specific special folder name to get the path.

The one thing that I **still want to do** for it is to add support for reading/writing from the user's AppData folder instead of the module folder, so that the config can persist across installs, and be configurable per-user even for modules installed in the machine common location.

### InvokeWeb

The Invoke-Web command is a PowerShell 2 compatible advanced function which implements most of the functionality of Invoke-WebRequest, along with the ability to accept self-signed certificates as valid for ssl/tls connections, and some additional features.

It does not (yet) wrap the results in a container, and defaults to saving the output to file (which I happen to think of as a _feature_, rather than a missing feature).


Major TODO Items:
=================

- Finish New-Module and New-Package
- Validate the package.psd1 when calling Compress-Module
- Check/Update/Write help for the exported functions


Additionally, I've got a fairly long task list that starts with these items:

- Write test cases involving weird paths: UNC folders, PSDrives
- Write test cases for the Packaging cmdlets
   - Make sure we don't ignore it when the package.psd1 RequiredModules say "Name" instead of "ModuleName"
- Write additional test cases for the Installation cmdlets
- Write additional test cases for the ModuleInfo cmdlets
- Write test cases for the Invoke-Web cmdlet
- Test adding additional metadata to package.psd1 (e.g. an icon?) and verity it doesn't break anything
- Add functionality to Invoke-Web to support ignoring SSL certificates
- Support for downgrading (I need thoughts on how this should behave)
- Support for SxS versions (I need thoughts on how this could work)

Contributing:
=============

If you want to help, I would love it! Feel free to just do some work and send a pull request, or contact me, and can try to keep people from working on the same thing ;)

The simplest (but most important) thing that you can do is to just USE the module, and file issues or drop me an email with for any problems you find.

The most helpful thing you can do is to write automated Test Case scripts for me. There are some examples in the Tests.ps1 file, but we need a lot more (I am using my [PSAINT module]:http://poshcode.org/Modules/PSaint.psd1 for tests, but it still needs work, so I'm open to alternatives).