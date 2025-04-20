
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Numerics;
using System.Runtime.CompilerServices;
using Profile;

#pragma warning disable CS8981, IDE1006 // The type name only contains lower-cased ascii characters. Such names may become reserved for the language.

public readonly unsafe partial struct ptr : ISignedNumber<ptr>, IBinaryInteger<ptr>
{
    public static ptr NegativeOne => SignedNumber<nint>.NegativeOne;

    public static ptr One => NumberBase<nint>.One;

    public static int Radix => NumberBase<nint>.Radix;

    public static ptr Zero => NumberBase<nint>.Zero;

    public static ptr AdditiveIdentity => AdditiveIdentityProxy<nint>.AdditiveIdentity;

    public static ptr MultiplicativeIdentity => MultiplicativeIdentityProxy<nint>.MultiplicativeIdentity;

    public static ptr Abs(ptr value)
    {
        return NumberBase<nint>.Abs(value);
    }

    public static bool IsCanonical(ptr value)
    {
        return NumberBase<nint>.IsCanonical(value);
    }

    public static bool IsComplexNumber(ptr value)
    {
        return NumberBase<nint>.IsComplexNumber(value);
    }

    public static bool IsEvenInteger(ptr value)
    {
        return NumberBase<nint>.IsEvenInteger(value);
    }

    public static bool IsFinite(ptr value)
    {
        return NumberBase<nint>.IsFinite(value);
    }

    public static bool IsImaginaryNumber(ptr value)
    {
        return NumberBase<nint>.IsImaginaryNumber(value);
    }

    public static bool IsInfinity(ptr value)
    {
        return NumberBase<nint>.IsInfinity(value);
    }

    public static bool IsInteger(ptr value)
    {
        return NumberBase<nint>.IsInteger(value);
    }

    public static bool IsNaN(ptr value)
    {
        return NumberBase<nint>.IsNaN(value);
    }

    public static bool IsNegative(ptr value)
    {
        return NumberBase<nint>.IsNegative(value);
    }

    public static bool IsNegativeInfinity(ptr value)
    {
        return NumberBase<nint>.IsNegativeInfinity(value);
    }

    public static bool IsNormal(ptr value)
    {
        return NumberBase<nint>.IsNormal(value);
    }

    public static bool IsOddInteger(ptr value)
    {
        return NumberBase<nint>.IsOddInteger(value);
    }

    public static bool IsPositive(ptr value)
    {
        return NumberBase<nint>.IsPositive(value);
    }

    public static bool IsPositiveInfinity(ptr value)
    {
        return NumberBase<nint>.IsPositiveInfinity(value);
    }

    public static bool IsRealNumber(ptr value)
    {
        return NumberBase<nint>.IsRealNumber(value);
    }

    public static bool IsSubnormal(ptr value)
    {
        return NumberBase<nint>.IsSubnormal(value);
    }

    public static bool IsZero(ptr value)
    {
        return NumberBase<nint>.IsZero(value);
    }

    public static ptr MaxMagnitude(ptr x, ptr y)
    {
        return NumberBase<nint>.MaxMagnitude(x, y);
    }

    public static ptr MaxMagnitudeNumber(ptr x, ptr y)
    {
        return NumberBase<nint>.MaxMagnitudeNumber(x, y);
    }

    public static ptr MinMagnitude(ptr x, ptr y)
    {
        return NumberBase<nint>.MinMagnitude(x, y);
    }

    public static ptr MinMagnitudeNumber(ptr x, ptr y)
    {
        return NumberBase<nint>.MinMagnitudeNumber(x, y);
    }

    public static ptr Parse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider)
    {
        return NumberBase<nint>.Parse(s, style, provider);
    }

    public static ptr Parse(string s, NumberStyles style, IFormatProvider? provider)
    {
        return NumberBase<nint>.Parse(s, style, provider);
    }

    public bool Equals(ptr other)
    {
        return ((nint)this).Equals((nint)other);
    }

    public static ptr operator +(ptr value)
    {
        return UnaryPlusOperators<nint>.UnaryPlus(value);
    }

    public static ptr operator +(ptr left, ptr right)
    {
        return AdditionOperators<nint>.Addition(left, right);
    }

    public static ptr operator checked +(ptr left, ptr right)
    {
        return AdditionOperators<nint>.CheckedAddition(left, right);
    }

    public static ptr operator -(ptr value)
    {
        return UnaryNegationOperators<nint>.UnaryNegation(value);
    }

    public static ptr operator checked -(ptr value)
    {
        return UnaryNegationOperators<nint>.CheckedUnaryNegation(value);
    }

    public static ptr operator -(ptr left, ptr right)
    {
        return SubtractionOperators<nint>.Subtraction(left, right);
    }

    public static ptr operator checked -(ptr left, ptr right)
    {
        return SubtractionOperators<nint>.CheckedSubtraction(left, right);
    }

    public static ptr operator ++(ptr value)
    {
        return IncrementOperators<nint>.Increment(value);
    }

    public static ptr operator checked ++(ptr value)
    {
        return IncrementOperators<nint>.CheckedIncrement(value);
    }

    public static ptr operator --(ptr value)
    {
        return DecrementOperators<nint>.Decrement(value);
    }

    public static ptr operator checked --(ptr value)
    {
        return DecrementOperators<nint>.CheckedDecrement(value);
    }

    public static ptr operator *(ptr left, ptr right)
    {
        return MultiplyOperators<nint>.Multiply(left, right);
    }

    public static ptr operator checked *(ptr left, ptr right)
    {
        return MultiplyOperators<nint>.CheckedMultiply(left, right);
    }

    public static ptr operator /(ptr left, ptr right)
    {
        return DivisionOperators<nint>.Division(left, right);
    }

    public static ptr operator checked /(ptr left, ptr right)
    {
        return DivisionOperators<nint>.CheckedDivision(left, right);
    }

    public static bool operator ==(ptr left, ptr right)
    {
        return EqualityOperators<nint>.Equality(left, right);
    }

    public static bool operator !=(ptr left, ptr right)
    {
        return EqualityOperators<nint>.Inequality(left, right);
    }

    public static ptr operator &(ptr left, ptr right)
    {
        return (nint)left & (nint)right;
    }

    public static ptr operator |(ptr left, ptr right)
    {
        return (nint)left | (nint)right;
    }

    public static ptr operator ^(ptr left, ptr right)
    {
        return (nint)left ^ (nint)right;
    }

    public static ptr operator ~(ptr value)
    {
        return ~(nint)value;
    }

    public static bool operator >(ptr left, ptr right)
    {
        return (nint)left > (nint)right;
    }

    public static bool operator >=(ptr left, ptr right)
    {
        return (nint)left >= (nint)right;
    }

    public static bool operator <(ptr left, ptr right)
    {
        return (nint)left < (nint)right;
    }

    public static bool operator <=(ptr left, ptr right)
    {
        return (nint)left <= (nint)right;
    }

    public static ptr operator %(ptr left, ptr right)
    {
        return (nint)left % (nint)right;
    }

    public static ptr operator <<(ptr value, int shiftAmount)
    {
        return (nint)value << shiftAmount;
    }

    public static ptr operator >>(ptr value, int shiftAmount)
    {
        return (nint)value >> shiftAmount;
    }

    public static ptr operator >>>(ptr value, int shiftAmount)
    {
        return (nint)value >>> shiftAmount;
    }

    public static ptr Parse(ReadOnlySpan<char> s, IFormatProvider? provider) => SpanParsable<nint>.Parse(s, provider);

    public static ptr Parse(string s, IFormatProvider? provider) => SpanParsable<nint>.Parse(s, provider);

    public static bool TryParse(ReadOnlySpan<char> s, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr result)
    {
        Unsafe.SkipInit(out result);
        return SpanParsable<nint>.TryParse(s, provider, out Unsafe.As<ptr, nint>(ref result));
    }

    public static bool TryParse([NotNullWhen(true)] string? s, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr result)
    {
        Unsafe.SkipInit(out result);
        return SpanParsable<nint>.TryParse(s, provider, out Unsafe.As<ptr, nint>(ref result));
    }

    static bool INumberBase<ptr>.TryConvertFromChecked<TOther>(TOther value, out ptr result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryConvertFromChecked(value, out Unsafe.As<ptr, nint>(ref result));
    }

    static bool INumberBase<ptr>.TryConvertFromSaturating<TOther>(TOther value, out ptr result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryConvertFromSaturating(value, out Unsafe.As<ptr, nint>(ref result));
    }

    static bool INumberBase<ptr>.TryConvertFromTruncating<TOther>(TOther value, out ptr result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryConvertFromTruncating(value, out Unsafe.As<ptr, nint>(ref result));
    }

    static bool INumberBase<ptr>.TryConvertToChecked<TOther>(ptr value, out TOther result)
    {
        return NumberBase<nint>.TryConvertToChecked(value, out result);
    }

    static bool INumberBase<ptr>.TryConvertToSaturating<TOther>(ptr value, out TOther result)
    {
        return NumberBase<nint>.TryConvertToSaturating(value, out result);
    }

    static bool INumberBase<ptr>.TryConvertToTruncating<TOther>(ptr value, out TOther result)
    {
        return NumberBase<nint>.TryConvertToTruncating(value, out result);
    }

    public static bool TryParse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryParse(s, style, provider, out Unsafe.As<ptr, nint>(ref result));
    }

    public static bool TryParse([NotNullWhen(true)] string? s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryParse(s, style, provider, out Unsafe.As<ptr, nint>(ref result));
    }

    public bool TryFormat(Span<char> destination, out int charsWritten, ReadOnlySpan<char> format, IFormatProvider? provider)
        => ToIntPtr().TryFormat(destination, out charsWritten, format, provider);

    public string ToString(string? format, IFormatProvider? formatProvider)
        => format is null or "" ? ToString() : ToIntPtr().ToString(format, formatProvider);

    public int GetByteCount()
    {
        return BinaryInteger<nint>.GetByteCount(this);
    }

    public int GetShortestBitLength()
    {
        return BinaryInteger<nint>.GetShortestBitLength(this);
    }

    public static ptr PopCount(ptr value)
    {
        return BinaryInteger<nint>.PopCount(value);
    }

    public static ptr TrailingZeroCount(ptr value)
    {
        return BinaryInteger<nint>.TrailingZeroCount(value);
    }

    public static bool TryReadBigEndian(ReadOnlySpan<byte> source, bool isUnsigned, out ptr value)
    {
        Unsafe.SkipInit(out value);
        return BinaryInteger<nint>.TryReadBigEndian(source, isUnsigned, out Unsafe.As<ptr, nint>(ref value));
    }

    public static bool TryReadLittleEndian(ReadOnlySpan<byte> source, bool isUnsigned, out ptr value)
    {
        Unsafe.SkipInit(out value);
        return BinaryInteger<nint>.TryReadLittleEndian(source, isUnsigned, out Unsafe.As<ptr, nint>(ref value));
    }

    public bool TryWriteBigEndian(Span<byte> destination, out int bytesWritten)
    {
        return BinaryInteger<nint>.TryWriteBigEndian(this, destination, out bytesWritten);
    }

    public bool TryWriteLittleEndian(Span<byte> destination, out int bytesWritten)
    {
        return BinaryInteger<nint>.TryWriteLittleEndian(this, destination, out bytesWritten);
    }

    public static bool IsPow2(ptr value)
    {
        return BinaryNumber<nint>.IsPow2(value);
    }

    public static ptr Log2(ptr value)
    {
        return BinaryNumber<nint>.Log2(value);
    }

    public int CompareTo(object? obj)
    {
        return PointerOps.TryGetNativeInt(obj, out nint result)
            ? ((nint)this).CompareTo(result)
            : 1;
    }

    public int CompareTo(ptr other)
    {
        return ((nint)this).CompareTo((nint)other);
    }
}

public readonly unsafe partial struct ptr<T> : ISignedNumber<ptr<T>>, IBinaryInteger<ptr<T>>
    where T : unmanaged
{
    public static ptr<T> NegativeOne => SignedNumber<nint>.NegativeOne;

    public static ptr<T> One => NumberBase<nint>.One;

    public static int Radix => NumberBase<nint>.Radix;

    public static ptr<T> Zero => NumberBase<nint>.Zero;

    public static ptr<T> AdditiveIdentity => AdditiveIdentityProxy<nint>.AdditiveIdentity;

    public static ptr<T> MultiplicativeIdentity => 0;

    public static ptr<T> Abs(ptr<T> value)
    {
        return NumberBase<nint>.Abs(value);
    }

    public static bool IsCanonical(ptr<T> value)
    {
        return NumberBase<nint>.IsCanonical(value);
    }

    public static bool IsComplexNumber(ptr<T> value)
    {
        return NumberBase<nint>.IsComplexNumber(value);
    }

    public static bool IsEvenInteger(ptr<T> value)
    {
        return NumberBase<nint>.IsEvenInteger(value);
    }

    public static bool IsFinite(ptr<T> value)
    {
        return NumberBase<nint>.IsFinite(value);
    }

    public static bool IsImaginaryNumber(ptr<T> value)
    {
        return NumberBase<nint>.IsImaginaryNumber(value);
    }

    public static bool IsInfinity(ptr<T> value)
    {
        return NumberBase<nint>.IsInfinity(value);
    }

    public static bool IsInteger(ptr<T> value)
    {
        return NumberBase<nint>.IsInteger(value);
    }

    public static bool IsNaN(ptr<T> value)
    {
        return NumberBase<nint>.IsNaN(value);
    }

    public static bool IsNegative(ptr<T> value)
    {
        return NumberBase<nint>.IsNegative(value);
    }

    public static bool IsNegativeInfinity(ptr<T> value)
    {
        return NumberBase<nint>.IsNegativeInfinity(value);
    }

    public static bool IsNormal(ptr<T> value)
    {
        return NumberBase<nint>.IsNormal(value);
    }

    public static bool IsOddInteger(ptr<T> value)
    {
        return NumberBase<nint>.IsOddInteger(value);
    }

    public static bool IsPositive(ptr<T> value)
    {
        return NumberBase<nint>.IsPositive(value);
    }

    public static bool IsPositiveInfinity(ptr<T> value)
    {
        return NumberBase<nint>.IsPositiveInfinity(value);
    }

    public static bool IsRealNumber(ptr<T> value)
    {
        return NumberBase<nint>.IsRealNumber(value);
    }

    public static bool IsSubnormal(ptr<T> value)
    {
        return NumberBase<nint>.IsSubnormal(value);
    }

    public static bool IsZero(ptr<T> value)
    {
        return NumberBase<nint>.IsZero(value);
    }

    public static ptr<T> MaxMagnitude(ptr<T> x, ptr<T> y)
    {
        return NumberBase<nint>.MaxMagnitude(x, y);
    }

    public static ptr<T> MaxMagnitudeNumber(ptr<T> x, ptr<T> y)
    {
        return NumberBase<nint>.MaxMagnitudeNumber(x, y);
    }

    public static ptr<T> MinMagnitude(ptr<T> x, ptr<T> y)
    {
        return NumberBase<nint>.MinMagnitude(x, y);
    }

    public static ptr<T> MinMagnitudeNumber(ptr<T> x, ptr<T> y)
    {
        return NumberBase<nint>.MinMagnitudeNumber(x, y);
    }

    public static ptr<T> Parse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider)
    {
        return NumberBase<nint>.Parse(s, style, provider);
    }

    public static ptr<T> Parse(string s, NumberStyles style, IFormatProvider? provider)
    {
        return NumberBase<nint>.Parse(s, style, provider);
    }

    public bool Equals(ptr<T> other)
    {
        return ((nint)this).Equals((nint)other);
    }

    public static ptr<T> operator +(ptr<T> value)
    {
        return UnaryPlusOperators<nint>.UnaryPlus(value);
    }

    public static ptr<T> operator +(ptr<T> left, ptr<T> right)
    {
        return AdditionOperators<nint>.Addition(left, right);
    }

    public static ptr<T> operator checked +(ptr<T> left, ptr<T> right)
    {
        return AdditionOperators<nint>.CheckedAddition(left, right);
    }

    public static ptr<T> operator -(ptr<T> value)
    {
        return UnaryNegationOperators<nint>.UnaryNegation(value);
    }

    public static ptr<T> operator checked -(ptr<T> value)
    {
        return UnaryNegationOperators<nint>.CheckedUnaryNegation(value);
    }

    public static ptr<T> operator -(ptr<T> left, ptr<T> right)
    {
        return SubtractionOperators<nint>.Subtraction(left, right);
    }

    public static ptr<T> operator checked -(ptr<T> left, ptr<T> right)
    {
        return SubtractionOperators<nint>.CheckedSubtraction(left, right);
    }

    public static ptr<T> operator ++(ptr<T> value)
    {
        return IncrementOperators<nint>.Increment(value);
    }

    public static ptr<T> operator checked ++(ptr<T> value)
    {
        return IncrementOperators<nint>.CheckedIncrement(value);
    }

    public static ptr<T> operator --(ptr<T> value)
    {
        return DecrementOperators<nint>.Decrement(value);
    }

    public static ptr<T> operator checked --(ptr<T> value)
    {
        return DecrementOperators<nint>.CheckedDecrement(value);
    }

    public static ptr<T> operator *(ptr<T> left, ptr<T> right)
    {
        return MultiplyOperators<nint>.Multiply(left, right);
    }

    public static ptr<T> operator checked *(ptr<T> left, ptr<T> right)
    {
        return MultiplyOperators<nint>.CheckedMultiply(left, right);
    }

    public static ptr<T> operator /(ptr<T> left, ptr<T> right)
    {
        return DivisionOperators<nint>.Division(left, right);
    }

    public static ptr<T> operator checked /(ptr<T> left, ptr<T> right)
    {
        return DivisionOperators<nint>.CheckedDivision(left, right);
    }

    public static bool operator ==(ptr<T> left, ptr<T> right)
    {
        return EqualityOperators<nint>.Equality(left, right);
    }

    public static bool operator !=(ptr<T> left, ptr<T> right)
    {
        return EqualityOperators<nint>.Inequality(left, right);
    }

    public static ptr<T> operator &(ptr<T> left, ptr<T> right)
    {
        return (nint)left & (nint)right;
    }

    public static ptr<T> operator |(ptr<T> left, ptr<T> right)
    {
        return (nint)left | (nint)right;
    }

    public static ptr<T> operator ^(ptr<T> left, ptr<T> right)
    {
        return (nint)left ^ (nint)right;
    }

    public static ptr<T> operator ~(ptr<T> value)
    {
        return ~(nint)value;
    }

    public static bool operator >(ptr<T> left, ptr<T> right)
    {
        return (nint)left > (nint)right;
    }

    public static bool operator >=(ptr<T> left, ptr<T> right)
    {
        return (nint)left >= (nint)right;
    }

    public static bool operator <(ptr<T> left, ptr<T> right)
    {
        return (nint)left < (nint)right;
    }

    public static bool operator <=(ptr<T> left, ptr<T> right)
    {
        return (nint)left <= (nint)right;
    }

    public static ptr<T> operator %(ptr<T> left, ptr<T> right)
    {
        return (nint)left % (nint)right;
    }

    public static ptr<T> operator <<(ptr<T> value, int shiftAmount)
    {
        return (nint)value << shiftAmount;
    }

    public static ptr<T> operator >>(ptr<T> value, int shiftAmount)
    {
        return (nint)value >> shiftAmount;
    }

    public static ptr<T> operator >>>(ptr<T> value, int shiftAmount)
    {
        return (nint)value >>> shiftAmount;
    }

    public static ptr<T> Parse(ReadOnlySpan<char> s, IFormatProvider? provider) => SpanParsable<nint>.Parse(s, provider);

    public static ptr<T> Parse(string s, IFormatProvider? provider) => SpanParsable<nint>.Parse(s, provider);

    public static bool TryParse(ReadOnlySpan<char> s, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return SpanParsable<nint>.TryParse(s, provider, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    public static bool TryParse([NotNullWhen(true)] string? s, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return SpanParsable<nint>.TryParse(s, provider, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    static bool INumberBase<ptr<T>>.TryConvertFromChecked<TOther>(TOther value, out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryConvertFromChecked(value, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    static bool INumberBase<ptr<T>>.TryConvertFromSaturating<TOther>(TOther value, out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryConvertFromSaturating(value, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    static bool INumberBase<ptr<T>>.TryConvertFromTruncating<TOther>(TOther value, out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryConvertFromTruncating(value, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    static bool INumberBase<ptr<T>>.TryConvertToChecked<TOther>(ptr<T> value, out TOther result)
    {
        return NumberBase<nint>.TryConvertToChecked(value, out result);
    }

    static bool INumberBase<ptr<T>>.TryConvertToSaturating<TOther>(ptr<T> value, out TOther result)
    {
        return NumberBase<nint>.TryConvertToSaturating(value, out result);
    }

    static bool INumberBase<ptr<T>>.TryConvertToTruncating<TOther>(ptr<T> value, out TOther result)
    {
        return NumberBase<nint>.TryConvertToTruncating(value, out result);
    }

    public static bool TryParse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryParse(s, style, provider, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    public static bool TryParse([NotNullWhen(true)] string? s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out ptr<T> result)
    {
        Unsafe.SkipInit(out result);
        return NumberBase<nint>.TryParse(s, style, provider, out Unsafe.As<ptr<T>, nint>(ref result));
    }

    public bool TryFormat(Span<char> destination, out int charsWritten, ReadOnlySpan<char> format, IFormatProvider? provider)
        => ToIntPtr().TryFormat(destination, out charsWritten, format, provider);

    public string ToString(string? format, IFormatProvider? formatProvider)
        => format is null or "" ? ToString() : ToIntPtr().ToString(format, formatProvider);

    public int GetByteCount()
    {
        return BinaryInteger<nint>.GetByteCount(this);
    }

    public int GetShortestBitLength()
    {
        return BinaryInteger<nint>.GetShortestBitLength(this);
    }

    public static ptr<T> PopCount(ptr<T> value)
    {
        return BinaryInteger<nint>.PopCount(value);
    }

    public static ptr<T> TrailingZeroCount(ptr<T> value)
    {
        return BinaryInteger<nint>.TrailingZeroCount(value);
    }

    public static bool TryReadBigEndian(ReadOnlySpan<byte> source, bool isUnsigned, out ptr<T> value)
    {
        Unsafe.SkipInit(out value);
        return BinaryInteger<nint>.TryReadBigEndian(source, isUnsigned, out Unsafe.As<ptr<T>, nint>(ref value));
    }

    public static bool TryReadLittleEndian(ReadOnlySpan<byte> source, bool isUnsigned, out ptr<T> value)
    {
        Unsafe.SkipInit(out value);
        return BinaryInteger<nint>.TryReadLittleEndian(source, isUnsigned, out Unsafe.As<ptr<T>, nint>(ref value));
    }

    public bool TryWriteBigEndian(Span<byte> destination, out int bytesWritten)
    {
        return BinaryInteger<nint>.TryWriteBigEndian(this, destination, out bytesWritten);
    }

    public bool TryWriteLittleEndian(Span<byte> destination, out int bytesWritten)
    {
        return BinaryInteger<nint>.TryWriteLittleEndian(this, destination, out bytesWritten);
    }

    public static bool IsPow2(ptr<T> value)
    {
        return BinaryNumber<nint>.IsPow2(value);
    }

    public static ptr<T> Log2(ptr<T> value)
    {
        return BinaryNumber<nint>.Log2(value);
    }

    public int CompareTo(object? obj)
    {
        return PointerOps.TryGetNativeInt(obj, out nint result)
            ? ((nint)this).CompareTo(result)
            : 1;
    }

    public int CompareTo(ptr<T> other)
    {
        return ((nint)this).CompareTo((nint)other);
    }
}

#pragma warning restore CS8981, IDE1006 // The type name only contains lower-cased ascii characters. Such names may become reserved for the language.