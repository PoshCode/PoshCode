// ***********************************************************************
// Assembly         : Packaging
// Author           : Joel Bennett
// Created          : 03-30-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 03-31-2013
// ***********************************************************************
// <copyright file="ModuleInfo.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary>
//    The core information about a module and it's dependencies
// </summary>
// ***********************************************************************
namespace PoshCode.Packaging
{
   using System;
   using System.Collections.Generic;
   using System.ComponentModel;
   using System.Linq;
   using System.Reflection;
   using System.Windows.Markup;

   /// <summary>
   /// The core information about the Module and it's dependencies
   /// </summary>
   public class ModuleInfo : ModuleId
   {
      /// <summary>
      /// Initializes a new instance of the <see cref="ModuleInfo" /> class.
      /// </summary>
      public ModuleInfo()
      {
         this.RequiredModules = new List<ModuleId>();
         this.RequiredAssemblies = new List<string>();
         this.Keywords = new StringList();

         // Initializing these to empty strings (while the DefaultValue is null) causes them to always show up in serialized objects, even if they're blank
         this.LicenseUri  = string.Empty;
         this.HomePageUri = string.Empty;
         this.PackageUri  = string.Empty;
         this.HelpInfoUri = string.Empty;
      }

      /// <summary>
      /// Gets or sets the name of the author of the module and it's contents
      /// </summary>
      /// <value>The author's name.</value>
      [DefaultValue(null)]
      public string Author { get; set; }

      /// <summary>
      /// Gets or sets the name of the company that owns or provides support for the module.
      /// </summary>
      /// <value>The name of the owner company.</value>
      [DefaultValue(null)]
      public string CompanyName { get; set; }

      /// <summary>
      /// Gets or sets the description of the module and it's contents.
      /// </summary>
      /// <value>The description of the module.</value>
      [DefaultValue(null)]
      public string Description { get; set; }

      /// <summary>
      /// Gets or sets the copyright of the module and it's contents.
      /// </summary>
      /// <value>The copyright statement.</value>
      [DefaultValue(null)]
      public string Copyright { get; set; }

      /// <summary>
      /// Gets or sets the license URI for the module. This should point directly to a license file which describes the license for this module. 
      /// The URI may be a relative URI which points to the license, as contained in the package, or it may point to a license file on the web. 
      /// Although this is not preferred, it may also point to a minimal web page which contains the license text, such as 
      /// <seealso cref="http://opensource.org/licenses/MIT"/>  or <seealso cref="http://wasp.codeplex.com/license"/> 
      /// </summary>
      /// <value>The license URI.</value>
      public string LicenseUri { get; set; }

      /// <summary>
      /// Gets or sets the download URI for the PowerShell Help for this module.
      /// </summary>
      /// <value>The help URI.</value>
      public string HelpInfoUri { get; set; }

      /// <summary>
      /// Gets or sets the information URI for this module project. This should be the homepage for the module project.
      /// </summary>
      /// <value>The module home page URI.</value>
      public string HomePageUri { get; set; }

      /// <summary>
      /// Gets or sets the package download URI. This should be the location where the version-specific .psmx package can be downloaded
      /// </summary>
      /// <value>The module package download URI.</value>
      public string PackageUri { get; set; }

      /// <summary>
      /// Gets the keyword tags for this module.
      /// </summary>
      /// <value>The keyword tags.</value>
      [DefaultValue(null)]
      public StringList Keywords { get; private set; }      

      /// <summary>
      /// Gets or sets the classification category (from the TechNet hierarchy) for this module.
      /// </summary>
      /// <value>The category.</value>
      [DefaultValue(null)]
      public string Category { get; set; }     

      // OPTIONAL: requirements to get the module to run:
      // TODO: PrivateData should support ... hashtable of whatever
      // TODO: DefaultCommandPrefix -- can we read that from a module? Does it screw up our Exported*?

      /// <summary>
      /// Gets the required assemblies for this module. Maybe simple assembly names, relative paths, or fully qualified assembly names.
      /// </summary>
      /// <value>The required assemblies.</value>
      public List<string> RequiredAssemblies { get; private set; }

      /// <summary>
      /// Gets the required modules for this module. 
      /// May be simple module names, or a module name and version, or may include a GUID and module release URI. The more information, the better.
      /// </summary>
      /// <value>The required modules.</value>
      public List<ModuleId> RequiredModules { get; private set; }

      /// <summary>
      /// Gets or sets the CLR version required for this module.
      /// </summary>
      /// <value>The CLR version.</value>
      [DefaultValue(null)]
      public Version ClrVersion { get; set; }

      /// <summary>
      /// Gets or sets the dot net framework version required for this module.
      /// </summary>
      /// <value>The dot net framework version.</value>
      [DefaultValue(null)]
      public Version DotNetFrameworkVersion { get; set; }

      /// <summary>
      /// Gets or sets the name of the PowerShell host required for this module.
      /// </summary>
      /// <value>The name of the PowerShell host.</value>
      [DefaultValue(null)]
      public string PowerShellHostName { get; set; }

      /// <summary>
      /// Gets or sets the PowerShell host version required for this module.
      /// </summary>
      /// <value>The PowerShell host version.</value>
      [DefaultValue(null)]
      public Version PowerShellHostVersion { get; set; }

      /// <summary>
      /// Gets or sets the PowerShell version required for this module.
      /// </summary>
      /// <value>The PowerShell version.</value>
      [DefaultValue(null)]
      public Version PowerShellVersion { get; set; }

      /// <summary>
      /// Gets or sets the processor architecture required for this module.
      /// </summary>
      /// <value>The processor architecture.</value>
      [DefaultValue(typeof(ProcessorArchitecture), "None")]
      public ProcessorArchitecture ProcessorArchitecture { get; set; }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.Management.Automation.PSModuleInfo" /> to <see cref="ModuleInfo" />.
      /// </summary>
      /// <param name="moduleInfo">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator ModuleInfo(System.Management.Automation.PSModuleInfo moduleInfo)
      {
         var output = new ModuleInfo
         {
            Name = moduleInfo.Name,
            Version = moduleInfo.Version,
            Guid = moduleInfo.Guid,
            Author = moduleInfo.Author,
            CompanyName = moduleInfo.CompanyName,
            Description = moduleInfo.Description,
            Copyright = moduleInfo.Copyright,
            HelpInfoUri = string.IsNullOrEmpty(moduleInfo.HelpInfoUri) ? string.Empty : moduleInfo.HelpInfoUri,
            ClrVersion = moduleInfo.ClrVersion,
            DotNetFrameworkVersion = moduleInfo.DotNetFrameworkVersion,
            PowerShellHostName = moduleInfo.PowerShellHostName,
            PowerShellHostVersion = moduleInfo.PowerShellHostVersion,
            PowerShellVersion = moduleInfo.PowerShellVersion,
            ProcessorArchitecture = moduleInfo.ProcessorArchitecture
         };

         if (moduleInfo.RequiredAssemblies != null)
         {
            foreach (var r in moduleInfo.RequiredAssemblies)
            {
               output.RequiredAssemblies.Add(r);
            }
         }

         if (moduleInfo.RequiredModules != null)
         {
            foreach (var m in moduleInfo.RequiredModules.Select(mod => (ModuleId)mod)) 
            {
               output.RequiredModules.Add(m);
            }
         }

         return output;
      }
   }
}