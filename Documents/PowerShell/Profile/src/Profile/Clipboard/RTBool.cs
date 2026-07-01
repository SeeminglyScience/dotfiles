using System.Runtime.InteropServices;

namespace Profile.Clipboard;

[StructLayout(LayoutKind.Sequential, Pack = 0)]
public readonly struct RTBool
{
    private readonly byte _value;

    private RTBool(byte value) => _value = value;

    public static implicit operator RTBool(byte value) => new(value);

    public static implicit operator RTBool(bool value) => new(value ? (byte)1 : (byte)0);

    public static implicit operator bool(RTBool value) => value._value is not 0;

    public static implicit operator byte(RTBool value) => value._value;

    public static bool operator true(RTBool value) => (bool)value;

    public static bool operator false(RTBool value) => !(bool)value;
}
