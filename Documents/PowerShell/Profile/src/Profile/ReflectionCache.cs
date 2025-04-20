using System.Diagnostics.CodeAnalysis;
using System.Dynamic;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Runtime.CompilerServices;
using Profile.Commands;
using SMA = System.Management.Automation;

using static System.Linq.Expressions.Expression;

namespace Profile;

internal static class ExpressionExtensions
{
    public static Expression Convert<T>(this Expression target)
    {
        return Expression.Convert(target, typeof(T));
    }

    public static Expression Convert(this Expression target, Type type)
    {
        return Expression.Convert(target, type);
    }
}

internal enum ScriptBlockErrorHandlingBehavior
{
    WriteToCurrentErrorPipe = 1,
    WriteToExternalErrorPipe = 2,
    SwallowErrors = 3,
}

internal static class ReflectionCache
{
    private static ParameterExpression Param<T>(
        out ParameterExpression result,
        [CallerArgumentExpression(nameof(result))] string name = "")
    {
        return Param(typeof(T), out result, name);
    }

    private static ParameterExpression Param(
        Type type,
        out ParameterExpression result,
        [CallerArgumentExpression(nameof(result))] string name = "")
    {
        if (name is null)
        {
            return result = Parameter(type);
        }

        int i = name.LastIndexOf(' ');
        return result = Parameter(
            type,
            i is -1 || (i + 1) == name.Length ? name : name[(i + 1)..]);
    }

    public static Type GetSmaType(string name)
    {
        return GetTypeOrThrow($"System.Management.Automation.{name}");
    }

    private static Type GetTypeOrThrow(string fullName)
    {
        Type? type = typeof(PSObject).Assembly.GetType(fullName);

        if (type is null)
        {
            ThrowTypeNotFound(fullName);
            return null;
        }

        return type;

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowTypeNotFound(string fullName)
        {
            throw new InvalidOperationException($"The type '{fullName}' could not be found");
        }
    }

    private static PropertyInfo GetPropertyOrThrow(Type type, string name, BindingFlags flags)
    {
        PropertyInfo? property = type.GetProperty(name, flags);
        if (property is not null)
        {
            return property;
        }

        ThrowPropertyNotFound(type, name);
        return null;

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowPropertyNotFound(Type type, string name)
        {
            throw new InvalidOperationException($"The property '{name}' could not be found on type '{type.FullName}'.");
        }
    }

    private static FieldInfo GetFieldOrThrow(Type type, string name, BindingFlags flags)
    {
        FieldInfo? field = type.GetField(name, flags);
        if (field is not null)
        {
            return field;
        }

        ThrowFieldNotFound(type, name);
        return null;

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowFieldNotFound(Type type, string name)
        {
            throw new InvalidOperationException($"The field '{name}' could not be found on type '{type.FullName}'.");
        }
    }

    private static MethodInfo GetMethodOrThrow<T>(string name, BindingFlags flags, Type[] parameterTypes)
    {
        return GetMethodOrThrow(
            typeof(T),
            name,
            flags,
            parameterTypes);
    }

    private static MethodInfo GetMethodOrThrow(Type type, string name, BindingFlags flags, Type[] parameterTypes)
    {
        MethodInfo? method = type.GetMethod(
            name,
            flags,
            parameterTypes);

        if (method is not null)
        {
            return method;
        }

        ThrowMethodNotFound(type, name, parameterTypes);
        return null;

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowMethodNotFound(Type type, string name, Type[] parameterTypes)
        {
            throw new InvalidOperationException(
                $"The method '{type.FullName}.{name}({string.Join(", ", parameterTypes.Select(t => t.Name))})' could not be found.");
        }
    }

    private static ConstructorInfo GetCtorOrThrow(Type type, BindingFlags flags, Type[] parameterTypes)
    {
        ConstructorInfo? ctor = type.GetConstructor(
            flags,
            parameterTypes);

        if (ctor is not null)
        {
            return ctor;
        }

        ThrowCtorNotFound(type, parameterTypes);
        return null;

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowCtorNotFound(Type type, Type[] parameterTypes)
        {
            throw new InvalidOperationException(
                $"The ctor 'new {type.FullName}({string.Join(", ", parameterTypes.Select(t => t.Name))})' could not be found.");
        }
    }

    public static class PooledRunspaces
    {
        [field: MaybeNull]
        public static MethodInfo InvokeWithCachedRunspaceMethod => field ??= GetMethodOrThrow(
            typeof(Profile.PooledRunspaces),
            nameof(Profile.PooledRunspaces.InvokeWithCachedRunspace),
            BindTo.Static.Any,
            [typeof(SMA.ScriptBlock), typeof(Profile.PooledRunspaces), typeof(object), typeof(object), typeof(object[])]);
    }

    public static class MshCommandRuntime
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("MshCommandRuntime");

        [field: MaybeNull]
        public static Func<ICommandRuntime, object> GetOutputPipe
            => field ??= Lambda<Func<ICommandRuntime, object>>(
                Call(
                    Param<ICommandRuntime>(out ParameterExpression runtime)
                        .Convert(Type),
                    GetMethodOrThrow(Type, "get_OutputPipe", BindTo.Instance.Any, [])),
                $"{nameof(ReflectionCache)}.{nameof(MshCommandRuntime)}.{nameof(GetOutputPipe)}",
                [runtime])
                .Compile();
    }

    public static class PSScriptCmdlet
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("PSScriptCmdlet");

        [field: MaybeNull]
        public static FieldInfo _functionContext
            => field ??= GetFieldOrThrow(Type, "_functionContext", BindTo.Instance.NonPublic);

        [field: MaybeNull]
        public static Func<PSCmdlet, bool> Is
            => field ??= Lambda<Func<PSCmdlet, bool>>(
                TypeIs(
                    Param<PSCmdlet>(out ParameterExpression cmdlet),
                    Type),
                $"{nameof(ReflectionCache)}.{nameof(PSScriptCmdlet)}.{nameof(Is)}",
                [cmdlet])
                .Compile();

        [field: MaybeNull]
        public static Func<PSCmdlet, object> GetOutputPipe =>
            field ??= Lambda<Func<PSCmdlet, object>>(
                Field(
                    Field(
                        Convert(
                            Param<PSCmdlet>(out ParameterExpression cmdlet),
                            Type),
                        _functionContext),
                    FunctionContext._outputPipe),
                $"{nameof(ReflectionCache)}.{nameof(PSScriptCmdlet)}.{nameof(GetOutputPipe)}",
                [cmdlet])
                .Compile();
    }

    public static class ExecutionContext
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("ExecutionContext");
    }

    public static class Pipe
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("Internal.Pipe");
    }

    public static class ScriptInfo
    {
        [field: MaybeNull]
        public static Func<string, SMA.ScriptBlock, object, SMA.ScriptInfo> ctor
            => field ??= Lambda<Func<string, SMA.ScriptBlock, object, SMA.ScriptInfo>>(
                New(
                    GetCtorOrThrow(
                        typeof(SMA.ScriptInfo),
                        BindTo.Instance.NonPublic,
                        [
                            typeof(string),
                            typeof(SMA.ScriptBlock),
                            ExecutionContext.Type,
                        ]),
                    Param<string>(out ParameterExpression name),
                    Param<SMA.ScriptBlock>(out ParameterExpression script),
                    Convert(Param<object>(out ParameterExpression context), ExecutionContext.Type)),
                $"{nameof(ReflectionCache)}.{nameof(ScriptInfo)}.{nameof(ctor)}",
                [name, script, context])
                .Compile();
    }

    public static class ScriptBlock
    {
        public static class ErrorHandlingBehavior
        {
            [field: MaybeNull]
            public static Type Type => field ??= GetSmaType("ScriptBlock+ErrorHandlingBehavior");
        }

        public static class LanguageMode
        {
            [field: MaybeNull]
            public static Func<SMA.ScriptBlock, PSLanguageMode?> Get
                => field ??= GetMethodOrThrow<SMA.ScriptBlock>(
                    "get_LanguageMode",
                    BindTo.Instance.NonPublic,
                    [])
                    .CreateDelegate<Func<SMA.ScriptBlock, PSLanguageMode?>>();

            [field: MaybeNull]
            public static Action<SMA.ScriptBlock, PSLanguageMode?> Set
                => field ??= GetMethodOrThrow<SMA.ScriptBlock>(
                    "set_LanguageMode",
                    BindTo.Instance.NonPublic,
                    [typeof(PSLanguageMode?)])
                    .CreateDelegate<Action<SMA.ScriptBlock, PSLanguageMode?>>();
        }

        [field: MaybeNull]
        public static Func<SMA.ScriptBlock, SMA.ScriptBlock> Clone => field ??= GetMethodOrThrow(
            typeof(SMA.ScriptBlock),
            "Clone",
            BindTo.Instance.Any,
            [])
            .CreateDelegate<Func<SMA.ScriptBlock, SMA.ScriptBlock>>();

        [field: MaybeNull]
        public static Func<SMA.ScriptBlock, object?, object?, object?[]?, object?> InvokeAsDelegateHelper
            => field ??= GetMethodOrThrow<SMA.ScriptBlock>(
                nameof(InvokeAsDelegateHelper),
                BindTo.Instance.NonPublic,
                [typeof(object), typeof(object), typeof(object[])])
                .CreateDelegate<Func<SMA.ScriptBlock, object?, object?, object?[]?, object?>>();

        [field: MaybeNull]
        public static MethodInfo InvokeAsDelegateHelperMethod => field ??= GetMethodOrThrow(
            typeof(ScriptBlock),
            "InvokeAsDelegateHelper",
            BindTo.Instance.NonPublic,
            [typeof(object), typeof(object), typeof(object[])]);

        public delegate void InvokeWithPipeSignature(
            SMA.ScriptBlock scriptBlock,
            bool useLocalScope,
            ScriptBlockErrorHandlingBehavior errorHandlingBehavior,
            object? dollarUnder,
            object? input,
            object? scriptThis,
            object outputPipe,
            InvocationInfo invocationInfo,
            bool propagateAllExceptionsToTop = false,
            List<PSVariable>? variablesToDefine = null,
            Dictionary<string, SMA.ScriptBlock>? functionsToDefine = null,
            object?[]? args = null);

        [field: MaybeNull]
        public static InvokeWithPipeSignature InvokeWithPipe
            => field ??= Lambda<InvokeWithPipeSignature>(
                Call(
                    Param<SMA.ScriptBlock>(out ParameterExpression sb),
                    GetMethodOrThrow(
                        typeof(SMA.ScriptBlock),
                        "InvokeWithPipe",
                        BindTo.Instance.NonPublic,
                        [
                            typeof(bool),
                            ErrorHandlingBehavior.Type,
                            typeof(object),
                            typeof(object),
                            typeof(object),
                            Pipe.Type,
                            typeof(InvocationInfo),
                            typeof(bool),
                            typeof(List<PSVariable>),
                            typeof(Dictionary<string, SMA.ScriptBlock>),
                            typeof(object[])
                        ]),
                    [
                        Param<bool>(out ParameterExpression useLocalScope),
                        Param<ScriptBlockErrorHandlingBehavior>(out ParameterExpression ehb)
                            .Convert<int>()
                            .Convert(ErrorHandlingBehavior.Type),
                        Param<object>(out ParameterExpression dollarUnder),
                        Param<object>(out ParameterExpression input),
                        Param<object>(out ParameterExpression scriptThis),
                        Param<object>(out ParameterExpression outputPipe)
                            .Convert(Pipe.Type),
                        Param<InvocationInfo>(out ParameterExpression invocationInfo),
                        Param<bool>(out ParameterExpression propagateExceptions),
                        Param<List<PSVariable>>(out ParameterExpression variables),
                        Param<Dictionary<string, SMA.ScriptBlock>>(out ParameterExpression functions),
                        Param<object[]>(out ParameterExpression args),
                    ]),
                $"{nameof(ReflectionCache)}.{nameof(ScriptBlock)}.{nameof(InvokeWithPipe)}",
                [
                    sb, useLocalScope, ehb, dollarUnder, input,
                    scriptThis, outputPipe, invocationInfo,
                    propagateExceptions, variables, functions, args,
                ])
                .Compile();
    }

    public static class LocalPipeline
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("Runspaces.LocalPipeline");

        [field: MaybeNull]
        public static Func<object> GetExecutionContextFromTLS
            => field ??= GetMethodOrThrow(
                Type,
                "GetExecutionContextFromTLS",
                BindTo.Static.Any,
                [])
                .CreateDelegate<Func<object>>();
    }

    public static class FunctionContext
    {
        [field: MaybeNull]
        private static Type Type => field ??= GetSmaType("Language.FunctionContext");

        [field: MaybeNull]
        public static FieldInfo _outputPipe
            => field ??= GetFieldOrThrow(Type, "_outputPipe", BindTo.Instance.NonPublic);
    }

    public static class PSMethodInvocationConstraints
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("PSMethodInvocationConstraints");
    }

    public static class PSConvertBinder
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("Language.PSConvertBinder");

        [field: MaybeNull]
        public static Func<Type, ConvertBinder> Get
            => field ??= GetMethodOrThrow(Type, "Get", BindTo.Static.Any, [typeof(Type)])
                .CreateDelegate<Func<Type, ConvertBinder>>();
    }

    public static class PSGetIndexBinder
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("Language.PSGetIndexBinder");

        [field: MaybeNull]
        public static Func<int, bool, GetIndexBinder> Get
            => field ??= Lambda<Func<int, bool, GetIndexBinder>>(
                Call(
                    instance: null,
                    GetMethodOrThrow(
                        Type,
                        "Get",
                        BindTo.Static.Any,
                        [typeof(int), PSMethodInvocationConstraints.Type, typeof(bool)]),
                    [
                        Param<int>(out ParameterExpression argCount),
                        Constant(null, PSMethodInvocationConstraints.Type),
                        Param<bool>(out ParameterExpression allowSlicing),
                    ]),
                $"{nameof(ReflectionCache)}.{nameof(PSGetIndexBinder)}.{nameof(Get)}",
                [argCount, allowSlicing])
                .Compile();
    }

    public static class PSGetMemberBinder
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("Language.PSGetMemberBinder");

        [field: MaybeNull]
        public static Func<string, bool, GetMemberBinder> Get
            => field ??= Lambda<Func<string, bool, GetMemberBinder>>(
                Call(
                    instance: null,
                    GetMethodOrThrow(
                        Type,
                        "Get",
                        BindTo.Static.Any,
                        [typeof(string), typeof(Type), typeof(bool)]),
                    [
                        Param<string>(out ParameterExpression memberName),
                        Constant(null, typeof(Type)),
                        Param<bool>(out ParameterExpression isStatic),
                    ]),
                $"{nameof(ReflectionCache)}.{nameof(PSGetMemberBinder)}.{nameof(Get)}",
                [memberName, isStatic])
                .Compile();
    }

    public static class MethodCacheEntry
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("DotNetAdapter+MethodCacheEntry");

        [field: MaybeNull]
        public static FieldInfo methodInformationStructures => field ??= GetFieldOrThrow(
            Type,
            "methodInformationStructures",
            BindTo.Instance.Any);
    }

    public static class MethodInformation
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("MethodInformation");

        [field: MaybeNull]
        public static FieldInfo method => field ??= GetFieldOrThrow(
            Type,
            "method",
            BindTo.Instance.Any);
    }

    public static class TypeInferenceRuntimePermissions
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("TypeInferenceRuntimePermissions");
    }

    public static class AstTypeInference
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("AstTypeInference");

        [field: MaybeNull]
        public static Func<Ast, PowerShell, int, IList<PSTypeName>> InferTypeOf
            => field ??= Lambda<Func<Ast, PowerShell, int, IList<PSTypeName>>>(
                Call(
                    instance: null,
                    GetMethodOrThrow(
                        Type,
                        nameof(InferTypeOf),
                        BindTo.Static.Any,
                        [typeof(Ast), typeof(PowerShell), TypeInferenceRuntimePermissions.Type]),
                    [
                        Param<Ast>(out ParameterExpression ast),
                        Param<PowerShell>(out ParameterExpression powerShell),
                        Convert(
                            Param<int>(out ParameterExpression evalPermissions),
                            TypeInferenceRuntimePermissions.Type),
                    ]),
                $"{nameof(ReflectionCache)}.{nameof(AstTypeInference)}.{nameof(InferTypeOf)}",
                [ast, powerShell, evalPermissions])
                .Compile();
    }

    public static class TypeInferenceContext
    {
        [field: MaybeNull]
        public static Type Type => field ??= GetSmaType("TypeInferenceContext");

        [field: MaybeNull]
        public static Func<PowerShell, object> ctor
            => field ??= Lambda<Func<PowerShell, object>>(
                New(
                    GetCtorOrThrow(Type, BindTo.Instance.Any, [typeof(PowerShell)]),
                    [Param<PowerShell>(out ParameterExpression powerShell)]),
                $"{nameof(ReflectionCache)}.{nameof(TypeInferenceContext)}.{nameof(ctor)}",
                [powerShell])
                .Compile();
    }

    public static class CompletionCompleters
    {
        public delegate void CompleteMemberByInferredTypeSignature(
            object context,
            IEnumerable<PSTypeName> inferredTypes,
            List<CompletionResult> results,
            string memberName,
            Func<object, bool> filter,
            bool isStatic,
            HashSet<string>? excludedMembers,
            bool addMethodParenthesis,
            bool ignoreTypesWithoutDefaultConstructor);

        [field: MaybeNull]
        public static CompleteMemberByInferredTypeSignature CompleteMemberByInferredType
            => field ??= Lambda<CompleteMemberByInferredTypeSignature>(
                Call(
                    instance: null,
                    GetMethodOrThrow(
                        typeof(SMA.CompletionCompleters),
                        nameof(CompleteMemberByInferredType),
                        BindTo.Static.Any,
                        [
                            TypeInferenceContext.Type,
                            typeof(IEnumerable<PSTypeName>),
                            typeof(List<CompletionResult>),
                            typeof(string),
                            typeof(Func<object, bool>),
                            typeof(bool),
                            typeof(HashSet<string>),
                            typeof(bool),
                            typeof(bool),
                        ]),
                    [
                        Convert(Param<object>(out ParameterExpression context), TypeInferenceContext.Type),
                        Param<IEnumerable<PSTypeName>>(out ParameterExpression inferredTypes),
                        Param<List<CompletionResult>>(out ParameterExpression results),
                        Param<string>(out ParameterExpression memberName),
                        Param<Func<object, bool>>(out ParameterExpression filter),
                        Param<bool>(out ParameterExpression isStatic),
                        Param<HashSet<string>>(out ParameterExpression excludedMembers),
                        Param<bool>(out ParameterExpression addMethodParenthesis),
                        Param<bool>(out ParameterExpression ignoreTypesWithoutDefaultConstructor),
                    ]),
                $"{nameof(ReflectionCache)}.{nameof(CompletionCompleters)}.{nameof(CompleteMemberByInferredType)}",
                [
                    context,
                    inferredTypes,
                    results,
                    memberName,
                    filter,
                    isStatic,
                    excludedMembers,
                    addMethodParenthesis,
                    ignoreTypesWithoutDefaultConstructor,
                ])
                .Compile();

        [field: MaybeNull]
        public static Func<object, bool> IsPropertyMember => field ??= GetMethodOrThrow(
            typeof(SMA.CompletionCompleters),
            nameof(IsPropertyMember),
            BindTo.Static.Any,
            [typeof(object)])
            .CreateDelegate<Func<object, bool>>();
    }
}
