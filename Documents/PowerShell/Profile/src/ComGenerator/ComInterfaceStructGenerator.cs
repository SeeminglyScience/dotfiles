using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Diagnostics;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Text;

namespace ComGenerator;

[Generator]
public class ComInterfaceStructGenerator : IIncrementalGenerator
{
    private const string Namespace = "SeeminglyScience.ComGenerator";

    private const string ComStructAttribute = "ComStructAttribute";

    private const string GenericComStructAttribute = "ComStructAttribute`1";

    private const string ComExcludeAttribute = "ComExcludeAttribute";

    private const string VtblOffsetAttribute = "VtblOffsetAttribute";

    private const string IComIid = "IComIid";

    private const string IHasVtbl = "IHasVtbl";

    private static ComInterfaceInfo GetComInterfaceInfo(INamedTypeSymbol type)
    {
        AttributeData? attrib = type.GetAttribute(
            $"{Namespace}.{ComStructAttribute}",
            $"{Namespace}.{ComStructAttribute}<>");

        Poly.Assert(attrib is not null);
        Guid iid = default;
        if (attrib.ConstructorArguments is { Length: > 0 })
        {
            iid = Guid.Parse(attrib.ConstructorArguments[0].Value?.ToString());
        }

        int? explicitMethodCount = null;
        foreach (KeyValuePair<string, TypedConstant> kvp in attrib.NamedArguments)
        {
            if (kvp.Key is "MethodCount")
            {
                explicitMethodCount = kvp.Value.Value switch
                {
                    int i => i,
                    _ => null,
                };
            }
        }

        INamedTypeSymbol? attribClass = attrib.AttributeClass;

        Poly.Assert(attribClass is not null);
        ComInterfaceInfo? parent = null;
        int parentVtblSize = 0;
        if (attribClass is { IsGenericType: true, TypeArguments: [INamedTypeSymbol parentTypeSymbol] })
        {
            parent = GetComInterfaceInfo(parentTypeSymbol);
            parentVtblSize = parent.GetVtblSize();
        }

        IEnumerable<ComInterfaceMethodInfo> memberInfos = type.GetMembers()
            .OfType<IMethodSymbol>()
            .Where(m => m.Name is not ".ctor" and not "..ctor")
            .Where(m => !m.IsStatic)
            .Where(m => m.AssociatedSymbol is not IPropertySymbol)
            .Where(m => m.AssociatedSymbol is not IEventSymbol)
            .Where(m => m.GetAttribute($"{Namespace}.{ComExcludeAttribute}") is null)
            .Select((m, i) =>
            {
                AttributeData? vtblOffset = m.GetAttribute($"{Namespace}.{VtblOffsetAttribute}");
                return new ComInterfaceMethodInfo(
                    m.Name,
                    m.ReturnType.ToSrcString(),
                    ImmutableArray<string>.Empty,
                    m.Parameters.Select(p => new ComInterfaceParameterInfo(p.Name, p.Type.ToSrcString())).ToImmutableArray(),
                    vtblOffset is { ConstructorArguments: [TypedConstant { Value: int explicitOffset }] }
                        ? explicitOffset + parentVtblSize
                        : i + parentVtblSize);
            });

        return new ComInterfaceInfo(
            parent,
            type.ContainingNamespace.ToDisplayString(),
            type.Name,
            type.IsGenericType
                ? type.TypeArguments.Select(ta => ta.ToSrcString()).ToImmutableArray()
                : ImmutableArray<string>.Empty,
            type.Interfaces.Select(i => i.ToSrcString()).ToImmutableArray(),
            memberInfos.ToImmutableArray(),
            iid,
            explicitMethodCount ?? -1);
    }

    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        context.RegisterPostInitializationOutput(
            context =>
            {
                context.AddSource(
                    $"{ComStructAttribute}.g.cs",
                    SourceText.From($$"""
                            namespace {{Namespace}}
                            {
                                [global::System.AttributeUsage(global::System.AttributeTargets.Struct)]
                                internal class {{ComStructAttribute}} : global::System.Attribute
                                {
                                    public {{ComStructAttribute}}() { }

                                    public {{ComStructAttribute}}(string guid) => Guid = guid;

                                    public string Guid { get; }

                                    public int MethodCount { get; set; } = -1;
                                }

                                [global::System.AttributeUsage(global::System.AttributeTargets.Struct)]
                                internal sealed class {{ComStructAttribute}}<T> : {{ComStructAttribute}}
                                {
                                    public {{ComStructAttribute}}() : base() { }

                                    public {{ComStructAttribute}}(string guid) : base(guid) { }
                                }
                            }
                            """,
                        Encoding.UTF8));

                    context.AddSource(
                        $"{ComExcludeAttribute}.g.cs",
                        SourceText.From($$"""
                            namespace {{Namespace}}
                            {
                                [global::System.AttributeUsage(global::System.AttributeTargets.Method)]
                                internal class {{ComExcludeAttribute}} : global::System.Attribute
                                {
                                }
                            }
                            """,
                        Encoding.UTF8));

                    context.AddSource(
                        $"{VtblOffsetAttribute}.g.cs",
                        SourceText.From($$"""
                            namespace {{Namespace}}
                            {
                                [global::System.AttributeUsage(global::System.AttributeTargets.Method)]
                                internal class {{VtblOffsetAttribute}} : global::System.Attribute
                                {
                                    public {{VtblOffsetAttribute}}(int offset)
                                    {
                                        Offset = offset;
                                    }

                                    public int Offset { get; }
                                }
                            }
                            """,
                        Encoding.UTF8));

                    context.AddSource(
                        $"{IComIid}.g.cs",
                        SourceText.From($$"""
                            namespace {{Namespace}}
                            {
                                public unsafe interface {{IComIid}}
                                {
                                    static abstract global::System.Guid* IID { get; }
                                }
                            }
                            """,
                        Encoding.UTF8));

                    context.AddSource(
                        $"{IHasVtbl}.g.cs",
                        SourceText.From($$"""
                            namespace {{Namespace}}
                            {
                                internal unsafe interface {{IHasVtbl}}
                                {
                                    void** GetVtbl();

                                    static abstract int GetVtblSize();
                                }
                            }
                            """,
                        Encoding.UTF8));
            });

        IncrementalValuesProvider<ComInterfaceInfo> results = context.SyntaxProvider.ForAttributeWithMetadataName(
            $"{Namespace}.{ComStructAttribute}",
            (node, _) => node is StructDeclarationSyntax,
            (c, _) => GetComInterfaceInfo((INamedTypeSymbol)c.TargetSymbol))
            .WithTrackingName("BaseComInterfaces");

        context.RegisterSourceOutput(
            results,
            RegisterFoundInterfaces);

        IncrementalValuesProvider<ComInterfaceInfo> results2 = context.SyntaxProvider.ForAttributeWithMetadataName(
            $"{Namespace}.{GenericComStructAttribute}",
            (node, _) => node is StructDeclarationSyntax,
            (c, _) => GetComInterfaceInfo((INamedTypeSymbol)c.TargetSymbol))
            .WithTrackingName("ComInterfaces");

        context.RegisterSourceOutput(
            results2,
            RegisterFoundInterfaces);

        static void RegisterFoundInterfaces(SourceProductionContext spc, ComInterfaceInfo intInfo)
        {
            SyntaxWriter members = new();
            var interfaces = intInfo.ToSrcInterfaceName().AsEnumerable().Concat(intInfo.Interfaces).Append($"global::{Namespace}.{IHasVtbl}");
            if (!intInfo.Iid.Equals(Guid.Empty))
            {
                interfaces = interfaces.Append($"global::{Namespace}.{IComIid}");
            }

            members.OpenNamespaceBlock(intInfo.Namespace)
                .AppendStructDecl(
                    intInfo.Name,
                    interfaces: interfaces.ToArray(),
                    intInfo.GenericParameters.ToArray(),
                    isPartial: true,
                    isUnsafe: true)
                .OpenBlock();

            if (!intInfo.Iid.Equals(Guid.Empty))
            {
                Guid iid = intInfo.Iid;
                ref GuidFields f = ref Unsafe.As<Guid, GuidFields>(ref iid);
                members.Append("private static global::System.Guid s_iid = new global::System.Guid(")
                    .Append($"0x{f.A:x8},0x{f.B:x4},0x{f.C:x4},0x{f.D:x2},0x{f.E:x2},0x{f.F:x2},0x{f.G:x2},0x{f.H:x2},0x{f.I:x2},0x{f.J:x2},0x{f.K:x2}")
                    .AppendLine(");")
                    .AppendLine("public static global::System.Guid* IID => (global::System.Guid*)global::System.Runtime.CompilerServices.Unsafe.AsPointer(ref s_iid);");
            }

            members.AppendLine("public void** lpVtbl;").AppendLine();

            members.AppendLine($"void** global::{Namespace}.{IHasVtbl}.GetVtbl() => lpVtbl;").AppendLine();

            members.AppendLine($"static int global::{Namespace}.{IHasVtbl}.GetVtblSize() => {intInfo.GetVtblSize()};").AppendLine();

            foreach ((ComInterfaceMethodInfo member, bool inherited) in intInfo.GetAllMethods())
            {
                members.StartMethod(
                    member.Name,
                    member.ReturnType,
                    member.Parameters.Select(p => (p.Type, p.Name)).ToArray(),
                    isPartial: !inherited);

                members.OpenBlock()
                    .MaybeAppend(!member.ReturnType.Equals("void"), "return ")
                    .AppendFormat(
                        "((delegate* unmanaged[Stdcall]<void*, {0}>)lpVtbl[{1}])(",
                        string.Join(
                            ", ",
                            member.Parameters.Select(p => p.Type)
                                .Append(member.ReturnType)),
                        member.SlotIndex);

                members.PushIndent().AppendLine().Append("global::System.Runtime.CompilerServices.Unsafe.AsPointer(ref this)");
                for (int j = 0; j < member.Parameters.Length; j++)
                {
                    members.Append(',').AppendLine()
                        .Append(member.Parameters[j].Name);
                }

                members.AppendLine(");").PopIndent().CloseBlock();
            }

            members.Append("public partial interface Interface");
            if (intInfo.Parent is not null)
            {
                members.Append(" : ").Append(intInfo.Parent.ToSrcInterfaceName());
            }

            members.AppendLine().OpenBlock();
            foreach (ComInterfaceMethodInfo method in intInfo.Methods)
            {
                members.StartMethod(
                    method.Name,
                    method.ReturnType,
                    method.Parameters.Select(p => (p.Type, p.Name)).ToArray(),
                    method.GenericParameters.ToArray(),
                    skipAccess: true,
                    isWithoutBody: true);
            }

            members.CloseBlock().CloseBlock().CloseBlock();

            spc.AddSource(
                $"{intInfo.Namespace}.{intInfo.Name}_{ComStructAttribute}.g.cs",
                members.ToString());
        }
    }
}
