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
            $OutFile = $OutFile + "." + $response.ContentType.Split(";")[0].Split("/")[1]
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
      } elseif($Passthru) {
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