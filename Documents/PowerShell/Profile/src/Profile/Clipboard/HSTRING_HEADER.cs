using System.Runtime.InteropServices;

namespace Profile.Clipboard;

[StructLayout(LayoutKind.Sequential)]
public struct HSTRING_HEADER
{
    internal uint flags;

    internal uint length;

    internal uint padding1;

    internal uint padding2;

    internal nint data;
}
