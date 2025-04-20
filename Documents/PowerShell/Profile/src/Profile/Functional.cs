global using static Profile.Functional;

namespace Profile;

internal static class Functional
{
    public static TResult Out<TResult, TOut>(TResult result, out TOut location)
    {
        location = default!;
        return result;
    }

    public static TResult Out<TResult, TOut>(TResult result, TOut outValue, out TOut location)
    {
        location = outValue;
        return result;
    }
}