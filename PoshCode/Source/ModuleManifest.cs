// ***********************************************************************
// Assembly         : Packaging
// Author           : Joel Bennett
// Created          : 03-31-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 03-31-2013
// ***********************************************************************
// <copyright file="ModuleManifest.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary>
//    The full module manifest, including all information about the module and it's dependencies, all the included files, and everything it exports.
// </summary>
// ***********************************************************************
namespace PoshCode.Packaging
{
   using System;
   using System.Collections.Generic;
   using System.ComponentModel;
   using System.Linq;
   using System.Windows.Markup;

   /// <summary>
   /// Class ModuleManifest
   /// </summary>
   public class ModuleManifest : ModuleInfo
   {
      /// <summary>
      /// Initializes a new instance of the <see cref="ModuleManifest" /> class.
      /// </summary>
      public ModuleManifest() : base()
      {
         this.FunctionsToExport = new StringList();
         this.CmdletsToExport = new StringList();
         this.VariablesToExport = new StringList();
         this.WorkflowsToExport = new StringList();
         this.AliasesToExport = new StringList();

         // By virtue of being List<String> rather than StringList, 
         // these are serialized as elements rather than csv attributes:
         this.ScriptsToProcess = new List<string>();
         this.TypesToProcess = new List<string>();
         this.FormatsToProcess = new List<string>();
         this.FileList = new List<string>();

         // These are lists of ModuleId, so also serialized as elements
         this.ModuleList = new List<ModuleId>();
         this.NestedModules = new List<ModuleId>();
      }

      /// <summary>
      /// Gets or sets the root module which contains the main code for this module.
      /// </summary>
      /// <value>The root module.</value>
      [DefaultValue(null)]
      public string RootModule { get; set; }

      /// <summary>
      /// Gets the list of scripts to process from this module.
      /// </summary>
      /// <value>The script files to process.</value>
      public List<string> ScriptsToProcess { get; private set; }

      /// <summary>
      /// Gets the list of type files to process from this module.
      /// </summary>
      /// <value>The type files to process.</value>
      public List<string> TypesToProcess { get; private set; }

      /// <summary>
      /// Gets the list of format files to process from this module.
      /// </summary>
      /// <value>The format files to process.</value>
      public List<string> FormatsToProcess { get; private set; }

      /// <summary>
      /// Gets or sets the list of functions to export from this module.
      /// </summary>
      /// <value>The functions to export from this module.</value>
      public StringList FunctionsToExport { get; set; }

      /// <summary>
      /// Gets the list of cmdlets to export from this module.
      /// </summary>
      /// <value>The cmdlets to export from this module.</value>
      public StringList CmdletsToExport { get; private set; }

      /// <summary>
      /// Gets the list of aliases to export from this module.
      /// </summary>
      /// <value>The aliases to export from this module.</value>
      public StringList AliasesToExport { get; private set; }

      /// <summary>
      /// Gets the list of variables to export from this module.
      /// </summary>
      /// <value>The variables to export from this module.</value>
      public StringList VariablesToExport { get; private set; }

      /// <summary>
      /// Gets the list of workflows to export from this module.
      /// </summary>
      /// <value>The workflows to export from this module.</value>
      public StringList WorkflowsToExport { get; private set; }

      /// <summary>
      /// Gets the list of all the files in this module.
      /// </summary>
      /// <value>The list of files.</value>
      public List<string> FileList { get; private set; }

      /// <summary>
      /// Gets the list of modules contained in this package (if there's more than one).
      /// </summary>
      /// <value>The module list.</value>
      [DefaultValue(null)]
      public List<ModuleId> ModuleList { get; private set; }

      /// <summary>
      /// Gets the nested modules (modules which will be loaded within the root module).
      /// </summary>
      /// <value>The nested modules.</value>
      [DefaultValue(null)]
      public List<ModuleId> NestedModules { get; private set; }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.Management.Automation.PSModuleInfo" /> to <see cref="ModuleInfo" />.
      /// </summary>
      /// <param name="moduleInfo">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator ModuleManifest(System.Management.Automation.PSModuleInfo moduleInfo)
      {
         var output = new ModuleManifest
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
            ProcessorArchitecture = moduleInfo.ProcessorArchitecture,
            RootModule = moduleInfo.RootModule,
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

         if (moduleInfo.ExportedTypeFiles != null)
         {
            foreach (var i in moduleInfo.ExportedTypeFiles)
            {
               output.TypesToProcess.Add(i);
            }
         }

         if (moduleInfo.ExportedFormatFiles != null)
         {
            foreach (var i in moduleInfo.ExportedFormatFiles)
            {
               output.FormatsToProcess.Add(i);
            }
         }

         if (moduleInfo.ExportedFunctions != null)
         {
            foreach (var i in moduleInfo.ExportedFunctions.Select(ef => ef.Key))
            {
               output.FunctionsToExport.Add(i);
            }
         }

         if (moduleInfo.ExportedCmdlets != null)
         {
            foreach (var i in moduleInfo.ExportedCmdlets.Select(ec => ec.Key))
            {
               output.CmdletsToExport.Add(i);
            }
         }

         if (moduleInfo.ExportedVariables != null)
         {
            foreach (var i in moduleInfo.ExportedVariables.Select(ev => ev.Key))
            {
               output.VariablesToExport.Add(i);
            }
         }

         if (moduleInfo.ExportedAliases != null)
         {
            foreach (var i in moduleInfo.ExportedAliases.Select(ea => ea.Key))
            {
               output.AliasesToExport.Add(i);
            }
         }

         if (moduleInfo.ExportedWorkflows != null)
         {
            foreach (var i in moduleInfo.ExportedWorkflows.Keys)
            {
               output.WorkflowsToExport.Add(i);
            }
         }

         if (moduleInfo.Scripts != null)
         {
            foreach (var i in moduleInfo.Scripts)
            {
               output.ScriptsToProcess.Add(i);
            }
         }

         if (moduleInfo.FileList != null)
         {
            foreach (var i in moduleInfo.FileList)
            {
               output.FileList.Add(i);
            }
         }

         if (moduleInfo.ModuleList != null)
         {
            foreach (var i in moduleInfo.ModuleList.Select(mod => (ModuleId)mod))
            {
               output.ModuleList.Add(i);
            }
         }

         if (moduleInfo.NestedModules != null)
         {
            foreach (var i in moduleInfo.NestedModules.Select(mod => (ModuleId)mod))
            {
               output.NestedModules.Add(i);
            }
         }

         return output;
      }
   }
}
