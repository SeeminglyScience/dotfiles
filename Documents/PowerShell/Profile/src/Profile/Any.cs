using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;

namespace Profile;

internal static class Any
{
    public static void ThrowIfNone<TAny>(ref readonly TAny any, [CallerArgumentExpression(nameof(any))] string? expression = null)
        where TAny : struct, IAny<TAny>
    {
        if (!any.IsNone)
        {
            return;
        }

        ThrowArgumentNullException(expression);

        static void ThrowArgumentNullException(string? paramName)
        {
            throw new ArgumentNullException(paramName);
        }
    }
}

public interface IAny<TSelf> where TSelf : struct, IAny<TSelf>
{
    bool IsNone { get; }

    ref readonly T UnsafeGetRef<T>();

    static Someable<TSelf, TResult> Some<T, TResult>(ref TSelf self, Func<T, TResult> func)
    {
        return new Someable<TSelf, TResult>(self).Some(func);
    }
}

internal static class AnyExtensions
{
    public static Someable<TSelf, TResult> Some<TSelf, T, TResult>(ref this TSelf self, Func<T, TResult> func)
        where TSelf : struct, IAny<TSelf>
    {
        return new Someable<TSelf, TResult>(self).Some(func);
    }

    public static bool Some<TSelf, T>(this TSelf self, out T value)
        where TSelf : struct, IAny<TSelf>
    {
        ref readonly T valueRef = ref self.UnsafeGetRef<T>();
        if (Unsafe.IsNullRef(in valueRef))
        {
            value = default!;
            return false;
        }

        value = valueRef;
        return true;
    }

    public static Someable<TSelf, TResult> None<TSelf, TResult>(ref this TSelf self, Func<TResult> func)
        where TSelf : struct, IAny<TSelf>
    {
        return new Someable<TSelf, TResult>(self).None(func);
    }
}

public readonly struct Someable<TAny, TResult>
    where TAny : struct, IAny<TAny>
{
    private readonly TAny _any;

    private readonly bool _found;

    private readonly TResult _result;

    public Someable(TAny any)
    {
        _any = any;
        _found = false;
        _result = default!;
    }

    private Someable(TAny any, TResult result)
    {
        _any = any;
        _found = true;
        _result = result;
    }

    public Someable<TAny, TResult> Some<T>(Func<T, TResult> func)
    {
        if (_found)
        {
            return this;
        }

        ref readonly T item = ref _any.UnsafeGetRef<T>();
        if (Unsafe.IsNullRef(in item))
        {
            return this;
        }

        return new(_any, func(item));
    }

    public Someable<TAny, TResult> None(Func<TResult> func)
    {
        if (_found || _any.IsNone)
        {
            return this;
        }

        return new(_any, func());
    }

    public TResult Eval() => _result;
}

public readonly struct Any<T0, T1> : IAny<Any<T0, T1>>
{
    private readonly T0 _item0;

    private readonly T1 _item1;

    private readonly int _setIndex;

    public Any(T0 value)
    {
        _item0 = value;
        _item1 = default!;
        _setIndex = 1;
    }

    public Any(T1 value)
    {
        _item0 = default!;
        _item1 = value;
        _setIndex = 2;
    }

    public static implicit operator Any<T0, T1>(T0 value) => new(value);

    public static implicit operator Any<T0, T1>(T1 value) => new(value);

    public bool IsNone => _setIndex is 0;

    public ref readonly T UnsafeGetRef<T>()
    {
        if (_setIndex is 1 && typeof(T) == typeof(T0)) return ref Unsafe.As<T0, T>(ref Unsafe.AsRef(in _item0));
        if (_setIndex is 2 && typeof(T) == typeof(T1)) return ref Unsafe.As<T1, T>(ref Unsafe.AsRef(in _item1));
        return ref Unsafe.NullRef<T>();
    }
}

public readonly struct Any<T0, T1, T2> : IAny<Any<T0, T1, T2>>
{
    private readonly T0 _item0;

    private readonly T1 _item1;

    private readonly T2 _item2;

    private readonly int _setIndex;

    public Any(T0 value)
    {
        _item0 = value;
        _item1 = default!;
        _item2 = default!;
        _setIndex = 1;
    }

    public Any(T1 value)
    {
        _item0 = default!;
        _item1 = value;
        _item2 = default!;
        _setIndex = 2;
    }

    public Any(T2 value)
    {
        _item0 = default!;
        _item1 = default!;
        _item2 = value;
        _setIndex = 3;
    }

    public static implicit operator Any<T0, T1, T2>(T0 value) => new(value);

    public static implicit operator Any<T0, T1, T2>(T1 value) => new(value);

    public static implicit operator Any<T0, T1, T2>(T2 value) => new(value);

    public bool IsNone => _setIndex is 0;

    public ref readonly T UnsafeGetRef<T>()
    {
        if (_setIndex is 1 && typeof(T) == typeof(T0)) return ref Unsafe.As<T0, T>(ref Unsafe.AsRef(in _item0));
        if (_setIndex is 2 && typeof(T) == typeof(T1)) return ref Unsafe.As<T1, T>(ref Unsafe.AsRef(in _item1));
        if (_setIndex is 3 && typeof(T) == typeof(T2)) return ref Unsafe.As<T2, T>(ref Unsafe.AsRef(in _item2));
        return ref Unsafe.NullRef<T>();
    }
}

// public readonly struct Any<T0, T1, T2>
// {
//     private readonly T0 _item0;

//     private readonly T1 _item1;

//     private readonly T2 _item2;

//     private readonly int _indexSet;

//     public static implicit operator Any<T0, T1, T2>(T0 value) => new(value);

//     public static implicit operator Any<T0, T1, T2>(T1 value) => new(value);

//     public static implicit operator Any<T0, T1, T2>(T2 value) => new(value);

//     public Any(T0 item)
//     {
//         _item0 = item;
//         _item1 = default!;
//         _item2 = default!;
//         _indexSet = 1;
//     }

//     public Any(T1 item)
//     {
//         _item0 = default!;
//         _item1 = item;
//         _item2 = default!;
//         _indexSet = 2;
//     }

//     public Any(T2 item)
//     {
//         _item0 = default!;
//         _item1 = default!;
//         _item2 = item;
//         _indexSet = 3;
//     }

//     public static Any<T0, T1, T2> None() => default;

//     public Someable<TResult> Some<TResult>(Func<T0, TResult> func)
//         => new Someable<TResult>(this, false, default!).Some(func);

//     public Someable<TResult> Some<TResult>(Func<T1, TResult> func)
//         => new Someable<TResult>(this, false, default!).Some(func);

//     public Someable<TResult> Some<TResult>(Func<T2, TResult> func)
//         => new Someable<TResult>(this, false, default!).Some(func);

//     public Someable<TResult> None<TResult>(Func<TResult> func)
//         => new Someable<TResult>(this, false, default!).None(func);

//     public bool Some([MaybeNullWhen(false)] out T0 item)
//     {
//         if (_indexSet is 1)
//         {
//             item = _item0;
//             return true;
//         }

//         item = default;
//         return false;
//     }

//     public bool Some([MaybeNullWhen(false)] out T1 item)
//     {
//         if (_indexSet is 2)
//         {
//             item = _item1;
//             return true;
//         }

//         item = default;
//         return false;
//     }

//     public bool Some([MaybeNullWhen(false)] out T2 item)
//     {
//         if (_indexSet is 3)
//         {
//             item = _item2;
//             return true;
//         }

//         item = default;
//         return false;
//     }

//     public bool IsNone => _indexSet is 0;


//     public readonly struct Someable<TResult>
//     {
//         private readonly Any<T0, T1, T2> _any;

//         private readonly bool _found;

//         private readonly TResult _value;

//         internal Someable(
//             Any<T0, T1, T2> any,
//             bool found,
//             TResult result)
//         {
//             _any = any;
//             _found = found;
//             _value = result;
//         }

//         public Someable<TResult> Some(Func<T0, TResult> func)
//         {
//             return _any._indexSet is 1
//                 ? new(_any, found: true, func(_any._item0))
//                 : this;
//         }

//         public Someable<TResult> Some(Func<T1, TResult> func)
//         {
//             return _any._indexSet is 2
//                 ? new(_any, found: true, func(_any._item1))
//                 : this;
//         }

//         public Someable<TResult> Some(Func<T2, TResult> func)
//         {
//             return _any._indexSet is 3
//                 ? new(_any, found: true, func(_any._item2))
//                 : this;
//         }

//         public Someable<TResult> None(Func<TResult> func)
//         {
//             return _any._indexSet is 0
//                 ? new(_any, found: true, func())
//                 : this;
//         }

//         public TResult Eval() => _value;
//     }
// }