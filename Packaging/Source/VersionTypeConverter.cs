// ***********************************************************************
// Assembly         : PoshCode.Packaging
// Author           : Joel Bennett
// Created          : 04-03-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 04-03-2013
// ***********************************************************************
// <copyright file="VersionTypeConverter.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary>A TypeConverter to make sure PoshCode.Packaging.Version serializes the way we want it to</summary>
// ***********************************************************************
namespace PoshCode.Packaging
{
   using System;
   using System.ComponentModel;
   using System.Diagnostics.CodeAnalysis;

   /// <summary>
   /// A TypeConverter to make sure PoshCode.Packaging.Version serializes the way we want it to
   /// </summary>
   public class VersionTypeConverter : TypeConverter
   {
      /// <summary>
      /// Returns whether this converter can convert the object to the specified type, using the specified context.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="destinationType">A <see cref="T:System.Type" /> that represents the type you want to convert to.</param>
      /// <returns>true if this converter can perform the conversion; otherwise, false.</returns>
      public override bool CanConvertTo(ITypeDescriptorContext context, Type destinationType)
      {
         var can = destinationType == typeof(string) || destinationType == typeof(Version) || base.CanConvertTo(context, destinationType);
         return can;
      }

      /// <summary>
      /// Returns whether this converter can convert an object of the given type to the type of this converter, using the specified context.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="sourceType">A <see cref="T:System.Type" /> that represents the type you want to convert from.</param>
      /// <returns>true if this converter can perform the conversion; otherwise, false.</returns>
      public override bool CanConvertFrom(ITypeDescriptorContext context, Type sourceType)
      {
         var can = sourceType == typeof(string) || sourceType == typeof(Version) || base.CanConvertFrom(context, sourceType);
         return can;
      }

      /// <summary>
      /// Converts the given value object to the specified type, using the specified context and culture information.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="culture">A <see cref="T:System.Globalization.CultureInfo" />. If null is passed, the current culture is assumed.</param>
      /// <param name="value">The <see cref="T:System.Object" /> to convert.</param>
      /// <param name="destinationType">The <see cref="T:System.Type" /> to convert the <paramref name="value" /> parameter to.</param>
      /// <returns>An <see cref="T:System.Object" /> that represents the converted value.</returns>
      public override object ConvertTo(ITypeDescriptorContext context, System.Globalization.CultureInfo culture, object value, Type destinationType)
      {
         if (destinationType == typeof(string))
         {
            return value.ToString();
         }

         if (destinationType == typeof(Version)) 
         {
            if (value is string)
            {
               return new Version(value as string);
            }

            if (value is System.Version)
            {
               return new Version(value as System.Version);
            }
         }

         return base.ConvertTo(context, culture, value, destinationType);
      }

      /// <summary>
      /// Converts the given object to the type of this converter, using the specified context and culture information.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="culture">The <see cref="T:System.Globalization.CultureInfo" /> to use as the current culture.</param>
      /// <param name="value">The <see cref="T:System.Object" /> to convert.</param>
      /// <returns>An <see cref="T:System.Object" /> that represents the converted value.</returns>
      public override object ConvertFrom(ITypeDescriptorContext context, System.Globalization.CultureInfo culture, object value)
      {
         if (value is string)
         {
            return new Version(value as string);
         }

         return base.ConvertFrom(context, culture, value);
      }

      /// <summary>
      /// Returns whether the given value object is valid for this type and for the specified context.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="value">The <see cref="T:System.Object" /> to test for validity.</param>
      /// <returns>true if the specified value is valid for this object; otherwise, false.</returns>
      public override bool IsValid(ITypeDescriptorContext context, object value)
      {
         try
         {
            Version toss;
            return Version.TryParse(value.ToString(), out toss);
         }
         catch
         {
            return false;
         }
      }
   }
}