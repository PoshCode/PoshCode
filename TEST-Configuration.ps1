[CmdletBinding()]param()

Import-Module PSAINT # http://poshcode.org/Modules/PSAINT.psd1
Import-Module "$PSScriptRoot\Configuration.psm1" -Force -ErrorAction Stop

#     test "" {
#        arrange {
#
#        }
#        act {
#
#        }
#        assert {
#           Assert-That {  }
#        }
#     } -Category ExpandPackage


test "Convert Simple Hashtable to Metadata" {
   arrange {

      $table = @{ 
                  one = 'uno'; two = "dos"
                  three = 'three'
               }

      $truth = "@{",
               "  one = 'uno'",
               "  two = 'dos'",
               "  three = 'three'",
               "}"
   }
   act {
      $result = ConvertTo-Metadata $table
   }
   assert {
      # It's not that they can be in ANY order, but the values can be
      # This is just simpler than trying to sort only the hashtable content
      $truth = ($truth | sort ) -join "`n"
      $result = (($result -split "[\r\n]+") | sort ) -join "`n"

      $truth.MustEqual($result)
   }
} -Category Serialize


test "Arrays and Hashtables" {
   arrange {
      $table = @(
                  @{ 
                     one = "uno"; two = "dos"
                     three = @( 'wan', 'too', 'tres', 'quatro')
                     num = 1, 2, 3, 4 
                  }, "Porkay?"
               )
      $truth = "@(@{",
               "  one = 'uno'",
               "  two = 'dos'",
               "  three = @('wan','too','tres','quatro')",
               "  num = @(1,2,3,4)",
               "},'Porkay?')"
   }
   act {
      $result = ConvertTo-Metadata $table
   }
   assert {
      # It's not that they can be in ANY order, but the values can be
      # This is just simpler than trying to sort only the hashtable content
      $truth = ($truth | sort ) -join "`n"
      $result = (($result -split "[\r\n]+") | sort ) -join "`n"

      $truth.MustEqual($result)
   }
} -Category Serialize


test "Numbers And Deep Nesting" {
   arrange {
      $table = @{ 
                  russian = @{
                     nesting = @{
                        dolls = @{
                           are = @{
                              4 = 'quatro'
                              3 = 'tres'
                              2 = 'too'
                              1 = 'wan'
                           }
                        }
                     }
                  }
               }
      $truth = "@{`n" +
               "  russian = @{`n" +
               "    nesting = @{`n" +
               "      dolls = @{`n" +
               "        are = @{`n" +
               "          4 = 'quatro'`n" +
               "          3 = 'tres'`n" +
               "          2 = 'too'`n" +
               "          1 = 'wan'`n" +
               "        }`n" +
               "      }`n" +
               "    }`n" +
               "  }`n" +
               "}"
   }
   act {
      $result = ConvertTo-Metadata $table
   }
   assert {
      $truth.MustEqual($result)
   }
} -Category Serialize



test "Real Data Test: Curly braces " {
   arrange {
      $table = @{ 
                  InstallPaths = @{
                     CommonPath = "{ProgramFiles}\WindowsPowerShell\Modules"
                     UserPath = "{MyDocuments}\WindowsPowerShell\Modules"
                  }
                  Repositories = @{
                     FileSystem = "\\PoshCode.org\Modules"
                  }
               }
      $truth = "@{",
               "  InstallPaths = @{",
               "    CommonPath = '{ProgramFiles}\WindowsPowerShell\Modules'",
               "    UserPath = '{MyDocuments}\WindowsPowerShell\Modules'",
               "  }",
               "  Repositories = @{",
               "    FileSystem = '\\PoshCode.org\Modules'",
               "  }",
               "}"
   }
   act {
      $result = ConvertTo-Metadata $table
   }
   assert {
      # It's not that they can be in ANY order, but the values can be
      # This is just simpler than trying to sort only the hashtable content
      $truth = ($truth | sort ) -join "`n"
      $result = (($result -split "[\r\n]+") | sort ) -join "`n"

      $truth.MustEqual($result)
   }
} -Category Serialize

test "Custom Converters" {
   arrange {
      $CustomObject = New-Object PSObject -Property @{ FirstName = "Joel"; LastName = "Bennett"; Age = 39; }
      $Guid = [Guid]::NewGuid()
      $Now = Get-Date

      $table = @{
                  InstallPaths = @{
                     CommonPath = '{ProgramFiles}\WindowsPowerShell\Modules'
                     UserPath = '{MyDocuments}\WindowsPowerShell\Modules'
                  }
                  Repositories = @{
                     FileSystem = '\\PoshCode.org\Modules', 'P:\Modules'
                  }
                  Custom = $CustomObject
                  Guid = $Guid
                  Culture = $PSCulture
                  When = $Now
               }
      $truth = "@{",
               "  InstallPaths = @{",
               "    CommonPath = '{ProgramFiles}\WindowsPowerShell\Modules'",
               "    UserPath = '{MyDocuments}\WindowsPowerShell\Modules'",
               "  }",
               "  Repositories = @{",
               "    FileSystem = @('\\PoshCode.org\Modules','P:\Modules')",
               "  }",
               "  Custom = PSObject @{",
               "    FirstName = 'Joel'",
               "    LastName = 'Bennett'",
               "    Age = 39",
               "  }",
               "  Guid = Guid '$Guid'",
               "  Culture = '$PSCulture'",
               "  When = DateTime '$($Now.ToString('o'))'",
               "}"
   }
   act {
      $result = ConvertTo-Metadata $table
   }
   assert {
      # It's not that they can be in ANY order, but the values can be
      # This is just simpler than trying to sort only the hashtable content
      $truth = $truth
      $result = ($result -split "[\r\n]+")

      $truth = ($truth | sort) -join "`n"
      $result = ($result | sort) -join "`n"

      $truth.MustEqual($result)
   }
} -Category Serialize



test "Get Special Folder" {
   arrange {
      $FolderNames = [Environment+SpecialFolder].GetFields("Public,Static").Name | Sort
   }
   act {
      $truth = @{}
      foreach($name in $FolderNames) {
         $truth.$name = [Environment]::GetFolderPath($name)
      }
   }
   assert {
      foreach($name in $FolderNames) {
         if($truth.$name) {
            $truth.$name.MustEqual((Get-SpecialFolder $name -Value))
         } else {
            Assert-That { $null -eq (Get-SpecialFolder $name -Value) } -FailMessage "Get-SpecialFolder '$name' returned a value that's not in the Environment!"
         }
      }
   }
}