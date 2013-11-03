####################################################################################################
## Script Name:     PoshCode Module
## Created On:      
## Author:          Joel 'Jaykul' Bennett
## File:            PoshCode.psm1
## Usage:          
## Version:         4.0
## Purpose:         Provides cmdlets for working with scripts from the PoshCode Repository:
##                  Get-PoshCodeUpgrade - get the latest version of this script from the PoshCode server
##                  Get-PoshCode        - Search for and download code snippets
##                  Send-PoshCode        - Upload new code snippets
##                  Get-WebFile         - Download
## ################ ################################################################################
## Requirements:    PowerShell Version 2
## Last Updated:    03/04/2011
## History:
##                  4.00 2013-08-05 - Rename to "Scripts" and put it in the new "PoshCode" multi-module.
##                                  - Remove the Get-PoshCodeUpgrade command (will use the new PoshCode\Install)
##                                  - Remove the Block/Unblock feature (it's just pointless and a little annoying)
##                                  - Remove the Get-WebFile (depend on Invoke-Web or the version from PoshCode\Install)
##                  3.15 2012-07-13 - Fixed the System.Security.SecurityZone cast on line 311
##                  3.14 2011-03-04 - Fixed PowerShell 3.0 Regression :-P
##                  3.13 2010-08-04 - Fixed proxy credentials for download (oops)
##                                  - Fixed WebException handling (e.g.: 404 errors) on Get-WebFile (only report one error, and make it nicer)
##                                  - Fixed test for $filename so it doesn't throw if $filename is empty
##                  3.12 2010-07-14 - Complete help documentation for the last two public functions.
##                  3.11 2010-06-08 - Add code for proxy credentials at Kirk Munro's suggestion.
##                  3.10 2009-11-08 - Fix a typo bug in Get-PoshCode
##                  3.9  2009-10-02 - Put back the fixed NTFS Streams
##                  3.8  2009-08-04 - Fixed PoshCodeUpgrade for CTP3+ and added secondary cert
##                  3.7  2009-07-29 - Remove NTFS Streams 
##                  3.6  2009-05-04 - Documentation Rewrite
##                       
####################################################################################################
#requires -version 2.0
Set-StrictMode -Version Latest

$PoshCode = "http://PoshCode.org/" | Add-Member -type NoteProperty -Name "ApiVersion" -Value 1 -Passthru

function Send-PoshCode {
  <#
  .SYNOPSIS
  	Uploads a script to PoshCode
  .DESCRIPTION
  	Uploads code to the PowerShell Script Repository and returns the url for you.
  .LINK
  	http://www.poshcode.org
  .EXAMPLE
  	C:\PS>Get-Content MyScript.ps1 | Send-PoshCode "An example for you" "This is just to show how to do it"
  	
  	This command gets the content of MyScript.ps1 and passes it to Send-PoshCode which then posts it to poshcode.org with the specified title and description.
  .PARAMETER Path
  	Specifies the path to an item.
  .PARAMETER Description
  	Sets the free-text summary of the script that will be displayed on the poshcode page for the script. 
  .PARAMETER Author
  	Specifies the author of the script that is being submitted.
  .PARAMETER Language
  	Specifies the language of the script that is being submitted.
  .PARAMETER Keep
  	Specifies how long to keep scripts on the poshcode.org site. Possible values are 'day', 'month', or 'forever'.
  .PARAMETER Title
  	Specifies the title of the script that is being submitted. 
  .PARAMETER URL
  	Overrides the default PoshCode url, to allow posting to other Pastebin sites.
  .NOTES
   	History:
      v 4.0 - Renamed to Send-PoshCode
  		v 3.1 - Fixed the $URL parameter so that it's settable again. *This* function should work on any pastebin site
  		v 3.0 - Renamed to New-PoshCode.  
      			-	Removed the -Permanent switch, since this is now exclusive to the permanent repository
  		v 2.1 - Changed some defaults
      		  - Added "PermanentPosh" switch ( -P ) to switch the upload to the PowerShellCentral repository
  		v 2.0 - works with "pastebin" (including posh.jaykul.com/p/ and PowerShellCentral.com/scripts/)
   		v 1.0 - Worked with a special pastebin
  #>
  [CmdletBinding()]
  PARAM(
     [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
     [Alias("FullName")]
     [string]$Path
  ,
     [Parameter(Position=5, Mandatory=$true)]
     [string]$Description
  , 
     [Parameter(Mandatory=$true, Position=10)]
     [string]$Author
  , 
     [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
     [Alias("BaseName","Name")]
     [string]$Title
  , 
     [Parameter(Position=15)]
     [PoshCodeLanguage]$Language="posh"
  , 
     [Parameter(Position=20, Mandatory=$false)]
     [ValidateScript({ if($_ -match "^[dmf]") { return $true } else { throw "Please specify 'day', 'month', or 'forever'" } })]
     [string]$Keep="f"
  ,
     [Parameter()]
     [int]$Parent = 0
  ,
     [Parameter(Mandatory=$false)]
     [string]$url= $($PoshCode)
  )
     
  BEGIN {
     $null = [Reflection.Assembly]::LoadWithPartialName("System.Web")
     [string]$data = ""
     [string]$meta = ""
     
     if($language) {
        $meta = "format=" + [System.Web.HttpUtility]::UrlEncode($language)
        # $url = $url + "?" +$lang
     } else {
        $meta = "format=text"
     }
     
     if($Parent) {
        $meta = $meta + "&parent_pid=$Parent"
     }


     # Note how simplified this is by 
     switch -regex ($Keep) {
        "^d" { $meta += "&expiry=d" }
        "^m" { $meta += "&expiry=m" }
        "^f" { $meta += "&expiry=f" }
     }
   
     if($Description) {
        $meta += "&descrip=" + [System.Web.HttpUtility]::UrlEncode($Description)
     } else {
        $meta += "&descrip="
     }   
     $meta += "&poster=" + [System.Web.HttpUtility]::UrlEncode($Author)
     
     function Send-PoshCode ($meta, $title, $data, $url= $($PoshCode)) {
        $meta += "&paste=Send&posttitle=" + [System.Web.HttpUtility]::UrlEncode($Title)
        $data = $meta + "&code2=" + [System.Web.HttpUtility]::UrlEncode($data)
       
        $request = [System.Net.WebRequest]::Create($url)
        $request.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        if ($request.Proxy -ne $null) {
           $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        }
        $request.ContentType = "application/x-www-form-urlencoded"
        $request.ContentLength = $data.Length
        $request.Method = "POST"
   
        $post = new-object IO.StreamWriter $request.GetRequestStream()
        $post.Write($data)
        $post.Flush()
        $post.Close()
   
        # $reader = new-object IO.StreamReader $request.GetResponse().GetResponseStream() ##,[Text.Encoding]::UTF8
        # write-output $reader.ReadToEnd()
        # $reader.Close()
        write-output $request.GetResponse().ResponseUri.AbsoluteUri
        $request.Abort()
     }
  }
  PROCESS {
     $EAP = $ErrorActionPreference
     $ErrorActionPreference = "SilentlyContinue"
     if(Test-Path $Path -PathType Leaf) {
        $ErrorActionPreference = $EAP
        Write-Verbose $Path
        Write-Output $(Send-PoshCode $meta $Title $([string]::join("`n",(Get-Content $Path))) $url)
     } elseif(Test-Path $Path -PathType Container) {
        $ErrorActionPreference = $EAP
        Write-Error "Can't upload folders yet: $Path"
     } else { ## Todo, handle folders?
        $ErrorActionPreference = $EAP
        if(!$data -and !$Title){
           $Title = Read-Host "Give us a title for your post"
        }
        $data += "`n" + $Path
     }
  }
  END {
     if($data) { 
        Write-Output $(Send-PoshCode $meta $Title $data $url)
     }
  }
}

function Get-PoshCode {
  <#
  .SYNOPSIS
     Search for and/or download scripts from PoshCode.org
  .DESCRIPTION	
  	Search PoshCode.org by search terms, and returns a list of results, Or download a specific script by ID and output the contents or save to file.
  .LINK
  	http://www.poshcode.org
  .EXAMPLE
  	C:\PS>Get-PoshCode Authenticode 
         This command searches the repository for scripts dealing with Authenticode, and list the results
         Normally, you will take one of those IDs and do this:
  .EXAMPLE
  	C:\PS>Get-PoshCode 456
         This command will download the script with the ID of 456 and save it to file (based on it's name/contents)
  .EXAMPLE
  	C:\PS>Get-PoshCode 456 -passthru 
         Thi command outputs the contents of that script into the pipeline, so eg:
         (Get-PoshCode 456 -passthru) -replace "AuthenticodeSignature","SillySig"
  .EXAMPLE
  	C:\PS>Get-PoshCode 456 $ProfileDir\Authenticode.psm1
         This command downloads the script saving it as the name specified.
  .EXAMPLE
  	C:\PS>Get-PoshCode SCOM | Get-PoshCode
         This command searches the repository for all scripts about SCOM, and then downloads them!
  .PARAMETER Path
  	Specifies the path to an item.
  .PARAMETER Description
  	Sets the free-text summary of the script that will be displayed on the poshcode page for the script. 
  .PARAMETER Author
  	Specifies the author of the script that is being submitted.
  .PARAMETER Language
  	Specifies the language of the script that is being submitted.
  .PARAMETER Keep
  	Specifies how long to keep scripts on the poshcode.org site. Possible values are 'day', 'month', or 'forever'.
  .PARAMETER Title
  	Specifies the title of the script that is being submitted. 
  .PARAMETER URL
  .NOTES
  	All search terms are automatically surrounded with wildcards.
   	History:
     v 4.0  - Moved into the new PoshCode Packaging Module
  	 v 3.10 - Fixed a typo
  	 v 3.4  - Add "-Language" parameter to force PowerShell only, fix upgrade to leave INVALID as .psm1
  	 v 3.2  - Add "-Upgrade" switch to cause the script to upgrade itself.
  	 v 3.1  - Add "Huddled.PoshCode.ScriptInfo" to TypeInfo, so it can be formatted by a ps1xml
    	        - Add ConvertTo-Module function to try to rename .ps1 scripts to .psm1 
  	        - Fixed exceptions thrown by searches which return no results
  	        - Removed the auto-wildcards!!!!
  	           NOTE: to get the same results as before you must now put * on the front and end of searches
  	           This is so that searches on the website work the same as searches here...
  	           My intention is to improve the website's search instead of leaving this here.
  	           NOTE: the website currently will not search for words less than 4 characters long
  	 v 3.0  - Working against the new RSS-based API
  	        - And using ParameterSets, which work in CTP2
      v 2.0  - Combined with Find-Poshcode into a single script
      v 1.0  - Working against our special pastebin
           
  #>
  [CmdletBinding(DefaultParameterSetName="Download")]
  PARAM(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Search")]
        [string]$Query
  ,
        [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="Download" )]
        [int]$Id
  ,
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Upgrade")]
        [switch]$Upgrade
  ,
        [Parameter(Position=1, Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [Alias("FullName","Title")]
        [string]$SaveAs
  ,
        [Parameter(Position=2, Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('text','asp','bash','cpp','csharp','posh','vbnet','xml','all')]
        [string]$Language="posh"
  ,
        [switch]$InBrowser
  ,
        [Parameter(Mandatory=$false)][string]$url= $($PoshCode)
     )
  PROCESS {
     Write-Debug "ParameterSet Name: $($PSCmdlet.ParameterSetName)"
     if($Language -eq 'all') { $Language = "" }
     switch($PSCmdlet.ParameterSetName) {
        "Search" {
           $results = @(([xml](Invoke-WebRequest "$($url)api$($PoshCode.ApiVersion)/$($query)&lang=$($Language)").Content).rss.channel.GetElementsByTagName("item"))
           if($results.Count -eq 0 ) {
              Write-Host "Zero Results for '$query'" -Fore Red -Back Black
           } 
           else {
              $results | Select @{ n="Id";e={$($_.link -replace $url,'') -as [int]}},
                  @{n="Title";e={$_.title}},
                  @{n="Author";e={$_.creator}},
                  @{n="Date";e={$_.pubDate }},
                  @{n="Link";e={$_.guid.get_InnerText() }},
                  @{n="Web";e={$_.Link}},
                  @{n="Description";e={"$($_.description.get_InnerText())`n" }} |
              ForEach { $_.PSObject.TypeNames.Insert( 0, "Huddled.PoshCode.ScriptInfo" ); $_ }
           }
        }
        "Download" {
           if(!$InBrowser) {
              if($SaveAs) {
                if(![IO.Path]::HasExtension($SaveAs)) {
                  $SaveAs = "${SaveAs}.ps1"
                }

                $ScriptFile = Invoke-WebRequest "$($url)?dl=$id" -OutFile $SaveAs -ErrorVariable FourOhFour
                if($FourOhFour){
                  $PSCmdlet.ThrowTerminatingError( $FourOhFour[0] )
                }
                # If we used the built-in Invoke-WebRequest, we don't have the file yet...
                $(if($ScriptFile -isnot [System.IO.FileInfo]) { Get-ChildItem $SaveAs }) | ConvertTo-Module
              } 
              else {
                $ScriptFile = Invoke-WebRequest "$($url)?dl=$id" -OutFile "${id}.ps1" -ErrorVariable FourOhFour
                if($FourOhFour){
                  $PSCmdlet.ThrowTerminatingError( $FourOhFour[0] )
                }
                # If we used the built-in Invoke-WebRequest, we don't have the file yet...
                $(if($ScriptFile -isnot [System.IO.FileInfo]) { Get-ChildItem "${id}.ps1" }) | ConvertTo-Module
              }
           } 
           else {
              [Diagnostics.Process]::Start( "$($url)$id" )
           }
        }
        "Upgrade" { 
           Get-PoshCodeUpgrade
        }
     }
  }
}

## Test-Signature - Returns true if the signature is valid OR is signed by:
## "4F8842037D878C1FCDC6FD1313B200449716C353" OR "7DEFA3C6C2138C05AAA135FB8096332DEB9603E1"
function Test-Signature {
  [CmdletBinding(DefaultParameterSetName="File")]
  PARAM (
     [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Signature")]
     #  We can't actually require the type, or we won't be able to check the fake ones from Joel's Authenticode module
     #  [System.Management.Automation.Signature]
     $Signature
  ,  [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="File")]
     [System.IO.FileInfo]
     $File
  )
  PROCESS {
     if($File -and (Test-Path $File -PathType Leaf)) {
        $Signature = Get-AuthenticodeSignature $File
     }
     if(!$Signature) { return $false } else {
        $result = $false;
        try {
           $result = ((($Signature.Status -eq "UnknownError") -and $Signature.SignerCertificate -and
                                            (($Signature.SignerCertificate.Thumbprint -eq "4F8842037D878C1FCDC6FD1313B200449716C353") -or
                       ($Signature.SignerCertificate.Thumbprint -eq "7DEFA3C6C2138C05AAA135FB8096332DEB9603E1"))
                      ) -or $Signature.Status -eq "Valid" )
        } catch { }
  	  return $result
     }
  }
}

filter ConvertTo-Module {
   $oldFile  = $_
   if( ([IO.Path]::GetExtension($oldFile) -eq ".ps1") -and 
         [Regex]::Match( [IO.File]::ReadAllText($oldFile), 
              "^[^#]*Export-ModuleMember.*", "MultiLine").Success )
   { 
      $fileName = [IO.Path]::ChangeExtension($oldFile, ".psm1")
      Move-Item $oldFile $fileName -Force
      Get-Item $fileName
   } else { Get-Item $oldFile } 
}

Set-Alias Search-PoshCode Get-PoshCode
Set-Alias New-PoshCode Send-PoshCode

Export-ModuleMember Get-PoshCode, Send-PoshCode -alias Search-PoshCode, New-PoshCode


# SIG # Begin signature block
# MIIarwYJKoZIhvcNAQcCoIIaoDCCGpwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbpyUqr3M15CYJ+42jxC8e8h3
# RM+gghXlMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggahMIIFiaADAgECAhADS1DyPKUAAEvdY0qN2NEFMA0GCSqGSIb3DQEBBQUAMG8x
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBLTEwHhcNMTMwMzE5MDAwMDAwWhcNMTQwNDAxMTIwMDAwWjBt
# MQswCQYDVQQGEwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3Qg
# SGVucmlldHRhMRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pv
# ZWwgSC4gQmVubmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMPj
# sSDplpNPrcGhb5o977Z7VdTm/BdBokBbRRD5hGF+E7bnIOEK2FTB9Wypgp+9udd7
# 6nMgvZpj4gtO6Yj+noUcK9SPDMWgVOvvOe5JKKJArRvR5pDuHKFa+W2zijEWUjo5
# DcqU2PGDralKrBZVfOonity/ZHMUpieezhqy98wcK1PqDs0Cm4IeRDcbNwF5vU1T
# OAwzFoETFzPGX8n37INVIsV5cFJ1uGFncvRbAHVbwaoR1et0o01Jsb5vYUmAhb+n
# qL/IA/wOhU8+LGLhlI2QL5USxnLwxt64Q9ZgO5vu2C2TxWEwnuLz24SAhHl+OYom
# tQ8qQDJQcfh5cGOHlCsCAwEAAaOCAzkwggM1MB8GA1UdIwQYMBaAFHtozimqwBe+
# SXrh5T/Wp/dFjzUyMB0GA1UdDgQWBBRfhbxO+IGnJ/yiJPFIKOAXo+DUWTAOBgNV
# HQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwcwYDVR0fBGwwajAzoDGg
# L4YtaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL2Fzc3VyZWQtY3MtMjAxMWEuY3Js
# MDOgMaAvhi1odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vYXNzdXJlZC1jcy0yMDEx
# YS5jcmwwggHEBgNVHSAEggG7MIIBtzCCAbMGCWCGSAGG/WwDATCCAaQwOgYIKwYB
# BQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9y
# eS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYA
# IAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkA
# dAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAA
# RABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAA
# UgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAA
# dwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4A
# ZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkA
# bgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wgYIGCCsGAQUFBwEBBHYwdDAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEwGCCsGAQUFBzAC
# hkBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURD
# b2RlU2lnbmluZ0NBLTEuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEFBQAD
# ggEBABv8O1PicJ3pbsLtls/jzFKZIG16h2j0eXdsJrGZzx6pBVnXnqvL4ZrF6dgv
# puQWr+lg6wL+Nxi9kJMeNkMBpmaXQtZWuj6lVx23o4k3MQL5/Kn3bcJGpdXNSEHS
# xRkGFyBopLhH2We/0ic30+oja5hCh6Xko9iJBOZodIqe9nITxBjPrKXGUcV4idWj
# +ZJtkOXHZ4ucQ99f7aaM3so30IdbIq/1+jVSkFuCp32fisUOIHiHbl3nR8j20YOw
# ulNn8czlDjdw1Zp/U1kNF2mtZ9xMYI8yOIc2xvrOQQKLYecricrgSMomX54pG6uS
# x5/fRyurC3unlwTqbYqAMQMlhP8wggajMIIFi6ADAgECAhAPqEkGFdcAoL4hdv3F
# 7G29MA0GCSqGSIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0Rp
# Z2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMTAyMTExMjAwMDBaFw0yNjAy
# MTAxMjAwMDBaMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCcfPmgjwrKiUtTmjzsGSJ/DMv3SETQPyJumk/6zt/G0ySR/6hS
# k+dy+PFGhpTFqxf0eH/Ler6QJhx8Uy/lg+e7agUozKAXEUsYIPO3vfLcy7iGQEUf
# T/k5mNM7629ppFwBLrFm6aa43Abero1i/kQngqkDw/7mJguTSXHlOG1O/oBcZ3e1
# 1W9mZJRru4hJaNjR9H4hwebFHsnglrgJlflLnq7MMb1qWkKnxAVHfWAr2aFdvftW
# k+8b/HL53z4y/d0qLDJG2l5jvNC4y0wQNfxQX6xDRHz+hERQtIwqPXQM9HqLckvg
# VrUTtmPpP05JI+cGFvAlqwH4KEHmx9RkO12rAgMBAAGjggNDMIIDPzAOBgNVHQ8B
# Af8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwggHDBgNVHSAEggG6MIIBtjCC
# AbIGCGCGSAGG/WwDMIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2Vy
# dC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6C
# AVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBp
# AGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABh
# AG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBD
# AFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5
# ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABs
# AGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABv
# AHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBj
# AGUALjASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsNC5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMB0GA1UdDgQW
# BBR7aM4pqsAXvkl64eU/1qf3RY81MjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYun
# pyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAe3IdZP+IyDrBt+nnqcSHu9uUkteQ
# WTP6K4feqFuAJT8Tj5uDG3xDxOaM3zk+wxXssNo7ISV7JMFyXbhHkYETRvqcP2pR
# ON60Jcvwq9/FKAFUeRBGJNE4DyahYZBNur0o5j/xxKqb9to1U0/J8j3TbNwj7aqg
# TWcJ8zqAPTz7NkyQ53ak3fI6v1Y1L6JMZejg1NrRx8iRai0jTzc7GZQY1NWcEDzV
# sRwZ/4/Ia5ue+K6cmZZ40c2cURVbQiZyWo0KSiOSQOiG3iLCkzrUm2im3yl/Brk8
# Dr2fxIacgkdCcTKGCZlyCXlLnXFp9UH/fzl3ZPGEjb6LHrJ9aKOlkLEM/zGCBDQw
# ggQwAgEBMIGDMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTECEANLUPI8pQAAS91jSo3Y0QUwCQYF
# Kw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkD
# MQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJ
# KoZIhvcNAQkEMRYEFETtQXFWXS1PfQJxVc6FnziSXUn+MA0GCSqGSIb3DQEBAQUA
# BIIBAGSklybPU+A0F0rmQYfdDq4B4V8jBHmm85PmLKqCOyfKwWcpiobWcLJdiTWG
# +PLOBL1ex3Nec2VhK0Lb2tI8cvRx4PpnCz67zI0LhN43xCRuXzcNkiO9SEKdKdN0
# yjvj9EZPmaZeDEKJWfNP5ByakoGDQqUuRqqDm0kOCqv0U02JD9DoUClp/FqM/qmo
# XLJOmcDytmin5VP1BSuZFXtACmgNiKSzccRTWbJhzvUIaNyfA2E9ZEsa1jaQ921t
# SLPNXSA7yFVF314/LWis1sLNCiWo+tHGtqdogjnn2B3ry2i/i65cQwUsbI06oGDF
# C+4t+k5booa9JUpwRZeiPgN7O8ChggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQC
# AQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0Eg
# LSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMxMTAyMTkyMjUxWjAjBgkq
# hkiG9w0BCQQxFgQUIVWLt7fJP+9iUhHAK5OvA9vpxyMwDQYJKoZIhvcNAQEBBQAE
# ggEAClX2pZr9nVWUSXttjbLiodijPgPNu+vUtC0E6Aittk8wywja4+DOWx+cXa0b
# xgsJl/AlCBQGXRlDxPO6bx6m3je7sXel+7fRb5GPAoZSBkCVtA93grtxco4rqkx4
# mn7uF+e7OqowcyvNBql6ZFVAx+cnBGFLFQ3BV9EYwnSIX6VoqbmF0sZORu4n4+2c
# 6XMmPbyyA/coacqlNrkaSAEjb1+TdiBItEHcQP3XExpnGUaN7P9kwUXvEb41MYip
# fBzyabRRfCHX94Fv1mIDx0/UmM7Zg3XwMJ0g+CZhX8q3Vs7+AjYc8WMBV6egMCB5
# EBiVqUxPl1tQ+AG6XJ9OEkOTfw==
# SIG # End signature block
