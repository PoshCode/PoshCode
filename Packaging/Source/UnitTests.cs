// ***********************************************************************
// Assembly         : PoshCode.Packaging
// Author           : Joel Bennett
// Created          : 04-01-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 04-01-2013
// ***********************************************************************
// <copyright file="UnitTests.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary>Some unit tests</summary>
// ***********************************************************************
namespace PoshCode.Packaging
{
   using System;
   using System.Collections;
   using System.Collections.Generic;
   using System.Linq;
   using System.Management.Automation;
   using System.Text;

   using Microsoft.VisualStudio.TestTools.UnitTesting;

   /// <summary>
   /// Some unit tests
   /// </summary>
   [TestClass]
   public class UnitTests
   {
      /// <summary>
      /// Tests that Version is equatable...
      /// </summary>
      [TestMethod]
      public void TestVersionEquatable()
      {
         var one = new Version("1.0");
         var two = new Version(1.0);
         var three = new Version(1.0M);
         var four = new Version { Major = 1, Minor = 0 };

         Assert.IsTrue(one == two);

         Assert.AreEqual(one, four);
         Assert.AreEqual(two, four);
         Assert.AreEqual(two, three);
         Assert.AreEqual(three, four);

         Assert.IsTrue(one.Equals(three));
         Assert.IsTrue(three.Equals(one));

         Assert.IsTrue(one == two);
         Assert.IsTrue(one == three);

         Assert.AreNotSame(one, two);

         var revision = new Version { Major = 1, Minor = 0, Build = 0, Revision = 1 };
         Assert.IsFalse(revision == three);
         Assert.IsTrue(revision != three);
         Assert.AreNotEqual(revision, three);
      }

      /// <summary>
      /// Test the Version comparison operator
      /// </summary>
      [TestMethod]
      public void VersionCompare()
      {
         var v1 = new Version("2.1");
         var v2 = new Version("2.2");

         Assert.AreNotEqual(v1, v2);
         Assert.IsTrue(v2 > v1);
         Assert.IsTrue(v2 >= v1);
         Assert.IsTrue(v1 < v2);
         Assert.IsTrue(v1 <= v2);


         v1 = new Version("2.1.0.1");
         v2 = new Version("2.1.0.2");

         Assert.AreNotEqual(v1, v2);
         Assert.IsTrue(v2 > v1);
         Assert.IsTrue(v2 >= v1);
         Assert.IsTrue(v1 < v2);
         Assert.IsTrue(v1 <= v2);
      }

      /// <summary>
      /// Tests the string list serializer.
      /// </summary>
      [TestMethod]
      public void TestStringListSerializer()
      {
         var m = new ModuleManifest() { Name = "Test", Version = (Version)"2.0", ClrVersion = (Version)"4.5" };
         m.AliasesToExport.Add("One");
         m.AliasesToExport.Add("Two");

         var x = System.Xaml.XamlServices.Save(m);

         Assert.IsTrue(x.Contains(@"<ModuleManifest.AliasesToExport>
    <x:String>One</x:String>
    <x:String>Two</x:String>
  </ModuleManifest.AliasesToExport>"));
         // we don't want any nulls in our default manifests
         Assert.IsFalse(x.Contains(@"assembly:Null"));

         var mm = System.Xaml.XamlServices.Parse(x);

         Assert.IsTrue(mm is ModuleManifest);
         m = (ModuleManifest)mm;
         Assert.AreEqual(m.Version, (Version)"2.0");
         Assert.AreEqual(m.ClrVersion, (Version)"4.5");

         var ht = new System.Collections.Hashtable();
      }

      /// <summary>
      /// Tests the RequiredModules serialization
      /// </summary>
      [TestMethod]
      public void TestRequiredModules()
      {
         var m = new ModuleManifest { Name = "Test" };
         m.RequiredModules.AddRange(new[] { new ModuleId { Name = "One" }, new ModuleId { Name = "Two" } });
         string x, y;
         bool ok = false;
         x = System.Xaml.XamlServices.Save(m);
         y = System.Windows.Markup.XamlWriter.Save(m);

         ok = x.Contains(@"<ModuleManifest.RequiredModules>
    <ModuleId Name=""One"" ReleaseUri="""" />
    <ModuleId Name=""Two"" ReleaseUri="""" />
  </ModuleManifest.RequiredModules>");

         // TODO: Figure out XamlWriter
         ok = ok || y.Contains(@"<ModuleManifest.RequiredModules>
    <ModuleId Name=""One"" ReleaseUri="""" />
    <ModuleId Name=""Two"" ReleaseUri="""" />
  </ModuleManifest.RequiredModules>");

         Assert.IsTrue(ok);
      }

      /// <summary>
      /// Tests the FileList serialization
      /// </summary>
      [TestMethod]
      public void TestFileList()
      {
         var m = new ModuleManifest { Name = "Test" };
         m.FileList.AddRange(new[] { "Module.psd1", "Module.psm1" });
         m.FunctionsToExport.AddRange(new[] { "Get-Something", "New-Something" });
         string x = System.Xaml.XamlServices.Save(m);

         Assert.IsTrue(x.Contains(@"FunctionsToExport=""Get-Something,New-Something"""));
         Assert.IsTrue(x.Contains(@"<ModuleManifest.FileList>
    <x:String>Module.psd1</x:String>
    <x:String>Module.psm1</x:String>
  </ModuleManifest.FileList>"));
      }

      /// <summary>
      /// Test the Hashtable cast.
      /// </summary>
      [TestMethod]
      public void ModuleIdToHashtable()
      {
         var mid = new ModuleId()
                      {
                         Name = "Module",
                         Guid = new Guid("CA2EB1D9-C16C-4E59-8E3B-7370A1494670"),
                         ReleaseUri = "http://PoshCode.org",
                         Version = "2.1"
                      };

         var psm = (Hashtable)mid;

         Assert.AreEqual(mid.Name, psm["ModuleName"]);
         Assert.AreEqual(mid.Version, psm["ModuleVersion"]);
         Assert.AreEqual(mid.Guid, psm["Guid"]);
         Assert.IsFalse(psm.ContainsKey("ReleaseUri"));

         mid = new ModuleId()
         {
            Name = "Module",
         };

         psm = (Hashtable)mid;

         Assert.AreEqual(mid.Name, psm["ModuleName"]);
         Assert.AreEqual(new Version("0.0"), psm["ModuleVersion"]);
         Assert.IsFalse(psm.ContainsKey("Guid"));
         Assert.IsFalse(psm.ContainsKey("ReleaseUri"));
      }


   }
}
