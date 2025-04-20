using System.Diagnostics.CodeAnalysis;
using System.Dynamic;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace Profile;

internal static class Format
{
    private static readonly CallSite<Func<CallSite, object?, Type, int, string>> s_typeCallSite =
        CallSite<Func<CallSite, object?, Type, int, string>>.Create(new InvokeFormatBinder<string>("Type"));

    public static string Type(Type type, int maxLength = -1) => s_typeCallSite.Target(s_typeCallSite, null, type, maxLength);

    private static readonly CallSite<Func<CallSite, object?, object?, int, string>> s_numberCallSite =
        CallSite<Func<CallSite, object?, object?, int, string>>.Create(new InvokeFormatBinder<string>("Number"));
    public static string Number(object? value, int maxLength = -1) => s_numberCallSite.Target(s_numberCallSite, null, value, maxLength);

    private static readonly CallSite<Func<CallSite, object?, MemberInfo?, int, Type?, string>> s_memberCallSite =
        CallSite<Func<CallSite, object?, MemberInfo?, int, Type?, string>>.Create(new InvokeFormatBinder<string>("Member"));
    public static string Member(MemberInfo? value, int maxLength = -1, Type? targetType = null) => s_memberCallSite.Target(s_memberCallSite, null, value, maxLength, targetType);
}

internal class InvokeFormatBinder<T> : DynamicMetaObjectBinder
{
    private static readonly Lazy<Type?> s_formatType = new(
        () =>
        {
            return AppDomain.CurrentDomain.GetAssemblies()
                .Where(a => a.GetName().Name == "ClassExplorer")
                .FirstOrDefault()
                ?.GetType("ClassExplorer.Internal._Format");
        });

    public InvokeFormatBinder(string name)
    {
        Name = name;
    }

    public string Name { get; }

    public override Type ReturnType => typeof(T);

    private static bool TryGetFormatType([NotNullWhen(true)] out Type? type)
    {
        try
        {
            if (s_formatType.Value is Type result)
            {
                type = result;
                return true;
            }

            type = null;
            return false;
        }
        catch
        {
            type = null;
            return false;
        }
    }


    public override DynamicMetaObject Bind(DynamicMetaObject target, DynamicMetaObject[] args)
    {
        if (!TryGetFormatType(out Type? formatType))
        {
            return args[0];
        }

        MethodInfo? method = formatType.GetMethod(
            Name,
            BindingFlags.Public | BindingFlags.Static,
            args.Select(a => a.LimitType).ToArray());

        if (method is null)
        {
            return new DynamicMetaObject(
                Expression.Throw(
                    Expression.New(
                        typeof(MethodInvocationException).GetConstructor(
                            [typeof(string)])!,
                        Expression.Call(
                            typeof(string).GetMethod(
                                "Format",
                                BindingFlags.Static | BindingFlags.Public,
                                [typeof(string), typeof(object), typeof(object)])!,
                            Expression.Constant("Could not find method ClassExplorer.Internal._Format.{0}({1})."),
                            Expression.Constant(Name),
                            Expression.Constant(
                                string.Join(", ", args.Select(a => a.LimitType.ToString()).ToArray()))))),
                BindingRestrictions.Empty);
        }

        return new DynamicMetaObject(
            Expression.Call(
                method,
                args.Select(a => a.Expression)),
            BindingRestrictions.Empty);
    }
}
