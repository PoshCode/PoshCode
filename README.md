PoshCode Package Manager Module (BETA)
================================

PoshCode's purpose is (and has always been) to make it easier to distribute modules (and scripts) over the internet or within local and corporate networks.  **With this new project we are focusing on making it easy to distribute modules without explaining module installation to your users.**  Additionally, we're supporting the automatic installation of dependencies, so that you can distribute modules which have a dependency on other modules without having to worry about how your users will find and install them.

The module has two main commands for users, and a third for module developers:

1. `Find-Module` searches various module registries and repositories
2. `Install-Module` installs modules from local packages or .zip files, or from URLs or UNC paths
3. `Compress-Module` create a redistributable module package from a module on your system

#### To install the PoshCode module, run one of these two command lines:

```posh

    # Install by downloading and executing the installer:
    iwr http://PoshCode.org/I -OutF PC.ps1; .\PC; rm .\PC.ps1

    # Install from WebDAV share:
    \\PoshCode.org\Modules\Install

```

The rest of the documentation has moved to the wiki, broken into several sections:

1. Installing Modules (user's guide)
2. Creating Module Packages 
3. Distributing Module Packages
4. Additional Features of PoshCode (catch all)

Note: the additional features of PoshCode includes coverages of some of the mini modules I wrote to support the Package Manager functionality, mostly around Serialization and Configuration.
