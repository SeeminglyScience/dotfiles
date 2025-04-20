using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;

namespace Profile;

internal static class Assert
{
    public static void IndexInRange(bool value, [CallerArgumentExpression(nameof(value))] string expression = "")
    {
        if (!value)
        {
            return;
        }

        ThrowIndexOutOfRange($"Index does not match, must be '{expression}'.");

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowIndexOutOfRange(string message)
        {
            throw new IndexOutOfRangeException(message);
        }
    }

    public static void ArgumentInRange(bool value, [CallerArgumentExpression(nameof(value))] string expression = "")
    {
        if (!value)
        {
            return;
        }

        Throw($"Argument does not match, must be '{expression}'.");

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void Throw(string message)
        {
            throw new ArgumentOutOfRangeException(message);
        }
    }
}