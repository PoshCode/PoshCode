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
           $results = @(([xml](Invoke-WebRequest "$($url)api$($PoshCode.ApiVersion)/$($query)&lang=$($Language)")).rss.channel.GetElementsByTagName("item"))
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

