using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Numerics;
using Microsoft.PowerShell.Commands;

namespace Profile;

public static class IncrementOperators<TSelf> where TSelf : IIncrementOperators<TSelf>
{
    public static TSelf Increment(TSelf value) => unchecked(++value);

    public static TSelf CheckedIncrement(TSelf value) => checked(++value);
}

public static class DecrementOperators<TSelf> where TSelf : IDecrementOperators<TSelf>
{
    public static TSelf Decrement(TSelf value) => unchecked(--value);

    public static TSelf CheckedDecrement(TSelf value) => checked(--value);
}

public static class SubtractionOperators<TSelf, TOther, TResult> where TSelf : ISubtractionOperators<TSelf, TOther, TResult>?
{
    public static TResult Subtraction(TSelf left, TOther right) => unchecked(left - right);

    public static TResult CheckedSubtraction(TSelf left, TOther right) => checked(left - right);
}

public static class SubtractionOperators<TSelf> where TSelf : ISubtractionOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf Subtraction(TSelf left, TSelf right) => unchecked(left - right);

    public static TSelf CheckedSubtraction(TSelf left, TSelf right) => checked(left - right);
}

public static class AdditionOperators<TSelf, TOther, TResult> where TSelf : IAdditionOperators<TSelf, TOther, TResult>?
{
    public static TResult Addition(TSelf left, TOther right) => unchecked(left + right);

    public static TResult CheckedAddition(TSelf left, TOther right) => checked(left + right);
}

public static class AdditionOperators<TSelf> where TSelf : IAdditionOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf Addition(TSelf left, TSelf right) => unchecked(left + right);

    public static TSelf CheckedAddition(TSelf left, TSelf right) => checked(left + right);
}

public static class MultiplyOperators<TSelf, TOther, TResult> where TSelf : IMultiplyOperators<TSelf, TOther, TResult>?
{
    public static TResult Multiply(TSelf left, TOther right) => unchecked(left * right);

    public static TResult CheckedMultiply(TSelf left, TOther right) => checked(left * right);
}

public static class MultiplyOperators<TSelf> where TSelf : IMultiplyOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf Multiply(TSelf left, TSelf right) => unchecked(left * right);

    public static TSelf CheckedMultiply(TSelf left, TSelf right) => checked(left * right);
}

public static class DivisionOperators<TSelf, TOther, TResult> where TSelf : IDivisionOperators<TSelf, TOther, TResult>?
{
    public static TResult Division(TSelf left, TOther right) => unchecked(left / right);

    public static TResult CheckedDivision(TSelf left, TOther right) => checked(left / right);
}

public static class DivisionOperators<TSelf> where TSelf : IDivisionOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf Division(TSelf left, TSelf right) => unchecked(left / right);

    public static TSelf CheckedDivision(TSelf left, TSelf right) => checked(left / right);
}

public static class UnaryPlusOperators<TSelf, TResult> where TSelf : IUnaryPlusOperators<TSelf, TResult>?
{
    public static TResult UnaryPlus(TSelf value) => +value;
}

public static class UnaryPlusOperators<TSelf> where TSelf : IUnaryPlusOperators<TSelf, TSelf>?
{
    public static TSelf UnaryPlus(TSelf value) => +value;
}

public static class UnaryNegationOperators<TSelf> where TSelf : IUnaryNegationOperators<TSelf, TSelf>?
{
    public static TSelf UnaryNegation(TSelf value) => unchecked(-value);

    public static TSelf CheckedUnaryNegation(TSelf value) => checked(-value);
}

public static class Utf8SpanParsable<TSelf> where TSelf : IUtf8SpanParsable<TSelf>?
{
    public static TSelf Parse(ReadOnlySpan<byte> utf8Text, IFormatProvider? provider)
        => TSelf.Parse(utf8Text, provider);

    public static bool TryParse(ReadOnlySpan<byte> utf8Text, IFormatProvider? provider, [MaybeNullWhen(false)] out TSelf? result)
        => TSelf.TryParse(utf8Text, provider, out result);
}

public static class SpanParsable<TSelf> where TSelf : ISpanParsable<TSelf>?
{
    public static TSelf Parse(ReadOnlySpan<char> s, IFormatProvider? provider)
        => TSelf.Parse(s, provider);

    public static bool TryParse(ReadOnlySpan<char> s, IFormatProvider? provider, [MaybeNullWhen(false)] out TSelf? result)
        => TSelf.TryParse(s, provider, out result);
}

public static class Parsable<TSelf> where TSelf : IParsable<TSelf>?
{
    public static TSelf Parse(string s, IFormatProvider? provider)
        => TSelf.Parse(s, provider);

    public static bool TryParse(string s, IFormatProvider? provider, [MaybeNullWhen(false)] out TSelf? result)
        => TSelf.TryParse(s, provider, out result);
}

public static class ComparisonOperators<TSelf, TOther, TResult> where TSelf : IComparisonOperators<TSelf, TOther, TResult>?
{
    public static TResult LessThan(TSelf left, TOther right) => left < right;

    public static TResult LessThanOrEqual(TSelf left, TOther right) => left <= right;

    public static TResult GreaterThan(TSelf left, TOther right) => left > right;

    public static TResult GreaterThanOrEqual(TSelf left, TOther right) => left >= right;
}

public static class ComparisonOperators<TSelf> where TSelf : IComparisonOperators<TSelf, TSelf, bool>?
{
    public static bool LessThan(TSelf left, TSelf right) => left < right;

    public static bool LessThanOrEqual(TSelf left, TSelf right) => left <= right;

    public static bool GreaterThan(TSelf left, TSelf right) => left > right;

    public static bool GreaterThanOrEqual(TSelf left, TSelf right) => left >= right;
}

public static class Number<TSelf> where TSelf : INumber<TSelf>?
{
    public static TSelf Clamp(TSelf value, TSelf min, TSelf max) => TSelf.Clamp(value, min, max);

    public static TSelf CopySign(TSelf value, TSelf sign) => TSelf.CopySign(value, sign);

    public static TSelf Max(TSelf x, TSelf y) => TSelf.Max(x, y);

    public static TSelf MaxNumber(TSelf x, TSelf y) => TSelf.MaxNumber(x, y);

    public static TSelf Min(TSelf x, TSelf y) => TSelf.Min(x, y);

    public static TSelf MinNumber(TSelf x, TSelf y) => TSelf.MinNumber(x, y);

    public static int Sign(TSelf value) => TSelf.Sign(value);
}

public static class ModulusOperators<TSelf, TOther, TResult> where TSelf : IModulusOperators<TSelf, TOther, TResult>?
{
    public static TResult Modulus(TSelf left, TOther right) => left % right;
}

public static class ModulusOperators<TSelf> where TSelf : IModulusOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf Modulus(TSelf left, TSelf right) => left % right;
}

public static class ShiftOperators<TSelf, TOther, TResult> where TSelf : IShiftOperators<TSelf, TOther, TResult>?
{
    public static TResult LeftShift(TSelf value, TOther shiftAmount) => value << shiftAmount;

    public static TResult RightShift(TSelf value, TOther shiftAmount) => value >> shiftAmount;

    public static TResult UnsignedRightShift(TSelf value, TOther shiftAmount) => value >>> shiftAmount;
}

public static class ShiftOperators<TSelf> where TSelf : IShiftOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf LeftShift(TSelf value, TSelf shiftAmount) => value << shiftAmount;

    public static TSelf RightShift(TSelf value, TSelf shiftAmount) => value >> shiftAmount;

    public static TSelf UnsignedRightShift(TSelf value, TSelf shiftAmount) => value >>> shiftAmount;
}

public static class MinMaxValue<TSelf> where TSelf : IMinMaxValue<TSelf>?
{
    public static TSelf MaxValue => TSelf.MaxValue;

    public static TSelf MinValue => TSelf.MinValue;
}

public static class BitwiseOperators<TSelf, TOther, TResult> where TSelf : IBitwiseOperators<TSelf, TOther, TResult>?
{
    public static TResult BitwiseAnd(TSelf left, TOther right) => left & right;

    public static TResult BitwiseOr(TSelf left, TOther right) => left | right;

    public static TResult ExclusiveOr(TSelf left, TOther right) => left ^ right;

    public static TResult OnesComplement(TSelf value) => ~value;
}

public static class BitwiseOperators<TSelf> where TSelf : IBitwiseOperators<TSelf, TSelf, TSelf>?
{
    public static TSelf BitwiseAnd(TSelf left, TSelf right) => left & right;

    public static TSelf BitwiseOr(TSelf left, TSelf right) => left | right;

    public static TSelf ExclusiveOr(TSelf left, TSelf right) => left ^ right;

    public static TSelf OnesComplement(TSelf value) => ~value;
}

public static class BinaryNumber<TSelf> where TSelf : IBinaryNumber<TSelf>?
{
    public static TSelf AllBitsSet => TSelf.AllBitsSet;

    public static TSelf Log2(TSelf value) => TSelf.Log2(value);

    public static bool IsPow2(TSelf value) => TSelf.IsPow2(value);
}

public static class BinaryInteger<TSelf> where TSelf : IBinaryInteger<TSelf>
{
    public static ValueTuple<TSelf, TSelf> DivRem(TSelf left, TSelf right) => TSelf.DivRem(left, right);

    public static TSelf LeadingZeroCount(TSelf value) => TSelf.LeadingZeroCount(value);

    public static TSelf PopCount(TSelf value) => TSelf.PopCount(value);

    public static TSelf ReadBigEndian(byte[] source, bool isUnsigned) => TSelf.ReadBigEndian(source, isUnsigned);

    public static TSelf ReadBigEndian(byte[] source, int startIndex, bool isUnsigned) => TSelf.ReadBigEndian(source, startIndex, isUnsigned);

    public static TSelf ReadBigEndian(ReadOnlySpan<byte> source, bool isUnsigned) => TSelf.ReadBigEndian(source, isUnsigned);

    public static TSelf ReadLittleEndian(byte[] source, bool isUnsigned) => TSelf.ReadLittleEndian(source, isUnsigned);

    public static TSelf ReadLittleEndian(byte[] source, int startIndex, bool isUnsigned) => TSelf.ReadLittleEndian(source, startIndex, isUnsigned);

    public static TSelf ReadLittleEndian(ReadOnlySpan<byte> source, bool isUnsigned) => TSelf.ReadLittleEndian(source, isUnsigned);

    public static TSelf RotateLeft(TSelf value, int rotateAmount) => TSelf.RotateLeft(value, rotateAmount);

    public static TSelf RotateRight(TSelf value, int rotateAmount) => TSelf.RotateRight(value, rotateAmount);

    public static TSelf TrailingZeroCount(TSelf value) => TSelf.TrailingZeroCount(value);

    public static bool TryReadBigEndian(ReadOnlySpan<byte> source, bool isUnsigned, out TSelf value) => TSelf.TryReadBigEndian(source, isUnsigned, out value);

    public static bool TryReadLittleEndian(ReadOnlySpan<byte> source, bool isUnsigned, out TSelf value) => TSelf.TryReadLittleEndian(source, isUnsigned, out value);

    public static int GetByteCount(TSelf self) => self.GetByteCount();

    public static int GetShortestBitLength(TSelf self) => self.GetShortestBitLength();

    public static bool TryWriteBigEndian(TSelf self, Span<byte> destination, out int bytesWritten) => self.TryWriteBigEndian(destination, out bytesWritten);

    public static bool TryWriteLittleEndian(TSelf self, Span<byte> destination, out int bytesWritten) => self.TryWriteLittleEndian(destination, out bytesWritten);

    public static int WriteBigEndian(TSelf self, byte[] destination) => self.WriteBigEndian(destination);

    public static int WriteBigEndian(TSelf self, byte[] destination, int startIndex) => self.WriteBigEndian(destination, startIndex);

    public static int WriteBigEndian(TSelf self, Span<byte> destination) => self.WriteBigEndian(destination);

    public static int WriteLittleEndian(TSelf self, byte[] destination) => self.WriteLittleEndian(destination);

    public static int WriteLittleEndian(TSelf self, byte[] destination, int startIndex) => self.WriteLittleEndian(destination, startIndex);

    public static int WriteLittleEndian(TSelf self, Span<byte> destination) => self.WriteLittleEndian(destination);
}

public static class NumberBase<T> where T : INumberBase<T>
{
    public static T One => T.One;

    public static int Radix => T.Radix;

    public static T Zero => T.Zero;

    public static T Abs(T value)
        => T.Abs(value);

    public static bool IsCanonical(T value)
        => T.IsCanonical(value);

    public static bool IsComplexNumber(T value)
        => T.IsComplexNumber(value);

    public static bool IsEvenInteger(T value)
        => T.IsEvenInteger(value);

    public static bool IsFinite(T value)
        => T.IsFinite(value);

    public static bool IsImaginaryNumber(T value)
        => T.IsImaginaryNumber(value);

    public static bool IsInfinity(T value)
        => T.IsInfinity(value);

    public static bool IsInteger(T value)
        => T.IsInteger(value);

    public static bool IsNaN(T value)
        => T.IsNaN(value);

    public static bool IsNegative(T value)
        => T.IsNegative(value);

    public static bool IsNegativeInfinity(T value)
        => T.IsNegativeInfinity(value);

    public static bool IsNormal(T value)
        => T.IsNormal(value);

    public static bool IsOddInteger(T value)
        => T.IsOddInteger(value);

    public static bool IsPositive(T value)
        => T.IsPositive(value);

    public static bool IsPositiveInfinity(T value)
        => T.IsPositiveInfinity(value);

    public static bool IsRealNumber(T value)
        => T.IsRealNumber(value);

    public static bool IsSubnormal(T value)
        => T.IsSubnormal(value);

    public static bool IsZero(T value)
        => T.IsZero(value);

    public static T MaxMagnitude(T x, T y)
        => T.MaxMagnitude(x, y);

    public static T MaxMagnitudeNumber(T x, T y)
        => T.MaxMagnitudeNumber(x, y);

    public static T MinMagnitude(T x, T y)
        => T.MinMagnitude(x, y);

    public static T MinMagnitudeNumber(T x, T y)
        => T.MinMagnitudeNumber(x, y);

    public static T Parse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider) => T.Parse(s, style, provider);

    public static T Parse(string s, NumberStyles style, IFormatProvider? provider) => T.Parse(s, style, provider);

    public static bool TryParse(ReadOnlySpan<char> s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out T result)
        => T.TryParse(s, style, provider, out result);

    public static bool TryParse([NotNullWhen(true)] string? s, NumberStyles style, IFormatProvider? provider, [MaybeNullWhen(false)] out T result)
        => T.TryParse(s, style, provider, out result);

    private static class ProtectedGenerics<TOther>
    {
        private static OutCall<TOther, T, bool>? s_tryConvertFromChecked;

        public static OutCall<TOther, T, bool> GetTryConvertFromChecked
            => s_tryConvertFromChecked ??= InterfaceOps.CreateInterfaceImplInvocation<TOther, T, bool>(
                typeof(INumberBase<T>),
                typeof(T),
                typeof(TOther),
                "TryConvertFromChecked");

        private static OutCall<TOther, T, bool>? s_tryConvertFromSaturating;

        public static OutCall<TOther, T, bool> GetTryConvertFromSaturating
            => s_tryConvertFromSaturating ??= InterfaceOps.CreateInterfaceImplInvocation<TOther, T, bool>(
                typeof(INumberBase<T>),
                typeof(T),
                typeof(TOther),
                "TryConvertFromSaturating");

        private static OutCall<TOther, T, bool>? s_tryConvertFromTruncating;

        public static OutCall<TOther, T, bool> GetTryConvertFromTruncating
            => s_tryConvertFromTruncating ??= InterfaceOps.CreateInterfaceImplInvocation<TOther, T, bool>(
                typeof(INumberBase<T>),
                typeof(T),
                typeof(TOther),
                "TryConvertFromTruncating");

        private static OutCall<T, TOther, bool>? s_tryConvertToChecked;

        public static OutCall<T, TOther, bool> GetTryConvertToChecked
            => s_tryConvertToChecked ??= InterfaceOps.CreateInterfaceImplInvocation<T, TOther, bool>(
                typeof(INumberBase<T>),
                typeof(T),
                typeof(TOther),
                nameof(TryConvertToChecked));

        private static OutCall<T, TOther, bool>? s_tryConvertToSaturating;

        public static OutCall<T, TOther, bool> GetTryConvertToSaturating
            => s_tryConvertToSaturating ??= InterfaceOps.CreateInterfaceImplInvocation<T, TOther, bool>(
                typeof(INumberBase<T>),
                typeof(T),
                typeof(TOther),
                nameof(TryConvertToSaturating));

        private static OutCall<T, TOther, bool>? s_tryConvertToTruncating;

        public static OutCall<T, TOther, bool> GetTryConvertToTruncating
            => s_tryConvertToTruncating ??= InterfaceOps.CreateInterfaceImplInvocation<T, TOther, bool>(
                typeof(INumberBase<T>),
                typeof(T),
                typeof(TOther),
                nameof(TryConvertToTruncating));
    }

    public static bool TryConvertFromChecked<TOther>(TOther value, out T result)
        => ProtectedGenerics<TOther>.GetTryConvertFromChecked(value, out result);

    public static bool TryConvertFromSaturating<TOther>(TOther value, out T result)
        => ProtectedGenerics<TOther>.GetTryConvertFromSaturating(value, out result);

    public static bool TryConvertFromTruncating<TOther>(TOther value, out T result)
        => ProtectedGenerics<TOther>.GetTryConvertFromTruncating(value, out result);

    public static bool TryConvertToChecked<TOther>(T value, out TOther result)
        => ProtectedGenerics<TOther>.GetTryConvertToChecked(value, out result);

    public static bool TryConvertToSaturating<TOther>(T value, out TOther result)
        => ProtectedGenerics<TOther>.GetTryConvertToSaturating(value, out result);

    public static bool TryConvertToTruncating<TOther>(T value, out TOther result)
        => ProtectedGenerics<TOther>.GetTryConvertToTruncating(value, out result);
}

public static class SignedNumber<T> where T : ISignedNumber<T>
{
    public static T NegativeOne => T.NegativeOne;
}

public static class AdditiveIdentityProxy<TSelf, TResult> where TSelf : IAdditiveIdentity<TSelf, TResult>
{
    public static TResult AdditiveIdentity => TSelf.AdditiveIdentity;
}

public static class AdditiveIdentityProxy<TSelf> where TSelf : IAdditiveIdentity<TSelf, TSelf>
{
    public static TSelf AdditiveIdentity => TSelf.AdditiveIdentity;
}

public static class MultiplicativeIdentityProxy<TSelf, TResult> where TSelf : IMultiplicativeIdentity<TSelf, TResult>
{
    public static TResult MultiplicativeIdentity => TSelf.MultiplicativeIdentity;
}

public static class MultiplicativeIdentityProxy<TSelf> where TSelf : IMultiplicativeIdentity<TSelf, TSelf>
{
    public static TSelf MultiplicativeIdentity => TSelf.MultiplicativeIdentity;
}

public static class EqualityOperators<TSelf, TOther, TResult> where TSelf : IEqualityOperators<TSelf, TOther, TResult>
{
    public static TResult Equality(TSelf left, TOther right) => left == right;

    public static TResult Inequality(TSelf left, TOther right) => left != right;
}

public static class EqualityOperators<TSelf> where TSelf : IEqualityOperators<TSelf, TSelf, bool>
{
    public static bool Equality(TSelf left, TSelf right) => left == right;

    public static bool Inequality(TSelf left, TSelf right) => left != right;
}

public static class EqualityOperators<TSelf, TOther> where TSelf : IEqualityOperators<TSelf, TOther, bool>
{
    public static bool Equality(TSelf left, TOther right) => left == right;

    public static bool Inequality(TSelf left, TOther right) => left != right;
}