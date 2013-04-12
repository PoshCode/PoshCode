PoshCode BETA
=============

PoshCode Modules for Packaging, Searching, Fetching

The current build supports:

* Creating .moduleinfo xml manifests for modules on your local system
* Updating .moduleinfo xml manifests from the psd1 file in the module
* Reading .moduleinfo (or .psd1) manifests to present information about a module
* Creating packages (.psmx files) from modules on your local system
* Reading .moduleinfo manifests directly from a package (without extracting)
* Downloading packages 
* Installing (extracting) packages to your local system
* Configuration of the paths used for installing 

Note: this module is still in **beta** and may cause loss of data (from your .psd1 files, or modules which you choose to *overwrite* on install) when used -- please make copies before testing!

PoshCode Packaging
==================

The main Packaging module contains the New-ModulePackage and the Get-ModuleInfo and Update-ModuleInfo commands.  Theses commands are the core commands needed for **creating** module packages and the .moduleInfo files which are embedded in them. They depend on XAML serialization of some types which must be defined in C#, and so are kept separate from the more important commands for extracting packages (which do not require the binary assembly).


Installation
------------

The Installation submodule is the most important *part of the Packaging Module*, in a sense, it's the "*Packaging Lite*" module. It contains the commands for fetching modules from the internet and extracting them locally, as well as a light version of the Get-ModuleInfo command. This (***will soon***) includes the ability to fetch dependencies and check for updates.

The key feature of the Installation submodule is that it can be invoked as a script (using iex on it's contents) to install the main module, but can also serve itself as a light version of the Packaging module, suitable for end users that don't ever need to create packages, or that need to avoid creating the binary assemblies used by the main Packaging module.


Additional Modules
==================

There are actually a couple of sub-modules in this project which are fairly important, and which we hope will be generally useful for other module developers:

InvokeWeb
---------

The Invoke-Web command is a PowerShell 2 compatible advanced function which implements most of the functionality of Invoke-WebRequest, along with the ability to accept self-signed certificates as valid for ssl/tls connections, and some additional features.

It does not (yet) wrap the results in a container, and defaults to saving the output to file (which I happen to think of as a _feature_, rather than a missing feature).

Configuration
-------------

These commands could be useful for any module which needs to store key=value pairs on disk. The Get-ConfigData and Set-ConfigData commands allow you to read a simple key=value file just the way that ConvertFrom-StringData does, except they have a couple of very useful features: 

# There is no need to double-up on backslashes (\\)
# Windows Special Folders can be used by name in the values, like {MyDocuments}

The Get-SpecialFolder command allows you to get a hashtable of all the special folder names and values (so you can see what {tokens} are available), or to look up a specific special folder name to get the path.

The one thing that we **still want to do** for it is to add support for reading/writing from the user's AppData folder if the module is ReadOnly (i.e.: if you're not elevated, and the module is installed to a common location, the config should read the global location but overwrite those valuess with ones in the user's AddData folder).

