using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;

namespace ComGenerator;

public record ComInterfaceInfo(
    ComInterfaceInfo? Parent,
    string Namespace,
    string Name,
    ImmutableArray<string> GenericParameters,
    ImmutableArray<string> Interfaces,
    ImmutableArray<ComInterfaceMethodInfo> Methods,
    Guid Iid,
    int ExplicitMethodCount = -1)
{
    private string GetGenericParamSrcString() => GenericParameters.IsDefaultOrEmpty
        ? ""
        : $"<{string.Join(", ", GenericParameters)}>";

    public string ToSrcName() => $"global::{Namespace}.{Name}{GetGenericParamSrcString()}";

    public string ToSrcInterfaceName() => $"global::{Namespace}.{Name}{GetGenericParamSrcString()}.Interface";

    public IEnumerable<ComInterfaceInfo> EnumerateParents()
    {
        for (ComInterfaceInfo? info = Parent; info is not null; info = info.Parent)
        {
            yield return info;
        }
    }

    public IEnumerable<(ComInterfaceMethodInfo method, bool inherited)> GetAllMethods()
    {
        foreach (ComInterfaceInfo parent in EnumerateParents().Reverse())
        {
            foreach (ComInterfaceMethodInfo method in parent.Methods)
            {
                yield return (method, true);
            }
        }

        foreach (ComInterfaceMethodInfo method in Methods)
        {
            yield return (method, false);
        }
    }

    public int GetVtblSize()
    {
        if (ExplicitMethodCount is >= 0)
        {
            return (Parent?.GetVtblSize() ?? 0) + ExplicitMethodCount;
        }

        int highestExplicit = -1;
        foreach (ComInterfaceMethodInfo method in Methods)
        {
            if (highestExplicit < method.SlotIndex)
            {
                highestExplicit = method.SlotIndex;
            }
        }

        return highestExplicit + 1;
    }
}

public record ComInterfaceMethodInfo(
    string Name,
    string ReturnType,
    ImmutableArray<string> GenericParameters,
    ImmutableArray<ComInterfaceParameterInfo> Parameters,
    int SlotIndex);

public record ComInterfaceParameterInfo(
    string Name,
    string Type);
