PoshCode Packaging Module (BETA)
===============================

PoshCode's purpose is (and has always been) to make it easier to distribute modules (and scripts) over the internet or within local networks.  **With this new project we are focusing on making it easy to distribute modules without explaining module installation to your users.**  Additionally, we're supporting the automatic installation of dependencies, so that you can distribute modules which have a dependency on other modules without worrying about how your users will find those modules.

#### *tl;dr:* Execute the following command to install the Packaging module:

```posh
\\PoshCode.org\Modules\Install
```

Note: that sometimes fails because Windows' WebDAV is a bit slow making initial connections. Usually running it again will work, but you can always run this instead, it's just that this way digital signatures are bypassed:

```posh
iex (iwr http://PoshCode.org/Modules/Install.ps1)
```

If you're trying to distribute a module, you can have users install the Packaging module at the same time as they install your module. For instance, if you've published your module on your website (I have one published here: http://poshcode.org/Modules/WASP.psdxml) you can point users at the psdxml manifest or your module psmx package:

#### Install your module by url

```posh
\\PoshCode.org\Modules\Install http://poshcode.org/Modules/WASP.psdxml
```

#### Download the module and install it by file path

```posh
\\PoshCode.org\Modules\Install ~\Downloads\WASP-2.0.0.5.psmx
```

Of course, in order to distribute your module, you should create a psmx module package first. This may require you to create a module manifest (which you should already have done) and a package manifest (which we will help you create based on your module manifest and folder). If you have the Packaging module and your module both installed on your computer (and you already have the psd1), you can get started by just running the command:

#### To create a module package:

```posh
New-ModulePackage YourModuleName
```



About PoshCode Packages and Manifests
=====================================

The PoshCode _Module Package_ format (.psmx) is based on Microsoft's [System.IO.Packaging](http://msdn.microsoft.com/en-us/library/system.io.packaging.aspx), and is essentially a .zip with an .xml package manifest.

The package manifest includes several URIs (which wouldn't otherwise be in your module manifest): 

* _ReleaseUri_ where the psd1xml will be hosted to check for updates
* _LicenseUri_ to view the software license/eula
* _ProjectUri_ for the module's homepage

At least at first, there will not be a central hosting repository (the equivalent of NuGet.org).  We are instead focusing on allowing distribution of modules through any web site that can host psmx and psdxml files (e.g. GitHub). One core requirement is to support distributing a module on one website that has dependencies on modules hosted on a different site. This means that PoshCode modules must also have the _ReleaseURI_s for their dependencies in the manifest. This allows tools (like our Packaging module) to not only check for updates, but also _download dependencies automatically_.

> It is our intention to provide a _module registry_ on PoshCode.org (not module hosting, but a listing of modules and their hosting). The idea is that module authors/developers can post metadata about their module which will allow people to find it, without needing to upload the module to yet another repository. Specifically, we would collect the author's name, the module name (and GUID), and the URI's for the package feed, license, help info, and website URIs. This will allow users to search the registry to _find_ modules, but will also allow developers to continue hosting those modules wherever they like, without having to update the PoshCode site with each release.

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
* Checking for new versions of any installed modules (with psdxml manifests)
	* Downloading new packages from the web
	* Removing old module and installing the new module
* Configuration of the paths used for installing by default
* Validation (warns if not) that install paths are in PSModulePath


Note: this module is still in **beta** and may cause loss of data (specifically, you should back up modules before creating packages of them, because you may overwrite the manifest while generating the package, and the rest of the module when you test the install).


The PoshCode Module
-------------------

The main PoshCode module contains three new submodules: Packaging, Installation, and Configuration. It also still has the Scripts module which made up the bulk of the original PoshCode module and includes the ability to search for and download script files from PoshCode.org.

### Packaging

The New-ModulePackage and the Get-ModuleInfo and Update-ModuleInfo commands are in the Packaging submodule, they are the core commands needed for **creating** module packages and the psdxml manifest files which are embedded in them. They depend on XAML serialization of some types which are be defined in C#, and so are kept separate from the more important commands for extracting packages (which do not require the binary assembly).  All of this is explained in detail in [Creating Module Packages]().

### Installation

The Installation submodule is, in one sense, the most important *part of the PoshCode Module*. It contains the portion of the PoshCode module which is required for installing modules, and is the only part that end-users will need. It contains the commands for fetching modules from the internet and extracting them locally, including the ability to fetch dependencies and check for updates. 

It even works with simple .zip files, and has a light version of the Invoke-WebRequest command (so it works in PowerShell 2). It is also provided wrapped as a script: Install.ps1 which can not only install _itself_, but any other module package.

### Configuration

The configuration submodule is a simple reusable module which the Installation module depends on. It has just three commands: Get and Set ConfigData, and Get-SpecialFolder (which allows you to use special folder names like {UserProfile} in the other configuration commands).  It's used to persist the location where you want to install your modules. If you're interested in reusing that functionality, you can read more about the [Configuration Module]().


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

Contributing:
=============

If you want to help, I would love it! Feel free to just do some work and send a pull request, or contact me, and can try to keep people from working on the same thing ;)

The simplest (but most important) thing that you can do is to just USE the module, and file issues or drop me an email with for any problems you find.

The most helpful thing you can do is to write automated Test Case scripts for me. There are some examples in the Tests.ps1 file, but we need a lot more (I would use my PSAINT module for tests, but I don't really care too much as long as we can prove it works).