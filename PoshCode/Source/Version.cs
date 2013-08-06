// ***********************************************************************
// Assembly         : PoshCode.Packaging
// Author           : Joel Bennett
// Created          : 04-01-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 04-01-2013
// ***********************************************************************
// <copyright file="Version.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary>A replacement for the System.Version because that one doesn't serialize properly</summary>
// ***********************************************************************
namespace PoshCode.Packaging
{
   using System;
   using System.ComponentModel;
   using System.Linq;
   using System.Runtime.InteropServices;

   /// <summary>
   /// A replacement for the System.Version because that one doesn't serialize properly
   /// </summary>
   [TypeConverter(typeof(VersionTypeConverter))]
   public class Version : IComparable, IEquatable<Version>, IEquatable<string>, IEquatable<double>, IEquatable<decimal>
   {
      /// <summary>
      /// The revision value
      /// </summary>
      private RevisionValue revision;

      /// <summary>
      /// Initializes a new instance of the <see cref="Version" /> class.
      /// </summary>
      public Version()
      {
         this.revision = new RevisionValue();
         this.Major = this.Minor = this.Build = this.Revision = -1;
      }

      /// <summary>
      /// Initializes a new instance of the <see cref="Version" /> class from the specified double
      /// </summary>
      /// <param name="version">The version.</param>
      public Version(double version) : this()
      {
         if (version <= 0.0)
         {
            throw new ArgumentOutOfRangeException("version", "A Version must be a positive number");
         }

         this.Major = (int)Math.Truncate(version);
         this.Minor = (int)(Math.Abs(version) - Math.Truncate(Math.Abs(version)));
      }


      /// <summary>
      /// Initializes a new instance of the <see cref="Version" /> class from the specified long version
      /// </summary>
      /// <param name="version">The version.</param>
      public Version(long version) : this()
      {
         this.Revision = (int)(version & 0xffff);
         this.Build    = (int)((version >> 16) & 0xffff);
         this.Minor    = (int)((version >> 32) & 0xffff);
         this.Major    = (int)((version >> 48) & 0xffff);
      }


      /// <summary>
      /// Initializes a new instance of the <see cref="Version" /> class from the specified long version
      /// </summary>
      /// <param name="version">The version.</param>
      public Version(ulong version) : this()
      {
         this.Revision = (int)(version & 0xffff);
         this.Build    = (int)((version >> 16) & 0xffff);
         this.Minor    = (int)((version >> 32) & 0xffff);
         this.Major    = (int)((version >> 48) & 0xffff);
      }

      /// <summary>
      /// Initializes a new instance of the <see cref="Version" /> class from a <see cref="System.Version" />.
      /// </summary>
      /// <param name="version">The version.</param>
      public Version(System.Version version) : this()
      {
         if (!ReferenceEquals(null, version))
         {
            this.Major = version.Major;
            this.Minor = version.Minor;

            if (version.Build >= 0)
            {
               this.Build = version.Build;
            }

            if (version.Revision >= 0)
            {
               this.Revision = version.Revision;
            }
         }
      }

      /// <summary>
      /// Initializes a new instance of the <see cref="Version" /> class from a <see cref="System.String" />.
      /// </summary>
      /// <param name="version">The version.</param>
      public Version(string version) : this()
      {
         string[] parts = version.Split('.');
         int[] pieces;
         if (parts.Length < 2 || parts.Length > 4)
         {
            throw new ArgumentException("Version string portion was too short or too long.");
         }

         try
         {
            pieces = parts.Select(int.Parse).ToArray();
         }
         catch
         {
            throw new ArgumentException("Input string was not in a correct format.");
         }

         if (pieces.Length >= 2)
         {
            this.Major = pieces[0];
            this.Minor = pieces[1];
         }

         if (pieces.Length >= 3)
         {
            this.Build = pieces[2];
         }

         if (pieces.Length >= 4)
         {
            this.Revision = pieces[3];
         }
      }
      
      /// <summary>
      /// Gets or sets the major version number.
      /// </summary>
      /// <value>The major.</value>
      [DefaultValue(-1)]
      public int Major { get; set; }

      /// <summary>
      /// Gets or sets the minor version number.
      /// </summary>
      /// <value>The minor.</value>
      [DefaultValue(-1)]
      public int Minor { get; set; }

      /// <summary>
      /// Gets or sets the build number.
      /// </summary>
      /// <value>The build.</value>
      [DefaultValue(-1)]
      public int Build { get; set; }

      /// <summary>
      /// Gets or sets the revision number
      /// </summary>
      /// <value>The revision.</value>
      [DefaultValue(-1)]
      public int Revision
      {
         get
         {
            return this.revision.Number;
         }

         set
         {
            this.revision.Number = value;
         }
      }

      /// <summary>
      /// Gets the major portion of the revision number.
      /// </summary>
      /// <value>The major revision.</value>
      [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
      public short MajorRevision
      {
         get
         {
            return this.revision.High;
         }
      }

      /// <summary>
      /// Gets the minor portion of the revision number.
      /// </summary>
      /// <value>The minor revision.</value>
      [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
      public short MinorRevision
      {
         get
         {
            return this.revision.Low;
         }
      }
      
      /// <summary>
      /// Parses the specified version.
      /// </summary>
      /// <param name="input">The version.</param>
      /// <returns>The Version.</returns>
      public static Version Parse(string input)
      {
         return new Version(input);
      }
      
      /// <summary>
      /// Parses the specified input.
      /// </summary>
      /// <param name="input">The input.</param>
      /// <param name="version">The version.</param>
      /// <returns><c>true</c> if the parse is successful, <c>false</c> otherwise</returns>
      public static bool TryParse(string input, out Version version)
      {
         try
         {
            version = new Version(input);
            return true;
         }
         catch
         {
            version = new Version();
            return false;
         }
      }


      /// <summary>
      /// Performs an implicit conversion from <see cref="long" /> to <see cref="Version" />.
      /// </summary>
      /// <param name="version">The version number.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator Version(long version)
      {
         return new Version(version);
      }

      /// <summary>
      /// Performs an implicit conversion from <see cref="ulong" /> to <see cref="Version" />.
      /// </summary>
      /// <param name="version">The version number.</param>
      /// <returns>The result of the conversion.</returns>
      public static explicit operator Version(ulong version)
      {
         return new Version(version);
      }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.String" /> to <see cref="Version" />.
      /// </summary>
      /// <param name="version">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator Version(string version)
      {
         return new Version(version);
      }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.Version" /> to <see cref="Version" />.
      /// </summary>
      /// <param name="version">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator Version(System.Version version)
      {
         return ReferenceEquals(null, version) ? null : new Version(version);
      }

      /// <summary>
      /// Performs an implicit conversion from <see cref="System.Version" /> to <see cref="Version" />.
      /// </summary>
      /// <param name="version">The module info.</param>
      /// <returns>The result of the conversion.</returns>
      public static implicit operator System.Version(Version version)
      {
         if (version.Revision >= 0)
         {
            return new System.Version(version.Major, version.Minor, version.Build, version.Revision);
         }

         if (version.Build >= 0)
         {
            return new System.Version(version.Major, version.Minor, version.Build);
         }

         return new System.Version(version.Major, version.Minor);
      }

      /// <summary>
      /// Implements the !=.
      /// </summary>
      /// <param name="x">The x.</param>
      /// <param name="y">The y.</param>
      /// <returns>The result of the operator.</returns>
      public static bool operator !=(Version x, Version y)
      {
         return (ReferenceEquals(null, x) && !ReferenceEquals(null, y)) || (!ReferenceEquals(null, x) && ReferenceEquals(null, y)) || (!ReferenceEquals(null, x) && !x.Equals(y));
      }

      /// <summary>
      /// Implements the ==.
      /// </summary>
      /// <param name="x">The x.</param>
      /// <param name="y">The y.</param>
      /// <returns>The result of the operator.</returns>
      public static bool operator ==(Version x, Version y)
      {
         return (ReferenceEquals(null, x) && ReferenceEquals(null, y)) || (!ReferenceEquals(null, x) && x.Equals(y));
      }

      /// <summary>
      /// Implements the &gt;.
      /// </summary>
      /// <param name="x">The x.</param>
      /// <param name="y">The y.</param>
      /// <returns>The result of the operator.</returns>
      /// <exception cref="System.ArgumentNullException">x;Cannot compare Version to Null</exception>
      /// <exception cref="System.ArgumentNullException">y;Cannot compare Version to Null</exception>
      public static bool operator >(Version x, Version y)
      {
         if (ReferenceEquals(null, x))
         {
            throw new ArgumentNullException("x", "Cannot compare Version to Null");
         }

         if (ReferenceEquals(null, y))
         {
            throw new ArgumentNullException("y", "Cannot compare Version to Null");
         }

         return x.CompareTo(y) > 0;
      }

      /// <summary>
      /// Implements the &lt;.
      /// </summary>
      /// <param name="x">The x.</param>
      /// <param name="y">The y.</param>
      /// <returns>The result of the operator.</returns>
      /// <exception cref="System.ArgumentNullException">x;Cannot compare Version to Null</exception>
      /// <exception cref="System.ArgumentNullException">y;Cannot compare Version to Null</exception>
      public static bool operator <(Version x, Version y)
      {
         if (ReferenceEquals(null, x))
         {
            throw new ArgumentNullException("x", "Cannot compare Version to Null");
         }

         if (ReferenceEquals(null, y))
         {
            throw new ArgumentNullException("y", "Cannot compare Version to Null");
         }

         return x.CompareTo(y) < 0;
      }


      /// <summary>
      /// Implements the &gt;=.
      /// </summary>
      /// <param name="x">The x.</param>
      /// <param name="y">The y.</param>
      /// <returns>The result of the operator.</returns>
      /// <exception cref="System.ArgumentNullException">x;Cannot compare Version to Null</exception>
      /// <exception cref="System.ArgumentNullException">y;Cannot compare Version to Null</exception>
      public static bool operator >=(Version x, Version y)
      {
         if (ReferenceEquals(null, x))
         {
            throw new ArgumentNullException("x", "Cannot compare Version to Null");
         }

         if (ReferenceEquals(null, y))
         {
            throw new ArgumentNullException("y", "Cannot compare Version to Null");
         }

         return x.CompareTo(y) >= 0;
      }


      /// <summary>
      /// Implements the &lt;=.
      /// </summary>
      /// <param name="x">The x.</param>
      /// <param name="y">The y.</param>
      /// <returns>The result of the operator.</returns>
      /// <exception cref="System.ArgumentNullException">x;Cannot compare Version to Null</exception>
      /// <exception cref="System.ArgumentNullException">y;Cannot compare Version to Null</exception>
      public static bool operator <=(Version x, Version y)
      {
         if (ReferenceEquals(null, x))
         {
            throw new ArgumentNullException("x", "Cannot compare Version to Null");
         }

         if (ReferenceEquals(null, y))
         {
            throw new ArgumentNullException("y", "Cannot compare Version to Null");
         }

         return x.CompareTo(y) <= 0;
      }

      /// <summary>
      /// Determines whether the specified <see cref="System.Object" /> is equal to this instance.
      /// </summary>
      /// <param name="obj">The object to compare with the current object.</param>
      /// <returns><c>true</c> if the specified <see cref="System.Object" /> is equal to this instance; otherwise, <c>false</c>.</returns>
      public override bool Equals(object obj)
      {
         if (ReferenceEquals(null, obj))
         {
            return false;
         }

         if (ReferenceEquals(this, obj))
         {
            return true;
         }

         if (obj.GetType() != this.GetType())
         {
            return false;
         }
         return Equals((Version)obj);
      }

      /// <summary>
      /// Returns a hash code for this instance.
      /// </summary>
      /// <returns>A hash code for this instance, suitable for use in hashing algorithms and data structures like a hash table.</returns>
      public override int GetHashCode()
      {
         unchecked
         {
            var hashCode = this.Major;
            hashCode = (hashCode * 397) ^ this.Minor;
            hashCode = (hashCode * 397) ^ this.Build;
            hashCode = (hashCode * 397) ^ this.Revision;
            return hashCode;
         }
      }

      /// <summary>
      /// Compares to another Version
      /// </summary>
      /// <param name="other">The other.</param>
      /// <returns><c>true</c> if they are equatable, <c>false</c> otherwise</returns>
      public bool Equals(Version other)
      {
         if (ReferenceEquals(null, other))
         {
            return false;
         }

         if (ReferenceEquals(this, other))
         {
            return true;
         }

         return this.Major == other.Major && this.Minor == other.Minor && this.Build == other.Build && this.Revision == other.Revision;
      }

      /// <summary>
      /// Compares to another Version
      /// </summary>
      /// <param name="value">The value.</param>
      /// <returns><c>true</c> if they are equatable, <c>false</c> otherwise</returns>
      public bool Equals(string value)
      {
         Version other;
         return TryParse(value, out other) && this.Equals(other);
      }

      /// <summary>
      /// Compares to another Version
      /// </summary>
      /// <param name="other">The other.</param>
      /// <returns><c>true</c> if they are equatable, <c>false</c> otherwise</returns>
      public bool Equals(double other)
      {
         if (this.Build >= 0 && this.Revision >= 0)
         {
            return false;
         }

         var major = (int)Math.Truncate(other);
         var minor = (int)(Math.Abs(other) - Math.Truncate(Math.Abs(other)));

         return this.Major == major && this.Minor == minor;
      }

      /// <summary>
      /// Compares to another Version
      /// </summary>
      /// <param name="other">The other.</param>
      /// <returns><c>true</c> if they are equatable, <c>false</c> otherwise</returns>
      public bool Equals(decimal other)
      {
         if (this.Build >= 0 && this.Revision >= 0)
         {
            return false;
         }

         var major = (int)Math.Truncate(other);
         var minor = (int)(Math.Abs(other) - Math.Truncate(Math.Abs(other)));

         return this.Major == major && this.Minor == minor;
      }

      /// <summary>
      /// Returns a <see cref="System.String" /> that represents this instance.
      /// </summary>
      /// <returns>A <see cref="System.String" /> that represents this instance.</returns>
      public override string ToString()
      {
         if (this.Revision >= 0)
         {
            return string.Format("{0}.{1}.{2}.{3}", this.Major, this.Minor, this.Build, this.Revision);
         }

         if (this.Build >= 0)
         {
            return string.Format("{0}.{1}.{2}", this.Major, this.Minor, this.Build);
         }

         if (this.Major >= 0)
         {
            return string.Format("{0}.{1}", this.Major, this.Minor);
         }

         return string.Empty;
      }

      /// <summary>
      /// Compares the current instance with another object of the same type and returns an integer that indicates whether the current instance precedes, follows, or occurs in the same position in the sort order as the other object.
      /// </summary>
      /// <param name="obj">An object to compare with this instance.</param>
      /// <returns>A value that indicates the relative order of the objects being compared. 
      ///   The return value has these meanings: 
      /// | Value             | Meaning 
      /// | Less than zero    | This instance precedes <paramref name="obj" /> in the sort order. 
      /// | Zero              | This instance occurs in the same position in the sort order as <paramref name="obj" />. 
      /// | Greater than zero | This instance follows <paramref name="obj" /> in the sort order.</returns>
      public int CompareTo(object obj)
      {
         var other = obj as Version;
         if (other != null)
         {
            var result = this.Major.CompareTo(other.Major);
            if (result != 0)
            {
               return result;
            }

            result = this.Minor.CompareTo(other.Minor);
            if (result != 0)
            {
               return result;
            }

            result = this.Build.CompareTo(other.Build);
            if (result != 0)
            {
               return result;
            }

            result = this.Revision.CompareTo(other.Revision);
            return result;
         }

         throw new NotImplementedException("Can't compare Version to " + obj.GetType().FullName);
      }

      /// <summary>
      /// Returns a <see cref="System.String"/> that represents this instance.
      /// </summary>
      /// <param name="fieldCount">
      /// The field Count.
      /// </param>
      /// <returns>
      /// A <see cref="System.String"/> that represents this instance.
      /// </returns>
      public string ToString(int fieldCount)
      {
         if (fieldCount >= 4)
         {
            return string.Format("{0}.{1}.{2}.{3}", this.Major, this.Minor, this.Build, this.Revision);
         }

         if (fieldCount == 3)
         {
            return string.Format("{0}.{1}.{2}", this.Major, this.Minor, this.Build);
         }

         if (fieldCount == 2)
         {
            return string.Format("{0}.{1}", this.Major, this.Minor);
         }

         if (fieldCount == 1)
         {
            return string.Format("{0}", this.Major);
         }

         return string.Empty;
      }

      /// <summary>The Revision Value</summary>
      [StructLayout(LayoutKind.Explicit)]
      private struct RevisionValue
      {
         /// <summary>The low-order value</summary>
         [FieldOffset(0)]
         public readonly short Low;

         /// <summary>The high-order value</summary>
         [FieldOffset(2)]
         public readonly short High;

         /// <summary>The revision number</summary>
         [FieldOffset(0)]
         public int Number;
      }
   }
}
