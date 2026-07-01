using System.Diagnostics;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Management.Automation.Internal;
using System.Reflection;

namespace Profile;

public sealed class PooledConverter : PSTypeConverter
{
    public override bool CanConvertFrom(object sourceValue, Type destinationType)
    {
        if (sourceValue is PSObject pso)
        {
            sourceValue = pso.BaseObject;
        }

        return sourceValue is pooled && destinationType.IsSubclassOf(typeof(Delegate));
    }

    public override bool CanConvertTo(object sourceValue, Type destinationType)
    {
        if (sourceValue is PSObject pso)
        {
            sourceValue = pso.BaseObject;
        }

        return sourceValue is pooled && destinationType.IsSubclassOf(typeof(Delegate));
    }

    public override object ConvertFrom(
        object sourceValue,
        Type destinationType,
        IFormatProvider formatProvider,
        bool ignoreCase)
    {
        if (sourceValue is PSObject pso)
        {
            sourceValue = pso.BaseObject;
        }

        pooled pooledValue = (pooled)sourceValue;
        return CreateDelegate(pooledValue._scriptBlock, destinationType, pooledValue._dollarThis);
    }

    public override object ConvertTo(object sourceValue, Type destinationType, IFormatProvider formatProvider, bool ignoreCase)
    {
        if (sourceValue is PSObject pso)
        {
            sourceValue = pso.BaseObject;
        }

        pooled pooledValue = (pooled)sourceValue;
        return CreateDelegate(pooledValue._scriptBlock, destinationType, pooledValue._dollarThis);
    }

    private Delegate CreateDelegate(ScriptBlock scriptBlock, Type delegateType, object? dollarThis = null)
    {
        MethodInfo? invokeMethod = delegateType.GetMethod("Invoke");
        Debug.Assert(invokeMethod is not null);

        ParameterInfo[] parameters = invokeMethod.GetParameters();
        ParameterExpression[] paramExpr = new ParameterExpression[parameters.Length];
        Expression[] paramsAsArgs = new Expression[parameters.Length];
        for (int i = parameters.Length - 1; i >= 0; i--)
        {
            ParameterInfo p = parameters[i];
            ParameterExpression pExpr = Expression.Parameter(p.ParameterType, p.Name);
            paramExpr[i] = pExpr;
            if (p.ParameterType.IsValueType)
            {
                paramsAsArgs[i] = Expression.Convert(pExpr, typeof(object));
                continue;
            }

            paramsAsArgs[i] = pExpr;
        }

        ConstantExpression autoNull = Expression.Constant(AutomationNull.Value, typeof(object));
        Expression call = Expression.Call(
            null,
            ReflectionCache.PooledRunspaces.InvokeWithCachedRunspaceMethod,
            [
                Expression.Constant(ReflectionCache.ScriptBlock.Clone(scriptBlock)),
                Expression.Constant(PooledRunspaces.Instance),
                paramsAsArgs.Length is not 0 ? paramsAsArgs[0] : autoNull,
                dollarThis is null ? autoNull : Expression.Constant(dollarThis, typeof(object)),
                Expression.NewArrayInit(typeof(object), paramsAsArgs)
            ]);

        if (invokeMethod.ReturnType != typeof(void))
        {
            call = Expression.Dynamic(
                ReflectionCache.PSConvertBinder.Get(invokeMethod.ReturnType),
                invokeMethod.ReturnType,
                call);
        }

        return Expression.Lambda(delegateType, call, paramExpr).Compile();
    }
}