using System.Diagnostics;

namespace Profile;

internal static class Throw
{
    // public static TResult ThrowOutOfRange()
    // {
    //     ArgumentException.
    // }
    public static TResult Unreachable<TResult>()
    {
        throw new UnreachableException();
    }
}