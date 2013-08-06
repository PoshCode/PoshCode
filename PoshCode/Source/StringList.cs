// ***********************************************************************
// Assembly         : PoshCode.Packaging
// Author           : Joel Bennett
// Created          : 04-03-2013
//
// Last Modified By : Joel Bennett
// Last Modified On : 04-04-2013
// ***********************************************************************
// <copyright file="ListOfStringTypeConverter.cs" company="HuddledMasses.org">
//     Copyright (c) Joel Bennett. All rights reserved.
// </copyright>
// <summary></summary>
// ***********************************************************************

namespace PoshCode.Packaging
{
   using System;
   using System.Collections.Generic;
   using System.ComponentModel;
   using System.Diagnostics.CodeAnalysis;
   using System.Linq;
   using System.Text.RegularExpressions;
   using System.Windows.Markup;

   /// <summary>
   /// A TypeConverter that lets us have lists of strings inline as attribute values
   /// </summary>
   public class ListOfStringTypeConverter : TypeConverter
   {
      /// <summary>
      /// The separator
      /// </summary>
      private const char Separator = ',';

      /// <summary>
      /// Returns whether this converter can convert the object to the specified type, using the specified context.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="destinationType">A <see cref="T:System.Type" /> that represents the type you want to convert to.</param>
      /// <returns>true if this converter can perform the conversion; otherwise, false.</returns>
      public override bool CanConvertTo(ITypeDescriptorContext context, Type destinationType)
      {
         return destinationType == typeof(string) || destinationType == typeof(StringList) || base.CanConvertTo(context, destinationType);
      }

      /// <summary>
      /// Returns whether this converter can convert an object of the given type to the type of this converter, using the specified context.
      /// </summary>
      /// <param name="context">An <see cref="T:System.ComponentModel.ITypeDescriptorContext" /> that provides a format context.</param>
      /// <param name="sourceType">A <see cref="T:System.Type" /> that represents the type you want to convert from.</param>
      /// <returns>true if this converter can perform the conversion; otherwise, false.</returns>
      public override bool CanConvertFrom(ITypeDescriptorContext context, Type sourceType)
      {
         return sourceType == typeof(StringList) || sourceType == typeof(string) || base.CanConvertFrom(context, sourceType);
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
         if (destinationType == typeof(string) && value is StringList)
         {
            return ((StringList)value).Count == 0 ? null : string.Join(new string(Separator, 1), (StringList)value);
         }

         if (destinationType == typeof(StringList))
         {
            if (value is string)
            {
               return new StringList((value as string).Split(Separator));
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
            return new StringList((value as string).Split(Separator));
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
         return value is string;
      }
   }

   /// <summary>
   /// A ValueSerializer to make sure the string lists serialize the way we want them to.
   /// </summary>
   public class StringListSerializer : ValueSerializer
   {
      /// <summary>
      /// The separator
      /// </summary>
      private const char Separator = ',';

      /// <summary>
      /// Determines whether the specified object can be converted into a <see cref="T:System.String" />.
      /// </summary>
      /// <param name="value">The object to evaluate for conversion.</param>
      /// <param name="context">Context information that is used for conversion.</param>
      /// <returns>true if the <paramref name="value" /> can be converted into a <see cref="T:System.String" />; otherwise, false.</returns>
      public override bool CanConvertToString(object value, IValueSerializerContext context)
      {
         return value is List<string> || base.CanConvertToString(value, context);
      }

      /// <summary>
      /// Converts the specified object to a <see cref="T:System.String" />.
      /// </summary>
      /// <param name="value">The object to convert into a string.</param>
      /// <param name="context">Context information that is used for conversion.</param>
      /// <returns>A string representation of the specified object.</returns>
      public override string ConvertToString(object value, IValueSerializerContext context)
      {
         var list = (List<string>)value;
         return string.Join(new string(Separator, 1), list);
      }

      /// <summary>
      /// Determines whether the specified <see cref="T:System.String" /> can be converted to an instance of the type that the implementation of <see cref="T:System.Windows.Markup.ValueSerializer" /> supports.
      /// </summary>
      /// <param name="value">The string to evaluate for conversion.</param>
      /// <param name="context">Context information that is used for conversion.</param>
      /// <returns>true if the value can be converted; otherwise, false.</returns>
      public override bool CanConvertFromString(string value, IValueSerializerContext context)
      {
         return true;
      }

      /// <summary>
      /// Converts a <see cref="T:System.String" /> to an instance of the type that the implementation of <see cref="T:System.Windows.Markup.ValueSerializer" /> supports.
      /// </summary>
      /// <param name="value">The string to convert.</param>
      /// <param name="context">Context information that is used for conversion.</param>
      /// <returns>A new instance of the type that the implementation of <see cref="T:System.Windows.Markup.ValueSerializer" /> supports based on the supplied <paramref name="value" />.</returns>
      public override object ConvertFromString(string value, IValueSerializerContext context)
      {
         return value.Split(Separator).ToList();
      }
   }

   /// <summary>
   /// A nice holder for lists of strings, for serialization purposes
   /// </summary>
   [TypeConverter(typeof(ListOfStringTypeConverter))]
   [ValueSerializer(typeof(StringListSerializer))]
   public class StringList : List<string>
   {
      /// <summary>
      /// Initializes a new instance of the <see cref="StringList" /> class.
      /// </summary>
      public StringList()
      {
      }

      /// <summary>
      /// Initializes a new instance of the <see cref="StringList" /> class from the specified collection
      /// </summary>
      /// <param name="collection">The values.</param>
      public StringList(IEnumerable<string> collection)
         : base(collection)
      {
      }
   }

}