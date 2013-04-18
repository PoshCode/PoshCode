<?php
  use Sabre\DAV;
  use Sabre\DAV\Auth;

  // Files we need
  require_once '../SabreDAV/vendor/autoload.php';

  class ReadOnlyDirectory extends DAV\Collection {
    private $myPath;
    function __construct($myPath) {
      $this->myPath = $myPath;
    }

    function getChildren() {
      $children = array();
      // Loop through the directory, and create objects for each node
      foreach(scandir($this->myPath) as $node) {
        // Ignoring files staring with .
        if ($node[0]==='.') continue;
        $children[] = $this->getChild($node);
      }
      return $children;
    }

    function getChild($name) {
      $path = $this->myPath . '/' . $name;

      // We have to throw a NotFound exception if the file didn't exist
      if (!file_exists($path)) {
        throw new DAV\Exception\NotFound('The file with name: ' . $name . ' could not be found');
      }

      // Some added security
      if ($name[0]=='.')  throw new DAV\Exception\NotFound('Access denied');
      if (is_dir($path)) {
          return new ReadOnlyDirectory($path);
      } else {
          return new ReadOnlyFile($path);
      }
    }

    function childExists($name) {
      return file_exists($this->myPath . '/' . $name);
    }

    function getName() {
      return basename($this->myPath);
    }
  }

  class ReadOnlyFile extends DAV\File {
    private $myPath;
    function __construct($myPath) {
      $this->myPath = $myPath;
    }

    function getName() {
      return basename($this->myPath);
    }

    function get() {
      return fopen($this->myPath,'r');
    }

    function getSize() {
      return filesize($this->myPath);
    }

    function getETag() {
      return '"' . md5_file($this->myPath) . '"';
    }

    function getContentType() {
      // The FileInfo extension is not available on DreamHost?
      //$const = defined('FILEINFO_MIME_TYPE') ? FILEINFO_MIME_TYPE : FILEINFO_MIME;
      //$handle = finfo_open($const, '/usr/share/file/magic.mime');
      //$result = finfo_file($handle, $this->myPath);
      //echo $result;

      $fileext = substr(strrchr($this->myPath, '.'), 1);
      if (empty($fileext)) return null;


      // We only know these file types .psmx and .ps1
      switch($fileext) {
        case "ps1":
      	  return "text/powershell";
      	case "psmx":
      	  return "application/vnd.poshcode.package+zip";
      	case "psdxml":
      	  return "application/vnd.poshcode.package-info+xml";
      }

      return null; // no match at all
    }
  }


  // Change public to something else, if you are using a different directory for your files
  // $rootDirectory = new DAV\FS\Directory('public');
  $rootDirectory = new ReadOnlyDirectory('public');

  // The server object is responsible for making sense out of the WebDAV protocol
  $server = new DAV\Server($rootDirectory);

  // SabreDAV lives in a subdirectory with mod_rewrite sending every request to server.php
  $server->setBaseUri('/Modules');

  // // Authentication backend
  // $authBackend = new \Sabre\DAV\Auth\Backend\File('.htdigest');
  // $auth = new \Sabre\DAV\Auth\Plugin($authBackend,'poshcode');
  // $server->addPlugin($auth);

  // Support for html frontend
  $browser = new \Sabre\DAV\Browser\Plugin(false);
  $server->addPlugin($browser);

  // The lock manager is reponsible for making sure users don't overwrite each others changes. Change 'data' to a different 
  // directory, if you're storing your data somewhere else.
  $lockBackend = new DAV\Locks\Backend\File('data/locks');
  $lockPlugin = new DAV\Locks\Plugin($lockBackend);

  $server->addPlugin($lockPlugin);

  // All we need to do now, is to fire up the server
  $server->exec();

?>