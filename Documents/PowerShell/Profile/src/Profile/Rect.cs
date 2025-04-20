using System.Diagnostics.CodeAnalysis;
using System.Numerics;

namespace Profile;

public readonly struct Rect : IEquatable<Rect>, IEqualityOperators<Rect, Rect, bool>
{
    public int Left { get; }

    public int Top { get; }

    public int Right { get; }

    public int Bottom { get; }

    public int Width => Right - Left;

    public int Height => Bottom - Top;

    public static bool operator ==(Rect left, Rect right)
    {
        return left.Equals(right);
    }

    public static bool operator !=(Rect left, Rect right)
    {
        return !left.Equals(right);
    }

    public bool Equals(Rect other)
    {
        return Left == other.Left
            && Right == other.Right
            && Top == other.Top
            && Bottom == other.Bottom;
    }

    public override bool Equals([NotNullWhen(true)] object? obj)
    {
        return obj is Rect other && Equals(other);
    }

    public override string ToString()
    {
        return $"{Left},{Top} - {Width}x{Height}";
    }

    public override int GetHashCode()
    {
        return HashCode.Combine(Left, Right, Top, Bottom);
    }
}