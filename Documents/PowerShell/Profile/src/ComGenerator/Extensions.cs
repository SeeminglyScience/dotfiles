using System;
using System.Collections.Generic;
using Microsoft.CodeAnalysis;

internal static class Extensions
{
    public static string ToSrcString(this ITypeSymbol type)
    {
        return type.ToDisplayString(SymbolDisplayFormat.FullyQualifiedFormat);
    }

    public static IEnumerable<T> AsEnumerable<T>(this T self)
    {
        yield return self;
    }

    public static AttributeData? GetAttribute<TSymbol>(this TSymbol symbol, string metadataName)
        where TSymbol : ISymbol
    {
        foreach (AttributeData attrib in symbol.GetAttributes())
        {
            string? fullClassName = attrib.AttributeClass
                ?.ToDisplayString(
                    SymbolDisplayFormat.FullyQualifiedFormat
                        .WithGlobalNamespaceStyle(SymbolDisplayGlobalNamespaceStyle.Omitted));

            if (fullClassName?.Equals(metadataName, StringComparison.Ordinal) is true)
            {
                return attrib;
            }
        }

        return null;
    }

    public static AttributeData? GetAttribute<TSymbol>(this TSymbol symbol, string metadataName, string orThisMetadataName)
        where TSymbol : ISymbol
    {
        foreach (AttributeData attrib in symbol.GetAttributes())
        {
            string? fullClassName = attrib.AttributeClass
                ?.ToDisplayString(
                    SymbolDisplayFormat.FullyQualifiedFormat
                        .WithGenericsOptions(SymbolDisplayGenericsOptions.None)
                        .WithGlobalNamespaceStyle(SymbolDisplayGlobalNamespaceStyle.Omitted));

            if (fullClassName is null or "")
            {
                continue;
            }

            if (fullClassName.Equals(metadataName, StringComparison.Ordinal))
            {
                return attrib;
            }

            if (fullClassName.Equals(orThisMetadataName, StringComparison.Ordinal))
            {
                return attrib;
            }
        }

        return null;
    }
}
