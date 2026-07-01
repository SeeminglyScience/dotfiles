using System.Linq.Expressions;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;

namespace Profile;

internal static class ExtentExtensions
{
    extension(IScriptExtent extent)
    {
        public IScriptExtent CloneWithNewOffsets(int start, int end)
        {
            return s_newScriptExtent.Value(extent, start, end);
        }
    }

    private static readonly Lazy<Func<IScriptExtent, int, int, IScriptExtent>> s_newScriptExtent = new(() => CreateNewScriptExtentFunc());

    private static Func<IScriptExtent, int, int, IScriptExtent> CreateNewScriptExtentFunc()
    {
        ParameterExpression source = Expression.Parameter(typeof(IScriptExtent), nameof(source));
        ParameterExpression start = Expression.Parameter(typeof(int), nameof(start));
        ParameterExpression end = Expression.Parameter(typeof(int), nameof(end));

        const string smal = "System.Management.Automation.Language";
        Type phType = typeof(PSObject).Assembly.GetType($"{smal}.PositionHelper") ?? Throw.Unreachable<Type>();
        Type iseType = typeof(PSObject).Assembly.GetType($"{smal}.InternalScriptExtent") ?? Throw.Unreachable<Type>();
        return Expression.Lambda<Func<IScriptExtent, int, int, IScriptExtent>>(
            Expression.New(
                iseType.GetConstructor(BindTo.Instance.Any, [phType, typeof(int), typeof(int)]) ?? Throw.Unreachable<ConstructorInfo>(),
                Expression.Property(
                    Expression.Convert(source, iseType),
                    iseType.GetProperty("PositionHelper", BindTo.Instance.Any) ?? Throw.Unreachable<PropertyInfo>()),
                start,
                end),
            "CloneWithNewOffsets",
            [source, start, end])
            .Compile();
    }
}

internal static class ExtentUtils
{
    public static IScriptExtent Combine(IScriptExtent start, IScriptExtent end)
    {
        if (start == end)
        {
            return start;
        }

        return start.CloneWithNewOffsets(start.StartOffset, end.EndOffset);
    }
}