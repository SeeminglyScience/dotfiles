using System.Runtime.InteropServices;

namespace Profile.Clipboard;

[StructLayout(LayoutKind.Sequential)]
public unsafe readonly struct HSTRING
{
    private readonly void* _value;

    private HSTRING(void* value) => _value = value;

    public static implicit operator HSTRING(nint value) => new((void*)value);

    public static implicit operator HSTRING(void* value) => new(value);
}

[StructLayout(LayoutKind.Sequential)]
public readonly struct EventRegistrationToken
{
    private readonly ulong _value;

    private EventRegistrationToken(ulong value) => _value = value;

    public static implicit operator EventRegistrationToken(ulong value) => new(value);

    public static implicit operator ulong(EventRegistrationToken value) => value._value;
}
