using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace Profile;

internal static class Throw
{
    // public static TResult ThrowOutOfRange<TResult>([CallerArgumentExpression()] string? paramName = null)
    // {
    //     throw new ArgumentOutOfRangeException()
    // }
    public static TResult Unreachable<TResult>()
    {
        throw new UnreachableException();
    }
}