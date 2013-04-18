########################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
########################################################################

function ConvertTo-Dictionary {
  #.Synopsis
  #   Convert a Hashtable or NameObjectCollection to a strongly typed generic dictionary
  param(
    # The Hashtable to be converted
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ParameterSetName="Hashtable")]
    [Hashtable[]]$Hashtable,

    # The NameObjectCollection to be converted
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName="WebHeaders")]
    [System.Collections.Specialized.NameObjectCollectionBase]$Headers,

    # The type for the key of the output dictionary
    [Parameter(Mandatory=$true,ParameterSetName="Hashtable")]
    [Type]$TKey,

    # The type for the value of the output dictionary
    [Parameter(Mandatory=$true,ParameterSetName="Hashtable")]
    [Type]$Tvalue
  )
  begin {
    switch($PSCmdlet.ParameterSetName) {
      "Hashtable" {
        $dictionary = New-Object "System.Collections.Generic.Dictionary[[$($TKey.FullName)],[$($TValue.FullName)]]" 
      }
      "WebHeaders" {
        $dictionary = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
      }
    }
  }
  process { 
    switch($PSCmdlet.ParameterSetName) {
      "Hashtable" {
        foreach($ht in $Hashtable) { 
          foreach($key in $ht.Keys) { 
            $dictionary.Add( $key, $ht.$key ) 
          }
        }
      }
      "WebHeaders" {
        foreach($key in $Headers.AllKeys) {
          $dictionary.Add($key, $Headers[$key])
        }
      }
    }
  }
  end { return $dictionary }
}

function ConvertFrom-Dictionary {
  #.Synopsis
  #   Convert a string dictionary to a key = value strings, optionally UrlEncoding the values.
  [CmdletBinding()]
  param(
    # The dictionary to convert (values should be strings or castable to strings)
    $Dictionary, 
    
    # If set, UrlEncode the values    
    [Switch]$Encode
  )
  foreach($key in $Dictionary.Keys) {
    "{0} = {1}" -f $key, $( if($Encode) { [System.Net.WebUtility]::UrlEncode( $Dictionary.$key ) } else { $Dictionary.$key } )
  }
}

## Get-WebFile (aka wget for PowerShell)
function Invoke-Web {
  <#
    .Synopsis
      Downloads a file or page from the web, or sends web API posts/requests
    .Description
      Creates an HttpWebRequest to download a web file or post data
    .Example
      Invoke-Web http://PoshCode.org/PoshCode.psm1
    
      Downloads the latest version of the PoshCode module to the current directory
    .Example
      Invoke-Web http://PoshCode.org/PoshCode.psm1 ~\Documents\WindowsPowerShell\Modules\PoshCode\
    
      Downloads the latest version of the PoshCode module to the default PoshCode module directory...
    .Example
      $RssItems = @(([xml](Invoke-Web http://poshcode.org/api/ -passthru)).rss.channel.GetElementsByTagName("item"))
    
      Returns the most recent items from the PoshCode.org RSS feed
    .Notes
      History:
      v4.2  - Fixed bugs when sending content in the body.
      v4.1  - Reworked most of it with PowerShell 3's Invoke-WebRequest as inspiration
            - Added a bunch of parameters, the ability to do PUTs etc., and session/cookie persistence
            - Did NOT parse the return code and get you the FORMs the way PowerShell 3 does -- upgrade! ;)
      v3.12 - Added full help
      v3.9 - Fixed and replaced the Set-DownloadFlag
      v3.7 - Removed the Set-DownloadFlag code because it was throwing on Windows 7:
             "Attempted to read or write protected memory."
      v3.6.6 Add UserAgent calculation and parameter
      v3.6.5 Add file-name guessing and cleanup
      v3.6 - Add -Passthru switch to output TEXT files 
      v3.5 - Add -Quiet switch to turn off the progress reports ...
      v3.4 - Add progress report for files which don't report size
      v3.3 - Add progress report for files which report their size
      v3.2 - Use the pure Stream object because StreamWriter is based on TextWriter:
             it was messing up binary files, and making mistakes with extended characters in text
      v3.1 - Unwrap the filename when it has quotes around it
      v3   - rewritten completely using HttpWebRequest + HttpWebResponse to figure out the file name, if possible
      v2   - adds a ton of parsing to make the output pretty
             added measuring the scripts involved in the command, (uses Tokenizer)
  #>
  [CmdletBinding(DefaultParameterSetName="NoSession")]
  param(
      #  The URL of the file/page to download
      [Parameter(Mandatory=$true,Position=0)]
      [System.Uri][Alias("Url")]$Uri, # = (Read-Host "The URL to download")
   
      #  Specifies the body of the request. The body is the content of the request that follows the headers.
      #  You can also pipe a request body to Invoke-WebRequest 
      #  Note that you should probably set the ContentType if you're setting the Body
      [Parameter(ValueFromPipeline=$true)]
      $Body,

      # Specifies the content type of the web request, such as "application/x-www-form-urlencoded" (defaults to "application/x-www-form-urlencoded" if the Body is set to a hashtable, dictionary, or other NameValueCollection)
      [String]$ContentType,

      #  Specifies the client certificate that is used for a secure web request. Enter a variable that contains a certificate or a command or expression that gets the certificate.
      #  To find a certificate, use Get-PfxCertificate or use the Get-ChildItem cmdlet in the Certificate (Cert:) drive. If the certificate is not valid or does not have sufficient authority, the command fails.
      [System.Security.Cryptography.X509Certificates.X509Certificate[]]
      $Certificate,

      #  Sends the results to the specified output file. Enter a path and file name. If you omit the path, the default is the current location.
      #  By default, Invoke-WebRequest returns the results to the pipeline. To send the results to a file and to the pipeline, use the Passthru parameter.
      [Parameter(Position=1)]
      [Alias("OutFile")]
      [string]$OutPath,

      #  Leave the file unblocked instead of blocked
      [Switch]$Unblocked,

      #  Rather than saving the downloaded content to a file, output it.  
      #  This is for text documents like web pages and rss feeds, and allows you to avoid temporarily caching the text in a file.
      [switch]$Passthru,

      #  Supresses the Write-Progress during download
      [switch]$Quiet,

      # Specifies a name for the session variable. Enter a variable name without the dollar sign ($) symbol.
      # When you use the session variable in a web request, the variable is populated with a WebRequestSession object.
      # You cannot use the SessionVariable and WebSession parameters in the same command
      [Parameter(Mandatory=$true,ParameterSetName="CreateSession")]
      [String]$SessionVariable,

      # Specifies a web request session to store data for subsequent requests.
      # You cannot use the SessionVariable and WebSession parameters in the same command
      [Parameter(Mandatory=$true,ParameterSetName="UseSession")]
      $WebSession,

      #  Pass the default credentials
      [switch]$UseDefaultCredentials,

      #  Specifies a user account that has permission to send the request. The default is the current user.
      #  Type a user name, such as "User01" or "Domain01\User01", or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
      [System.Management.Automation.PSCredential]
      [System.Management.Automation.Credential()]
      [Alias("")]$Credential = [System.Management.Automation.PSCredential]::Empty,

      # Specifies that Authorization: Basic should always be sent. Requires $Credential to be set, and should only be used with https
      [ValidateScript({if(!($Credential -or $WebSession)){ throw "ForceBasicAuth requires the Credential parameter be set"} else { $true }})]
      $ForceBasicAuth,

      # Sets the KeepAlive value in the HTTP header to False. By default, KeepAlive is True. KeepAlive establishes a persistent connection to the server to facilitate subsequent requests.
      $DisableKeepAlive,

      # Specifies the headers for the web request. Enter a hash table or dictionary.
      [System.Collections.IDictionary]$Headers,

      # Determines how many times Windows PowerShell redirects a connection to an alternate Uniform Resource Identifier (URI) before the connection fails. 
      # Our default value is 5 (but .Net's default is 50). A value of 0 (zero) prevents all redirection.
      [int]$MaximumRedirection = 5,

      # Specifies the method used for the web request. Valid values are Default, Delete, Get, Head, Options, Post, Put, and Trace. Default value is Get.
      [ValidateSet("Default", "Delete", "Get", "Head", "Options", "Post", "Put", "Trace")]
      [String]$Method = "Get",

      # Specifies a ScriptBlock which will be passed the response when requests are successful.
      #
      # This ScriptBlock can, among other things, redefine the $OutFile and $Passthru parameters, and prepend to the $output stream.
      [ScriptBlock]$ResponseHandler,

      # Uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
      # Note: if you have a default proxy configured in your internet settings, there is no need to set it here.
      [Uri]$Proxy,

      #  Pass the default credentials to the Proxy
      [switch]$ProxyUseDefaultCredentials,

      #  Pass specific credentials to the Proxy
      [System.Management.Automation.PSCredential]
      [System.Management.Automation.Credential()]
      $ProxyCredential= [System.Management.Automation.PSCredential]::Empty,

      #  Text to include at the front of the UserAgent string
      [string]$UserAgent = "Mozilla/5.0 (Windows NT; Windows NT $([Environment]::OSVersion.Version.ToString(2)); $PSUICulture) WindowsPowerShell/$($PSVersionTable.PSVersion.ToString(2)); PoshCode/4.0; http://PoshCode.org"     
  )

  process {
    $EAP,$ErrorActionPreference = $ErrorActionPreference, "Stop"
    $request = [System.Net.HttpWebRequest]::Create($Uri)
    if($DebugPreference -ne "SilentlyContinue") {
      Set-Variable WebRequest -Scope 2 -Value $request
    }

    $ErrorActionPreference = $EAP
    # Not everything is a GET request ...
    $request.Method = $Method.ToUpper()

    # Now that we have a web request, we'll use the session values first if we have any
    if($WebSession) {
      $request.CookieContainer = $WebSession.Cookies
      $request.Headers = $WebSession.Headers
      if($WebSession.UseDefaultCredentials) {
        $request.UseDefaultCredentials
      } elseif($WebSession.Credentials) {
        $request.Credentials = $WebSession.Credentials
      }
      $request.ClientCertificates = $WebSession.Certificates
      $request.UserAgent = $WebSession.UserAgent
      $request.Proxy = $WebSession.Proxy
      $request.MaximumAutomaticRedirections = $WebSession.MaximumRedirection
    } else {
      $request.CookieContainer = $Cookies = New-Object System.Net.CookieContainer
    }
   
    # And override session values with user values if they provided any
    $request.UserAgent = $UserAgent
    $request.MaximumAutomaticRedirections = $MaximumRedirection
    $request.KeepAlive = !$DisableKeepAlive

    # Authentication normally uses EITHER credentials or certificates, but what do I know ...
    if($Certificate) {
      $request.ClientCertificates.AddRange($Certificate)
    }
    if($UseDefaultCredentials) {
      $request.UseDefaultCredentials = $true
    } elseif($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
      $request.Credentials = $Credential.GetNetworkCredential()
    }

    # You don't have to specify a proxy to specify proxy credentials (maybe your default proxy takes creds)
    if($Proxy) { $request.Proxy = New-Object System.Net.WebProxy $Proxy }
    if($request.Proxy -ne $null) {
      if($ProxyUseDefaultCredentials) {
        $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
      } elseif($ProxyCredentials -ne [System.Management.Automation.PSCredential]::Empty) {
        $request.Proxy.Credentials = $ProxyCredentials
      }
    }

    if($ForceBasicAuth) {
      if(!$request.Credentials) {
        throw "ForceBasicAuth requires Credentials!"
      }
      $request.Headers.Add('Authorization', 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($request.Credentials.UserName+":"+$request.Credentials.Password )));
    }

    if($SessionVariable) {
      Set-Variable $SessionVariable -Scope 1 -Value $WebSession
    }
   
    if($Headers) {
      foreach($h in $Headers.Keys) {
        $request.Headers.Add($h, $Headers[$h])
      }
    }

    if($Body) {
      if($Body -is [System.Collections.IDictionary] -or $Body -is [System.Collections.Specialized.NameObjectCollectionBase]) {
        if(!$ContentType) {
          $ContentType = "application/x-www-form-urlencoded"
        }
        [String]$Body = ConvertFrom-Dictionary $Body -Encode:$($ContentType -eq "application/x-www-form-urlencoded")
      } else {
        $Body = $Body | Out-String
      }

      $encoding = New-Object System.Text.ASCIIEncoding
      $bytes = $encoding.GetBytes($Body);
      $request.ContentType = $ContentType
      $request.ContentLength = $bytes.Length
      $writer = $request.GetRequestStream();
      $writer.Write($bytes, 0, $bytes.Length)
      $writer.Close()
    }

    try {
      $response = $request.GetResponse();
      if($DebugPreference -ne "SilentlyContinue") {
        Set-Variable WebResponse -Scope 2 -Value $response
      }
    } catch [System.Net.WebException] { 
      Write-Error $_.Exception -Category ResourceUnavailable
      return
    } catch { # Extra catch just in case, I can't remember what might fall here
      Write-Error $_.Exception -Category NotImplemented
      return
    }
 
    Write-Verbose "Retrieved $($Response.ResponseUri): $($Response.StatusCode)"
    if((Test-Path variable:response) -and $response.StatusCode -eq 200) {
      Write-Verbose "OutPath: $OutPath"

      # Magics to figure out a file location based on the response
      if($OutPath -and !(Split-Path $OutPath)) {
        $OutPath = Join-Path ([IO.Path]::GetTempPath()) $OutPath
      }
      elseif((!$Passthru -and !$OutPath) -or ($OutPath -and (Test-Path -PathType "Container" $OutPath)))
      {
        [string]$OutFile = ([regex]'(?i)filename=(.*)$').Match( $response.Headers["Content-Disposition"] ).Groups[1].Value
        $OutFile = $OutFile.trim("\/""'")
         
        $ofs = ""
        $OutFile = [Regex]::Replace($OutFile, "[$([Regex]::Escape(""$([System.IO.Path]::GetInvalidPathChars())$([IO.Path]::AltDirectorySeparatorChar)$([IO.Path]::DirectorySeparatorChar)""))]", "_")
        $ofs = " "
        
        if(!$OutFile) {
          $OutFile = $response.ResponseUri.Segments[-1]
          $OutFile = $OutFile.trim("\/")
          if(!$OutFile) { 
            $OutFile = Read-Host "Please provide a file name"
          }
          $OutFile = $OutFile.trim("\/")
          if(!([IO.FileInfo]$OutFile).Extension) {
            $OutFile = $OutFile + "." + $response.ContentType.Split(";")[0].Split("/")[-1].Split("+")[-1]
          }
        }
        Write-Verbose "Determined a filename: $OutFile"
        if($OutPath) {
          $OutPath = Join-Path $OutPath $OutFile
        } else {
          $OutPath = Join-Path (Convert-Path (Get-Location -PSProvider "FileSystem")) $OutFile
        }
        Write-Verbose "Calculated the full path: $OutPath"
      }

      if($Passthru) {
        $encoding = [System.Text.Encoding]::GetEncoding( $response.CharacterSet )
        [string]$output = ""
      }
 
      try {
        if($ResponseHandler) {
          . $ResponseHandler $response
        }
      } catch {
        $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
      }

      try {
        [int]$goal = $response.ContentLength
        $reader = $response.GetResponseStream()
        if($OutPath) {
          try {
            $writer = new-object System.IO.FileStream $OutPath, "Create"
          } catch { # Catch just in case, lots of things could go wrong ...
            Write-Error $_.Exception -Category WriteError
            return
          }
        }        
        [byte[]]$buffer = new-object byte[] 4096
        [int]$total = [int]$count = 0
        do
        {
          $count = $reader.Read($buffer, 0, $buffer.Length);
          if($OutPath) {
            $writer.Write($buffer, 0, $count);
          } 
          if($Passthru){
            $output += $encoding.GetString($buffer,0,$count)
          } elseif(!$quiet) {
            $total += $count
            if($goal -gt 0) {
              Write-Progress "Downloading $Uri" "Saving $total of $goal" -id 0 -percentComplete (($total/$goal)*100)
            } else {
              Write-Progress "Downloading $Uri" "Saving $total bytes..." -id 0
            }
          }
        } while ($count -gt 0)
      } catch [Exception] {
        $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
        Write-Error "Could not download package from $Url"
      } finally {
        if(Test-Path variable:Reader) {
          $Reader.Close()
          $Reader.Dispose()
        }
        if(Test-Path variable:Writer) {
          $writer.Flush()
          $Writer.Close()
          $Writer.Dispose()
        }
      }
      
      Write-Progress "Finished Downloading $Uri" "Saved $total bytes..." -id 0 -Completed

      if($OutPath) {
        Get-Item $OutPath
      } elseif(Get-Variable output -Scope Local) {
        $output
      }
    }
    if(Test-Path variable:response) {
      $response.Close(); 
      $response.Dispose(); 
    }

    if($SessionVariable) {
      Set-Variable $SessionVariable -Scope 1 -Value ([PSCustomObject]@{
        Headers               = ConvertTo-Dictionary -Headers $request.Headers
        Cookies               = $response.Cookies
        UseDefaultCredentials = $request.UseDefaultCredentials
        Credentials           = $request.Credentials
        Certificates          = $request.ClientCertificates
        UserAgent             = $request.UserAgent
        Proxy                 = $request.Proxy
        MaximumRedirection    = $request.MaximumAutomaticRedirections
      })
    }
    if($WebSession) {
      $WebSession.Cookies      = $response.Cookies
    }
  }
}

New-Alias iw Invoke-Web -ErrorAction SilentlyContinue
# SIG # Begin signature block
# MIIarwYJKoZIhvcNAQcCoIIaoDCCGpwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1JdnjmoQqKyUaJGUOaLmBdsR
# HjCgghXlMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# KoZIhvcNAQkEMRYEFAykS2IWwTmme67d0uXi9CetFGKuMA0GCSqGSIb3DQEBAQUA
# BIIBAARuqWu1ELTGB46mAM9d6tCBjv2cMpDEa+7uJBMND0CuyPa73wrHT6prTR/3
# HnF940g+HeosQjaFVghxu5gtuxm2gfTEpaOWopXQSWpF0/HFNYDfFVzZlyiVvJ+3
# 3mRG/G5ObzAgqIcz9Oz/3RMf+VgHywBvrkIVNnsMGJCa4awJzgObv4IdJvh+K5ek
# GcgHTRdQ6ShJCirLWL14MFAzzhyw8R1UPiaiu42/2yzvBU8xaFu7/6o5Y/6vo9XJ
# XwsrDLezAtz6KaCqdzzluK+GywSS8AlJi9NYe1bwxYWkaHSYauEj+cHwAhK6tgeP
# uUkvRxzNGDlpWL0FfV25fklAkkyhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQC
# AQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0Eg
# LSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNDE4MTkwMDQ1WjAjBgkq
# hkiG9w0BCQQxFgQUGA8+W0ZvnhEc4xmIZ3wiDkq0vjEwDQYJKoZIhvcNAQEBBQAE
# ggEALlPz8i1hlsVDA1037dhcln4UbWRXEL8QbozbSyCzuNCDZj37SO6U4Eh5Eu1+
# FmJwiGNf7QBDSFJfo89UU16Yz5wfvG3BSdYNy57ujhRX9r32lib74kbmTfRNSVxW
# RDYjgLi8MoGCJmNIO30sE8k2CKb+XEx4y4qgtZcH8+Rn0Acw7aPxQ44vRLccMs45
# ieJ1yXi1p5negAzcar+MVojbPq+03spjj0kh+85lhvtWPGqY/HFZ35lpP8YxX79S
# bT9yJI7UXJUIJQogySlxUkVePhVQq4eYZUd38RjyrrBd0O/kQAbgG0hW8m4fmDFI
# 7mQ2qcEEGFzpktDqq+B35QFeUw==
# SIG # End signature block
