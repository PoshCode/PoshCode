# File System Install
Test "When the Packaging module is your first module" {
  ## You'll have a PSModulePath with just two folders, and the default one won't exist (choose the default)

  assert { throw "Test not Written"}
} -Category "Clean","CreateDirectory"


Test "Install a new module with no dependencies from a file (clean install)" { assert { throw "Test Not Written" }} -Category "FileSystem"
Test "Install an upgrade module from a file (should overwrite module files but not delete ini files)" { assert { throw "Test Not Written" }} -Category "FileSystem"
Test "Install an downgrade module from a file (should delete all files first)" { assert { throw "Test Not Written" }} -Category "FileSystem"
Test "Install a module with existing dependencies (requires modules that are already installed -- shouldn't try to reinstall)" { assert { throw "Test Not Written" }} -Category "FileSystem"
Test "Install a module with dependencies from a file, with dependency package available in the same folder" { assert { throw "Test Not Written" }} -Category "FileSystem"
Test "Install a module with dependencies on a never version of an installed module, with dependency package available in the same folder" { assert { throw "Test Not Written" }} -Category "FileSystem"

# URL install
Test "Install a module with no dependencies from a url" { assert { throw "Test Not Written" }} -Category "Download"
Test "Install an upgrade module from a url (should overwrite module files but not delete ini files)" { assert { throw "Test Not Written" }} -Category "Download"
Test "Install an downgrade module from a url (should delete all files first)" { assert { throw "Test Not Written" }} -Category "Download"
Test "Install a module with dependencies from a url with dependency package is available in the install folder" { assert { throw "Test Not Written" }} -Category "Download"
Test "Install a module with dependencies from a url with dependency ModuleInfoUri set correctly (should download to same place and install)" { assert { throw "Test Not Written" }} -Category "Download"
Test "Install a module with dependencies from a url with dependencies that have unreachable ModuleInfoUri (should fail cleanly!)" { assert { throw "Test Not Written" }} -Category "Download"

# Get Module Info
Test "Validate the error message when getting module info from a module with no .psd1" { assert { throw "Test Not Written" } -Category "ModuleInfo"
Test "Get Module Info from an installed module with just .psd1" { assert { throw "Test Not Written" } -Category "ModuleInfo"
Test "Get Module Info from an installed module with a .moduleinfo" { assert { throw "Test Not Written" } -Category "ModuleInfo"
Test "Get Module Info from a local .psmx package file." { assert { throw "Test Not Written" } -Category "ModuleInfo"
Test "Get Module Info from a remote (UNC) package file." { assert { throw "Test Not Written" } -Category "ModuleInfo"
Test "Get Module Info from a remote (http) package file." { assert { throw "Test Not Written" } -Category "ModuleInfo"

# Update Module Info
Test "Update Module Info when there are new things in the .psd1" { assert { throw "Test Not Written" } -Category "UpdateModuleInfo","ModuleInfo"
Test "Update Module Info when there are things removed from the .psd1 (not supported yet)" { assert { throw "Test Not Written" } -Category "UpdateModuleInfo","ModuleInfo"
Test "Update Module Info when the .moduleinfo file hasn't been created yet" { assert { throw "Test Not Written" } -Category "UpdateModuleInfo","ModuleInfo"
Test "Update Module Info with various parameters" { assert { throw "Test Not Written" } -Category "UpdateModuleInfo","ModuleInfo"
