using System.Runtime.CompilerServices;

namespace Profile;

internal static class PointerOps
{
    public static bool TryGetNativeInt(object? value, out nint result)
    {
        return value switch
        {
            nint v => Success(v, out result),
            nuint v => Success(unchecked((nint)v), out result),
            int v => Success(v, out result),
            uint v => Success(unchecked((int)v), out result),
            long v => nint.Size is sizeof(long) ? Success(Unsafe.As<long, nint>(ref v), out result) : Fail(out result),
            ulong v => nint.Size is sizeof(long) ? Success(Unsafe.As<ulong, nint>(ref v), out result) : Fail(out result),
            INativeIntWrapper v => Success(v.ToIntPtr(), out result),
            _ => Fail(out result),
        };

        static bool Success(nint value, out nint result)
        {
            result = value;
            return true;
        }

        static bool Fail(out nint result)
        {
            result = default;
            return false;
        }
    }
}