## Test Cases Needed:

# File System Install
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
Test "Install a module with dependencies from a url with dependency ReleaseUri set correctly (should download to same place and install)" { assert { throw "Test Not Written" }} -Category "Download"
Test "Install a module with dependencies from a url with dependencies that have unreachable ReleaseUri (should fail cleanly!)" { assert { throw "Test Not Written" }} -Category "Download"

