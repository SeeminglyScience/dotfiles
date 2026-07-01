using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

internal static class VtblOps
{
    public static int GetVtblSize<T>() where T : IHasVtbl => T.GetVtblSize();
}
