using System.Globalization;
using System.Management.Automation;

namespace Profile.Links;

public readonly struct LnkConsoleColorRef
{
    private readonly uint _value;

    public int R => (int)((_value >> 0) & 0xFF);

    public int G => (int)((_value >> 8) & 0xFF);

    public int B => (int)((_value >> 16) & 0xFF);

    public LnkConsoleColorRef(uint value) => _value = value;

    public LnkConsoleColorRef(object[] args)
    {
        if (args is not [object r, object g, object b])
        {
            throw new ArgumentException(
                "Value must be three numbers, one for red, green and blue.",
                nameof(args));
        }

        _value = RgbToUInt(
            LanguagePrimitives.ConvertTo<byte>(r),
            LanguagePrimitives.ConvertTo<byte>(g),
            LanguagePrimitives.ConvertTo<byte>(b));
    }

    public static LnkConsoleColorRef FromRgb(byte r, byte g, byte b)
    {
        return new(RgbToUInt(r, g, b));
    }

    public static LnkConsoleColorRef Parse(string value)
    {
        ReadOnlySpan<char> valueSpan = value;
        if (valueSpan is ['#', ..])
        {
            valueSpan = valueSpan[1..];
        }

        if (valueSpan.Length is not 6)
        {
            goto FAIL;
        }

        ReadOnlySpan<char> color = valueSpan[..2];
        valueSpan = valueSpan[2..];
        if (!byte.TryParse(color, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out byte r))
        {
            goto FAIL;
        }

        color = valueSpan[..2];
        valueSpan = valueSpan[2..];
        if (!byte.TryParse(color, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out byte g))
        {
            goto FAIL;
        }

        if (!byte.TryParse(color, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out byte b))
        {
            goto FAIL;
        }

        throw null!;

FAIL:
        throw new ArgumentException(
            "Expected string format of '#RRGGBB' where 'R', 'G' and 'B' are the numeric values of red, green and blue in hex notation.",
            nameof(value));
    }

    private static uint RgbToUInt(byte r, byte g, byte b)
    {
        return (uint)(b << 16) | (uint)(g << 8) | r;
    }

    public override string ToString()
    {
        return $"#{R:X2}{G:X2}{B:X2}";
    }
}