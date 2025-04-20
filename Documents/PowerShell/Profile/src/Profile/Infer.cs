using System.Collections.Immutable;
using System.Diagnostics.CodeAnalysis;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace Profile;

public abstract class PSInferredMember
{
    public abstract MemberTypes Kind { get; }

    public virtual string Name => GetReflectionMembers()[0].Name;

    public string Definition => ToString();

    public abstract MemberInfo[] GetReflectionMembers();

    public abstract ImmutableArray<PSTypeName> GetOutputTypes();

    private protected PSInferredMember()
    {
    }

    public override string ToString()
    {
        MemberInfo? firstMember = GetReflectionMembers().FirstOrDefault();
        if (firstMember is null)
        {
            return string.Empty;
        }

        return Format.Member(firstMember);
    }

    internal static PSInferredMember Create(object value)
    {
        if (value is PropertyInfo property)
        {
            return new PSInferredProperty(property);
        }

        return new PSInferredMethodGroup(value);
    }
}

public sealed class PSInferredProperty : PSInferredMember
{
    private readonly PropertyInfo _property;

    internal PSInferredProperty(PropertyInfo property) => _property = property;

    public override MemberTypes Kind => MemberTypes.Property;

    public override string Name => _property.Name;

    [field: MaybeNull]
    private PSTypeName[] OutputTypes => field ??= [new PSTypeName(_property.PropertyType)];

    public override ImmutableArray<PSTypeName> GetOutputTypes()
    {
        PSTypeName[] outputTypes = OutputTypes;
        return Unsafe.As<PSTypeName[], ImmutableArray<PSTypeName>>(ref outputTypes);
    }

    public override MemberInfo[] GetReflectionMembers()
    {
        return [_property];
    }
}

public sealed class PSInferredMethodGroup : PSInferredMember
{
    private readonly object _cacheEntry;

    private MethodBase[]? _members;

    internal PSInferredMethodGroup(object cacheEntry) => _cacheEntry = cacheEntry;

    public override MemberTypes Kind => MemberTypes.Method;

    public override string Name => ReflectionMembers[0].Name;


    internal MethodBase[] ReflectionMembers
    {
        get
        {
            if (_members is not null)
            {
                return _members;
            }

            object? mi = ReflectionCache.MethodCacheEntry
                .methodInformationStructures
                .GetValue(_cacheEntry);

            if (mi is null)
            {
                return [];
            }

            if (mi is not Array mis)
            {
                return [];
            }

            MethodBase[] members = new MethodBase[mis.Length];
            for (int i = 0; i < members.Length; i++)
            {
                members[i] = (MethodBase)ReflectionCache.MethodInformation
                    .method
                    .GetValue(mis.GetValue(i))!;
            }

            return _members = members;
        }
    }

    [field: MaybeNull]
    private PSTypeName[] OutputTypes => field ??= ReflectionMembers
        .Select(m => m is MethodInfo mi ? mi.ReturnType : typeof(void))
        .Distinct()
        .Select(t => new PSTypeName(t))
        .ToArray();

    public override ImmutableArray<PSTypeName> GetOutputTypes()
    {
        PSTypeName[] outputTypes = OutputTypes;
        return Unsafe.As<PSTypeName[], ImmutableArray<PSTypeName>>(ref outputTypes);
    }

    public override MemberInfo[] GetReflectionMembers()
    {
        return [.. ReflectionMembers];
    }
}

public static class Infer
{
    public static IList<PSTypeName> InputTypes(CommandAst commandAst, string? parameterName)
    {
        if (commandAst.Parent is not PipelineAst pipeline || pipeline.PipelineElements.Count is 1 || pipeline.PipelineElements[0] == commandAst)
        {
            return FromParameter(commandAst, parameterName);
        }

        for (int i = 1; i < pipeline.PipelineElements.Count; i++)
        {
            if (pipeline.PipelineElements[i] != commandAst)
            {
                continue;
            }

            return Type(pipeline.PipelineElements[i - 1]);
        }

        // Should be unreachable.
        return [];

        static IList<PSTypeName> FromParameter(CommandAst commandAst, string? parameterName)
        {
            if (parameterName is null or "")
            {
                return [];
            }

            try
            {
                StaticBindingResult result = StaticParameterBinder.BindCommand(commandAst, true, [parameterName]);
                if (!result.BoundParameters.TryGetValue(parameterName, out ParameterBindingResult? parameter))
                {
                    return [];
                }

                return Type(parameter.Value);
            }
            catch
            {
                return [];
            }
        }
    }

    public static IList<PSTypeName> Type(Ast ast)
    {
        using PowerShell pwsh = PowerShell.Create(RunspaceMode.CurrentRunspace);
        return ReflectionCache.AstTypeInference.InferTypeOf(ast, pwsh, 1);
    }

    public static IReadOnlyList<PSInferredMember> Members(Any<Ast, PSTypeName[], Type[]> target)
    {
        IList<PSTypeName> types = ProcessAny(target, out LooseHandle<PowerShell> pwsh);
        using (pwsh)
        {
            return Members(
                types,
                "*",
                false,
                completionsOnly: false,
                pwsh.Value)
                .Members;
        }
    }

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target)
        => MemberCompletions(target, "*", propertiesOnly: false);

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        string wordToComplete)
        => MemberCompletions(target, wordToComplete, propertiesOnly: false);

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        bool propertiesOnly)
        => MemberCompletions(target, "*", propertiesOnly);

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        string wordToComplete,
        bool propertiesOnly)
    {
        IList<PSTypeName> types = ProcessAny(target, out LooseHandle<PowerShell> pwsh);
        using (pwsh)
        {
            (List<CompletionResult> completions, _) = Members(
                types,
                wordToComplete,
                propertiesOnly,
                completionsOnly: true,
                pwsh.Value);

            return completions;
        }
    }

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        out IReadOnlyList<PSInferredMember> members)
        => MemberCompletions(target, "*", propertiesOnly: false, out members);

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        string wordToComplete,
        out IReadOnlyList<PSInferredMember> members)
        => MemberCompletions(target, wordToComplete, propertiesOnly: false, out members);

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        bool propertiesOnly,
        out IReadOnlyList<PSInferredMember> members)
        => MemberCompletions(target, "*", propertiesOnly, out members);

    public static IReadOnlyList<CompletionResult> MemberCompletions(
        Any<Ast, PSTypeName[], Type[]> target,
        string wordToComplete,
        bool propertiesOnly,
        out IReadOnlyList<PSInferredMember> members)
    {
        IList<PSTypeName> types = ProcessAny(target, out LooseHandle<PowerShell> pwsh);
        using (pwsh)
        {
            (List<CompletionResult> completions, members) = Members(
                types,
                wordToComplete,
                propertiesOnly,
                completionsOnly: false,
                pwsh.Value);

            return completions;
        }
    }

    private static IList<PSTypeName> ProcessAny(Any<Ast, PSTypeName[], Type[]> arg, out LooseHandle<PowerShell> pwshHandle)
    {
        Any.ThrowIfNone(ref arg);
        pwshHandle = default;
        return arg switch
        {
            _ when arg.Some(out Ast ast) => ProcessAst(ast, out pwshHandle),
            _ when arg.Some(out PSTypeName[] typeNames) => typeNames,
            _ when arg.Some(out Type[] types) => types.Select(t => new PSTypeName(t)).ToArray(),
            { IsNone: true } => throw new ArgumentNullException(nameof(arg)),
            _ => Throw.Unreachable<IList<PSTypeName>>(),
        };

        static IList<PSTypeName> ProcessAst(Ast ast, out LooseHandle<PowerShell> pwshHandle)
        {
            PowerShell pwsh = PowerShell.Create(RunspaceMode.CurrentRunspace);
            pwshHandle = new(pwsh);
            return ReflectionCache.AstTypeInference.InferTypeOf(ast, pwsh, 1);
        }
    }

    internal static (List<CompletionResult> Completions, List<PSInferredMember> Members) Members(
        IList<PSTypeName> inferredTypes,
        string memberName,
        bool propertiesOnly = false,
        bool completionsOnly = false,
        PowerShell? pwsh = null)
    {
        bool ownsPwsh = false;
        if (pwsh is null)
        {
            ownsPwsh = true;
            pwsh = PowerShell.Create(RunspaceMode.CurrentRunspace);
        }

        WildcardPattern? pattern = memberName is not null or "" or "*"
            ? WildcardPattern.Get(memberName, WildcardOptions.IgnoreCase | WildcardOptions.CultureInvariant)
            : null;

        try
        {
            List<PSInferredMember>? inferredMembers = completionsOnly ? null : [];
            Func<object, bool> filter = (object value) =>
            {
                if (propertiesOnly && !ReflectionCache.CompletionCompleters.IsPropertyMember(value))
                {
                    return false;
                }

                if (pattern is not null && !pattern.IsMatch(GetMemberName(value)))
                {
                    return false;
                }

                if (!completionsOnly)
                {
                    inferredMembers!.Add(PSInferredMember.Create(value));
                }

                return true;
            };

            List<CompletionResult> results = [];
            object context = ReflectionCache.TypeInferenceContext.ctor(pwsh);
            ReflectionCache.CompletionCompleters.CompleteMemberByInferredType(
                context,
                inferredTypes,
                results,
                memberName!,
                filter,
                false,
                null,
                false,
                false);

            return (results, inferredMembers ?? []);
        }
        finally
        {
            if (ownsPwsh)
            {
                pwsh.Dispose();
            }
        }
    }

    internal static IEnumerable<PSTypeName> InferIndexType(IList<PSTypeName> inferredTypes)
    {
        foreach (PSTypeName type in inferredTypes)
        {
            if (type.Type is null)
            {
                yield return type;
                continue;
            }

            if (type.Type.IsArray)
            {
                yield return new PSTypeName(type.Type.GetElementType());
                continue;
            }

            foreach (Type iface in type.Type.GetInterfaces())
            {
                if (!iface.IsGenericType)
                {
                    continue;
                }

                Type generic = iface.GetGenericTypeDefinition();
                if (generic == typeof(IList<>))
                {
                    yield return new PSTypeName(iface.GetGenericArguments()[0]);
                    continue;
                }

                if (generic == typeof(IDictionary<,>))
                {
                    yield return new PSTypeName(iface.GetGenericArguments()[1]);
                }
            }


        }
    }

    private static string GetMemberName(object member)
    {
        return member switch
        {
            PropertyInfo property => property.Name,
            _ when IsMethodCacheEntry(member) => GetMethodCacheEntryName(member),
            _ => Throw.Unreachable<string>(),
        };
    }

    [field: MaybeNull]
    private static Func<object, bool> IsMethodCacheEntry
    {
        get
        {
            if (field is not null)
            {
                return field;
            }

            ParameterExpression member = Expression.Parameter(typeof(object), nameof(member));
            return field = Expression.Lambda<Func<object, bool>>(
                Expression.TypeIs(member, ReflectionCache.MethodCacheEntry.Type),
                [member])
                .Compile();
        }
    }

    [field: MaybeNull]
    private static Func<object, string> GetMethodCacheEntryName
    {
        get
        {
            if (field is not null)
            {
                return field;
            }

            ParameterExpression member = Expression.Parameter(typeof(object), nameof(member));
            return field = Expression.Lambda<Func<object, string>>(
                Expression.Field(
                    Expression.ArrayIndex(
                        Expression.Field(
                            Expression.Convert(member, ReflectionCache.MethodCacheEntry.Type),
                            ReflectionCache.MethodCacheEntry.methodInformationStructures),
                        Expression.Constant(0)),
                    ReflectionCache.MethodInformation.method),
                [member])
                .Compile();
        }
    }
}