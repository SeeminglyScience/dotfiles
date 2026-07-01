using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;

namespace ComGenerator;

internal static class Poly
{
    public static void Assert([DoesNotReturnIf(false)] bool condition)
    {
        Debug.Assert(condition);
    }
}
