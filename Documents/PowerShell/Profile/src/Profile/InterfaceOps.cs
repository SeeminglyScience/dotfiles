using System.Reflection;

namespace Profile;

internal delegate TResult OutCall<T, TOut, TResult>(T arg0, out TOut @out);

internal static class InterfaceOps
{
    public static OutCall<T, TOut, TResult> CreateInterfaceImplInvocation<T, TOut, TResult>(
        Type iType,
        Type implementingType,
        Type genericArg,
        string name)
    {
        MethodInfo? method = iType.GetMethod(
            name,
            BindingFlags.Static | BindingFlags.NonPublic,
            [typeof(T), typeof(TOut).MakeByRefType()]);

        if (method is null)
        {
            string parameterTypes = string.Join(
                ", ",
                typeof(T).FullName,
                typeof(TOut).MakeByRefType().FullName);

            throw new InvalidOperationException(
                $"Could not find method {iType}.{name}({parameterTypes}).");
        }

        InterfaceMapping mapping = implementingType.GetInterfaceMap(iType);
        MethodInfo? targetMethod = null;
        for (int i = 0; i < mapping.InterfaceMethods.Length; i++)
        {
            if (mapping.InterfaceMethods[i] == method)
            {
                targetMethod = mapping.TargetMethods[i];
                break;
            }
        }

        if (targetMethod is null)
        {
            string parameterTypes = string.Join(
                ", ",
                typeof(T).FullName,
                typeof(TOut).MakeByRefType().FullName);

            throw new InvalidOperationException(
                $"Could not find implementation of {iType.FullName}.{name}({parameterTypes}) in {implementingType.FullName}.");
        }

        return targetMethod.MakeGenericMethod(genericArg).CreateDelegate<OutCall<T, TOut, TResult>>();
    }
}