PoshCode Package Manager Module (BETA)
================================

PoshCode's purpose is to make it easier to distribute PowerShell modules and scripts over the internet or within local and corporate networks.  

**With this new project we are focusing on making it easy to distribute modules without explaining module installation to your users.**  

Additionally, we're supporting the automatic installation of dependencies, so that you can distribute modules which have a dependency on other modules without having to worry about how your users will find and install them.

The module has two main commands for users, and a third for module developers:

1. `Find-Module` searches configured module registries and repositories
2. `Install-Module` installs modules from local packages (.nupkg or .zip files), or from URLs or UNC paths
3. `Compress-Module` creates a redistributable module package from a module on your system

#### To install the PoshCode module

If your "WebClient" service is running (this is Window's built-in WebDAV client), you can install it straight from our server with a single command in any version of PowerShell:

```posh
    \\PoshCode.org\DavWWWRoot\Modules\Install.ps1
```

If you have problems with that (various things can make Windows WebDAV slow, and the service doesn't seem to be installed by default on server OSes), you will need to download and run our [Install.ps1](http://PoshCode.org/Modules/Install.ps1) script. Of course, you can still do that from PowerShell:

On PowerShell 3 and up you can do that using Invoke-WebRequest:
```posh
    # First download, then run, then delete the installer:
    iwr http://PoshCode.org/i -OutF PC.ps1; .\PC; rm .\PC.ps1
```

On PowerShell 2 you need to create and use a WebClient:
```posh
    (New-Object System.Net.WebClient).DownloadFile("http://poshcode.org/i","$pwd\pc.ps1"); .\PC; rm .\PC.ps1
```

The rest of the documentation will be in the wiki, broken into several sections:

1. Installing Modules (user's guide)
2. Creating Module Packages 
3. Distributing Module Packages (should include the "how to" for enterprise users)
5. Additional Features of PoshCode (everything else)

Note: the additional features of PoshCode include coverages of some of the mini modules I wrote to support the Package Manager functionality, mostly around Serialization and Configuration.
