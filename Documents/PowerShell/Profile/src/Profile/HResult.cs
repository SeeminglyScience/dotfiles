using System.ComponentModel;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Management.Automation;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Text;

namespace Profile;

public enum HRSeverity : byte
{
    Success = 0b00,
    Informational = 0b01,
    Warning = 0b10,
    Error = 0b11,
}

public struct HResult : IBinaryInteger<HResult>
{
    private uint _value;

    private const uint SeverityMask = 0b11_0_0_000000000000_0000000000000000;

    private const uint CustomerMask = 0b00_1_0_000000000000_0000000000000000;

    private const uint ReservedMask = 0b00_0_1_000000000000_0000000000000000;

    private const uint FacilityMask = 0b00_0_0_111111111111_0000000000000000;

    private const uint CodeMask = 0b00_0_0_000000000000_1111111111111111;

    private HResult(uint value) => _value = value;

    public static implicit operator HResult(uint value) => new(value);

    public static implicit operator HResult(int value) => new((uint)value);

    public static implicit operator uint(HResult value) => value._value;

    public static implicit operator int(HResult value) => (int)value._value;

    public static HResult operator &(HResult left, HResult right) => left._value & right._value;

    public static HResult operator |(HResult left, HResult right) => left._value | right._value;

    public static HResult operator ^(HResult left, HResult right) => left._value ^ right._value;

    public static HResult operator ~(HResult value) => ~value._value;

    public static bool operator >(HResult left, HResult right) => left._value > right._value;

    public static bool operator >=(HResult left, HResult right) => left._value >= right._value;

    public static bool operator <(HResult left, HResult right) => left._value < right._value;

    public static bool operator <=(HResult left, HResult right) => left._value <= right._value;

    public static HResult operator %(HResult left, HResult right) => left._value % right._value;

    public static HResult operator +(HResult left, HResult right) => left._value + right._value;

    public static HResult operator --(HResult value) => value._value--;

    public static HResult operator /(HResult left, HResult right) => left._value / right._value;

    public static bool operator ==(HResult left, HResult right) => left._value == right._value;

    public static bool operator ==(HResult left, int right) => left._value == right;

    public static bool operator ==(HResult left, uint right) => left._value == right;

    public static bool operator !=(HResult left, HResult right) => left._value != right._value;

    public static bool operator !=(HResult left, int right) => left._value != right;

    public static bool operator !=(HResult left, uint right) => left._value != right;

    public static HResult operator ++(HResult value) => value._value++;

    public static HResult operator *(HResult left, HResult right) => left._value * right._value;

    public static HResult operator -(HResult left, HResult right) => left._value - right._value;

    public static HResult operator -(HResult value) => -(int)value._value;

    public static HResult operator +(HResult value) => +(int)value._value;

    public static HResult operator <<(HResult value, int shiftAmount) => value._value << shiftAmount;

    public static HResult operator >>(HResult value, int shiftAmount) => value._value >> shiftAmount;

    public static HResult operator >>>(HResult value, int shiftAmount) => value._value >>> shiftAmount;

    public HRSeverity Severity
    {
        get => (HRSeverity)((_value >> 30) & 0b11);
        set => _value = (_value & ~SeverityMask) | (((uint)value & 0b11) << 30);
    }

    public bool Customer
    {
        get => (_value & CustomerMask) is not 0;
        set => _value = value ? _value | CustomerMask : _value & ~CustomerMask;
    }

    public bool Reserved
    {
        get => (_value & ReservedMask) is not 0;
        set => _value = value ? _value | ReservedMask : _value & ~ReservedMask;
    }

    public HRFacility Facility
    {
        get => (HRFacility)((_value >> 16) & 0b111111111111);
        set => _value = (_value & ~FacilityMask) | (((uint)value << 16) & FacilityMask);
    }

    public uint Code
    {
        get => _value & CodeMask;
        set => _value = (_value & ~CodeMask) | (value & CodeMask);
    }

    internal bool Success => _value is not 0;

    public ErrorCodeInfo[] Info => ErrorCodeInfo.GetInfo(_value);

    public void AssertSuccess()
    {
        if (Success)
        {
            return;
        }

        DoThrow((int)_value);

        [MethodImpl(MethodImplOptions.NoInlining)]
        static void DoThrow(int value)
        {
            throw new Win32Exception(value);
        }
    }

    public string ToDisplayString()
    {
        string fnStyle = PSStyle.Instance.Formatting.TableHeader;
        string reset = PSStyle.Instance.Reset;
        StringBuilder text = new();

        StringBuilder AddFieldName(string name)
        {
            return text.AppendFormat("{0}{1, -9}:{2} ", fnStyle, name, reset);
        }

        AddFieldName("Hex").AppendLine(Format.Number($"0x{_value:X8}"));
        AddFieldName("Unsigned").AppendLine(Format.Number(_value));
        AddFieldName("Signed").AppendLine(Format.Number((int)_value));
        AddFieldName("Severity").AppendLine(Severity switch
        {
            HRSeverity.Error => $"{PSStyle.Instance.Foreground.Red}Error{reset}",
            HRSeverity.Informational => $"{PSStyle.Instance.Foreground.Green}Informational{reset}",
            HRSeverity.Success => $"{PSStyle.Instance.Foreground.BrightGreen}Success{reset}",
            HRSeverity.Warning => $"{PSStyle.Instance.Foreground.Yellow}Warning{reset}",
            _ => "?"
        });

        AddFieldName("Customer").AppendLine(Format.FancyBool(Customer));
        AddFieldName("Reserved").AppendLine(Format.FancyBool(Reserved));
        AddFieldName("Facility").AppendLine(Facility switch
        {
            _ when int.TryParse(Facility.ToString(), out int asInt) => $"{Format.Number($"0x{asInt:X3}")} ({Format.Number(asInt)})",
            _ => Format.EnumString(Facility),
        });

        AddFieldName("Code").AppendLine(Format.Number($"{Format.Number($"0x{Code:X4}")} ({Format.Number(Code)})"));
        int i = 1;
        const int MaxInfos = 6;
        foreach (ErrorCodeInfo info in Info)
        {
            if (i >= MaxInfos)
            {
                text.AppendLine().Append("(...)");
                break;
            }

            text.AppendLine()
                .Append(Format.String(info.Source))
                .Append(" - ")
                .AppendLine(Format.Variable(info.Name));

            if (info.Description is not null and not [])
            {
                text.AppendLine(info.Description);
            }

            i++;
        }

        return text.ToString().Trim();
    }

    public int CompareTo(object? obj) => obj switch
    {
        null => 1,
        HResult value => CompareTo(value),
        uint value => _value.CompareTo(value),
        int value => ((int)_value).CompareTo(value),
        _ => throw new ArgumentException("Argument must be HResult, uint, or int.", nameof(obj)),
    };

    public int CompareTo(HResult other) => _value.CompareTo(other._value);

    public bool Equals(HResult other) => _value == other._value;

    public override bool Equals(object? other) => other switch
    {
        null => false,
        HResult value => Equals(value),
        uint value => _value == value,
        int value => _value == value,
        _ => false,
    };

    public override int GetHashCode() => _value.GetHashCode();

    public string ToString(string? format, IFormatProvider? formatProvider) => _value.ToString("X8");

    static HResult INumberBase<HResult>.One => NumberBase<uint>.One;

    static int INumberBase<HResult>.Radix => NumberBase<uint>.Radix;

    static HResult INumberBase<HResult>.Zero => NumberBase<uint>.Zero;

    static HResult IAdditiveIdentity<HResult, HResult>.AdditiveIdentity => AdditiveIdentityProxy<uint>.AdditiveIdentity;

    static HResult IMultiplicativeIdentity<HResult, HResult>.MultiplicativeIdentity => MultiplicativeIdentityProxy<uint>.MultiplicativeIdentity;

    int IBinaryInteger<HResult>.GetByteCount() => BinaryInteger<uint>.GetByteCount(_value);

    int IBinaryInteger<HResult>.GetShortestBitLength() => BinaryInteger<uint>.GetShortestBitLength(_value);

    static HResult IBinaryInteger<HResult>.PopCount(HResult value) => BinaryInteger<uint>.PopCount(value._value);

    static HResult IBinaryInteger<HResult>.TrailingZeroCount(HResult value) => BinaryInteger<uint>.TrailingZeroCount(value._value);

    static bool IBinaryInteger<HResult>.TryReadBigEndian(ReadOnlySpan<byte> source, bool isUnsigned, out HResult value)
    {
        Unsafe.SkipInit(out value);
        return BinaryInteger<uint>.TryReadBigEndian(source, isUnsigned, out Unsafe.As<HResult, uint>(ref value));
    }

    static bool IBinaryInteger<HResult>.TryReadLittleEndian(ReadOnlySpan<byte> source, bool isUnsigned, out HResult value)
    {
        Unsafe.SkipInit(out value);
        return BinaryInteger<uint>.TryReadLittleEndian(source, isUnsigned, out Unsafe.As<HResult, uint>(ref value));
    }

    bool IBinaryInteger<HResult>.TryWriteBigEndian(Span<byte> destination, out int bytesWritten) => BinaryInteger<uint>.TryWriteBigEndian(_value, destination, out bytesWritten);

    bool IBinaryInteger<HResult>.TryWriteLittleEndian(Span<byte> destination, out int bytesWritten) => BinaryInteger<uint>.TryWriteLittleEndian(_value, destination, out bytesWritten);

    static bool IBinaryNumber<HResult>.IsPow2(HResult value) => BinaryNumber<uint>.IsPow2(value._value);

    static HResult IBinaryNumber<HResult>.Log2(HResult value) => BinaryNumber<uint>.Log2(value._value);

    static HResult INumberBase<HResult>.Abs(HResult value) => NumberBase<uint>.Abs(value._value);

    static bool INumberBase<HResult>.IsCanonical(HResult value) => NumberBase<uint>.IsCanonical(value._value);

    static bool INumberBase<HResult>.IsComplexNumber(HResult value) => NumberBase<uint>.IsComplexNumber(value._value);

    static bool INumberBase<HResult>.IsEvenInteger(HResult value) => NumberBase<uint>.IsEvenInteger(value._value);

    static bool INumberBase<HResult>.IsFinite(HResult value) => NumberBase<uint>.IsFinite(value._value);

    static bool INumberBase<HResult>.IsImaginaryNumber(HResult value) => NumberBase<uint>.IsImaginaryNumber(value._value);

    static bool INumberBase<HResult>.IsInfinity(HResult value) => NumberBase<uint>.IsInfinity(value._value);

    static bool INumberBase<HResult>.IsInteger(HResult value) => NumberBase<uint>.IsInteger(value._value);

    static bool INumberBase<HResult>.IsNaN(HResult value) => NumberBase<uint>.IsNaN(value._value);

    static bool INumberBase<HResult>.IsNegative(HResult value) => NumberBase<uint>.IsNegative(value._value);

    static bool INumberBase<HResult>.IsNegativeInfinity(HResult value) => NumberBase<uint>.IsNegativeInfinity(value._value);

    static bool INumberBase<HResult>.IsNormal(HResult value) => NumberBase<uint>.IsNormal(value._value);

    static bool INumberBase<HResult>.IsOddInteger(HResult value) => NumberBase<uint>.IsOddInteger(value._value);

    static bool INumberBase<HResult>.IsPositive(HResult value) => NumberBase<uint>.IsPositive(value._value);

    static bool INumberBase<HResult>.IsPositiveInfinity(HResult value) => NumberBase<uint>.IsPositiveInfinity(value._value);

    static bool INumberBase<HResult>.IsRealNumber(HResult value) => NumberBase<uint>.IsRealNumber(value._value);

    static bool INumberBase<HResult>.IsSubnormal(HResult value) => NumberBase<uint>.IsSubnormal(value._value);

    static bool INumberBase<HResult>.IsZero(HResult value) => NumberBase<uint>.IsZero(value._value);

    static HResult INumberBase<HResult>.MaxMagnitude(HResult x, HResult y) => NumberBase<uint>.MaxMagnitude(x._value, y._value);

    static HResult INumberBase<HResult>.MaxMagnitudeNumber(HResult x, HResult y) => NumberBase<uint>.MaxMagnitudeNumber(x._value, y._value);

    static HResult INumberBase<HResult>.MinMagnitude(HResult x, HResult y) => NumberBase<uint>.MinMagnitude(x._value, y._value);

    static HResult INumberBase<HResult>.MinMagnitudeNumber(HResult x, HResult y) => NumberBase<uint>.MinMagnitudeNumber(x._value, y._value);

    static bool INumberBase<HResult>.TryConvertFromChecked<TOther>(TOther value, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<uint>.TryConvertFromChecked(value, out Unsafe.As<HResult, uint>(ref result));
    }

    static bool INumberBase<HResult>.TryConvertFromSaturating<TOther>(TOther value, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<uint>.TryConvertFromSaturating(value, out Unsafe.As<HResult, uint>(ref result));
    }

    static bool INumberBase<HResult>.TryConvertFromTruncating<TOther>(TOther value, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<uint>.TryConvertFromTruncating(value, out Unsafe.As<HResult, uint>(ref result));
    }

    static bool INumberBase<HResult>.TryConvertToChecked<TOther>(HResult value, [MaybeNullWhen(false)] out TOther result) => NumberBase<uint>.TryConvertToChecked(value._value, out result);

    static bool INumberBase<HResult>.TryConvertToSaturating<TOther>(HResult value, [MaybeNullWhen(false)] out TOther result) => NumberBase<uint>.TryConvertToSaturating(value._value, out result);

    static bool INumberBase<HResult>.TryConvertToTruncating<TOther>(HResult value, [MaybeNullWhen(false)] out TOther result) => NumberBase<uint>.TryConvertToTruncating(value._value, out result);

    static HResult INumberBase<HResult>.Parse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider) => NumberBase<uint>.Parse(s, style, provider);

    static HResult INumberBase<HResult>.Parse(string s, NumberStyles style, IFormatProvider? provider) => NumberBase<uint>.Parse(s, style, provider);

    static bool INumberBase<HResult>.TryParse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<uint>.TryParse(s, style, provider, out Unsafe.As<HResult, uint>(ref result));
    }

    static bool INumberBase<HResult>.TryParse([NotNullWhen(true)] string? s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<uint>.TryParse(s, style, provider, out Unsafe.As<HResult, uint>(ref result));
    }

    bool ISpanFormattable.TryFormat(Span<char> destination, out int charsWritten, ReadOnlySpan<char> format, IFormatProvider? provider) => _value.TryFormat(destination, out charsWritten, format, provider);

    static HResult ISpanParsable<HResult>.Parse(ReadOnlySpan<char> s, IFormatProvider? provider) => uint.Parse(s, provider);

    static HResult IParsable<HResult>.Parse(string s, IFormatProvider? provider) => uint.Parse(s, provider);

    static bool ISpanParsable<HResult>.TryParse(ReadOnlySpan<char> s, IFormatProvider? provider, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return uint.TryParse(s, provider, out Unsafe.As<HResult, uint>(ref result));
    }

    static bool IParsable<HResult>.TryParse([NotNullWhen(true)] string? s, IFormatProvider? provider, [MaybeNullWhen(false)] out HResult result)
    {
        Unsafe.SkipInit(out result);
        return uint.TryParse(s, provider, out Unsafe.As<HResult, uint>(ref result));
    }
}

public enum HRFacility : ushort
{
    None = 0,
    Rpc = 1,
    Dispatch = 2,
    Storage = 3,
    Itf = 4,
    Win32 = 7,
    Windows = 8,
    Sspi = 9,
    Security = 9,
    Control = 10,
    Cert = 11,
    Internet = 12,
    MediaServer = 13,
    Msmq = 14,
    SetupApi = 15,
    SCard = 16,
    Complus = 17,
    Aaf = 18,
    Urt = 19,
    Acs = 20,
    DPlay = 21,
    Umi = 22,
    Sxs = 23,
    WindowsCe = 24,
    Http = 25,
    UserModeCommonLog = 26,
    Wer = 27,
    UserModeFilterManager = 31,
    Backgroundcopy = 32,
    Configuration = 33,
    Wia = 33,
    StateManagement = 34,
    MetaDirectory = 35,
    WindowsUpdate = 36,
    DirectoryService = 37,
    Graphics = 38,
    Shell = 39,
    Nap = 39,
    TpmServices = 40,
    TpmSoftware = 41,
    UI = 42,
    Xaml = 43,
    ActionQueue = 44,
    Pla = 48,
    WindowsSetup = 48,
    Fve = 49,
    Fwp = 50,
    Winrm = 51,
    Ndis = 52,
    UserModeHypervisor = 53,
    Cmi = 54,
    UserModeVirtualization = 55,
    UserModeVolmgr = 56,
    Bcd = 57,
    UserModeVhd = 58,
    UserModeHns = 59,
    Sdiag = 60,
    Webservices = 61,
    Winpe = 61,
    Wpn = 62,
    WindowsStore = 63,
    Input = 64,
    Quic = 65,
    Eap = 66,
    Ioring = 70,
    WindowsDefender = 80,
    Opc = 81,
    Xps = 82,
    Mbn = 84,
    PowerShell = 84,
    Ras = 83,
    P2pInt = 98,
    P2p = 99,
    Daf = 100,
    BluetoothAtt = 101,
    Audio = 102,
    StateRepository = 103,
    VisualCpp = 109,
    Script = 112,
    Parse = 113,
    Blb = 120,
    BlbCli = 121,
    WsbApp = 122,
    BlbUI = 128,
    Usn = 129,
    UserModeVolsnap = 130,
    Tiering = 131,
    WsbOnline = 133,
    OnlineId = 134,
    DeviceUpdateAgent = 135,
    DrvServicing = 136,
    Dls = 153,
    DeliveryOptimization = 208,
    UserModeSpaces = 231,
    UserModeSecurityCore = 232,
    UserModeLicensing = 234,
    Sos = 160,
    OcpUpdateAgent = 173,
    Debuggers = 176,
    Spp = 256,
    Restore = 256,
    Dmserver = 256,
    DeploymentServicesServer = 257,
    DeploymentServicesImaging = 258,
    DeploymentServicesManagement = 259,
    DeploymentServicesUtil = 260,
    DeploymentServicesBinlsvc = 261,
    DeploymentServicesPxe = 263,
    DeploymentServicesTftp = 264,
    DeploymentServicesTransportManagement = 272,
    DeploymentServicesDriverProvisioning = 278,
    DeploymentServicesMulticastServer = 289,
    DeploymentServicesMulticastClient = 290,
    DeploymentServicesContentProvider = 293,
    HspServices = 296,
    HspSoftware = 297,
    LinguisticServices = 305,
    AudioStreaming = 1094,
    Ttd = 1490,
    Accelerator = 1536,
    WmaaEcma = 1996,
    DirectMusic = 2168,
    Direct3d10 = 2169,
    Dxgi = 2170,
    DxgiDdi = 2171,
    Direct3d11 = 2172,
    Direct3d11Debug = 2173,
    Direct3d12 = 2174,
    Direct3d12Debug = 2175,
    Dxcore = 2176,
    Presentation = 2177,
    Leap = 2184,
    AudClnt = 2185,
    WinCodecDWriteDwm = 2200,
    WinML = 2192,
    Direct2d = 2201,
    Defrag = 2304,
    UserModeSdBus = 2305,
    JScript = 2306,
    Pidgenx = 2561,
    Eas = 85,
    Web = 885,
    WebSocket = 886,
    Mobile = 1793,
    Sqlite = 1967,
    ServiceFabric = 1968,
    Utc = 1989,
    Wep = 2049,
    Syncengine = 2050,
    Xbox = 2339,
    Game = 2340,
    UserModeUnionFS = 2341,
    UserModePrm = 2342,
    UserModeWinAccel = 2343,
    Pix = 2748,
}