// ***********************************************************************
// Assembly         : Packaging
// Author           : Joel Bennett
// Created          : 03-30-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 03-30-2013
// ***********************************************************************
// <copyright file="ModuleId.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary>
//    The minimal set of information to identify a module on PoshCode.
//    Note that we don't need author, copyright, license, or requirements etc., 
//    But we do need a ReleaseUri Uri, so we can find the ACTUAL module, and get that information
// </summary>
// ***********************************************************************
namespace PoshCode.Packaging
{
   using System;
   using System.Collections;
   using System.ComponentModel;
   using System.Management.Automation;

   using Microsoft.PowerShell.Commands;

   /// <summary>
   /// The minimal set of information to identify a module on PoshCode.
   /// </summary>
   public class ModuleId // : ModuleSpecification
   {
      /// <summary>
      /// Initializes a new instance of the <see cref="ModuleId" /> class with default values.
      /// </summary>
      public ModuleId()
      {
         this.ReleaseUri = string.Empty;
      }

      /// <summary>
      /// Gets or sets the module name.
      /// </summary>
      /// <value>The name.</value>
      public string Name { get; set; }

      /// <summary>
      /// Gets or sets the version.
      /// </summary>
      /// <value>The version.</value>
      [DefaultValue(null)]
      public Version Version { get; set; }

      /// <summary>
      /// Gets or sets the module's unique identity.
      /// </summary>
      /// <value>The globally unique identifier.</value>
      [DefaultValue(typeof(Guid), "00000000-0000-0000-0000-000000000000")]
      public Guid Guid { get; set; }
      
      /// <summary>
      /// Gets or sets the module release URI.
      /// </summary>
      /// <value>The module release URI.</value>
      public string ReleaseUri { get; set; }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.Management.Automation.PSModuleInfo" /> to <see cref="ModuleId" />.
      /// </summary>
      /// <param name="moduleInfo">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator ModuleId(PSModuleInfo moduleInfo)
      {
         return new ModuleId
         {
            Name = moduleInfo.Name,
            Version = moduleInfo.Version,
            Guid = moduleInfo.Guid
         };
      }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.String" /> to <see cref="ModuleId" />.
      /// </summary>
      /// <param name="moduleName">The module name.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator ModuleId(string moduleName)
      {
         var moduleId = new ModuleId
         {
            Name = moduleName
         };
         return moduleId;
      }

      /// <summary>
      /// Performs an implicit conversion from <see cref="ModuleId" /> to <see cref="PSModuleInfo" />.
      /// </summary>
      /// <param name="moduleInfo">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator Hashtable(ModuleId moduleInfo)
      {
         var module = new Hashtable { { "ModuleName", moduleInfo.Name } };
         if (moduleInfo.Guid != Guid.Empty)
         {
            module.Add("Guid", moduleInfo.Guid);
         }

         module.Add("ModuleVersion", moduleInfo.Version ?? "0.0");

         return module;
      }

      // /// <summary>
      // /// Explicit cast operator for dynamic (PSObjects)
      // /// </summary>
      // /// <param name="moduleInfo">The module info.</param>
      // /// <returns>A new ModuleId.</returns>
      // public static ModuleId FromDynamic(dynamic moduleInfo)
      // {
      //    var moduleId = new ModuleId
      //    {
      //       Name = moduleInfo.Name,
      //       Version = moduleInfo.Version,
      //       Guid = moduleInfo.Guid
      //    };
      //    return moduleId;
      // }
   }
}
