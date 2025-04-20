using System.Collections;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Management.Automation;
using System.Numerics;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

using Profile;

#pragma warning disable CS8981, IDE1006 // The type name only contains lower-cased ascii characters. Such names may become reserved for the language.
#pragma warning disable CS0649 // Field '_' is never assigned to, and will always have its default value

public interface INativeIntWrapper
{
    nint ToIntPtr();
}

public readonly unsafe partial struct ptr<T> : INativeIntWrapper, IAdditionOperators<ptr<T>, int, ptr<T>>
    where T : unmanaged
{
    private readonly T* _value;

    public static implicit operator nint(ptr<T> value) => Unsafe.As<ptr<T>, nint>(ref value);

    public static implicit operator T*(ptr<T> value) => value._value;

    public static implicit operator void*(ptr<T> value) => value._value;

    public static implicit operator ptr(ptr<T> value) => Unsafe.As<ptr<T>, ptr>(ref value);

    public static implicit operator ptr<T>(nint value) => Unsafe.As<nint, ptr<T>>(ref value);

    public static implicit operator ptr<T>(T* value) => Unsafe.As<nint, ptr<T>>(ref *(nint*)&value);

    public static implicit operator ptr<T>(void* value) => Unsafe.As<nint, ptr<T>>(ref *(nint*)&value);

    public static ptr<T> operator +(ptr<T> left, int right)
        => unchecked((nint)left + right);

    public static ptr<T> operator checked +(ptr<T> left, int right)
        => checked((nint)left + right);

    public T this[int index]
    {
        get => _value[index];
        set => _value[index] = value;
    }

    public ptr<TResult> Cast<TResult>() where TResult : unmanaged
    {
        return (ptr<TResult>)(nint)this;
    }

    public override string ToString()
    {
        return $"({Format.Type(typeof(T))}*){Format.Number("0x" + ((long)(nint)_value).ToString("X16"))}";
    }

    public string ToString(int length)
    {
        if (typeof(T) == typeof(char))
        {
            return new string(new ReadOnlySpan<char>(_value, length));
        }

        return $"ptr<{typeof(T).Name}>[{length}]";
    }

    public override bool Equals([NotNullWhen(true)] object? obj)
    {
        return obj switch
        {
            null => ToIntPtr() is 0,
            nint v => v.Equals((nint)this),
            ptr<T> v => Equals(v),
            INativeIntWrapper v => v.ToIntPtr().Equals((nint)this),
            int v => ((nint)v).Equals((nint)this),
            long v => nint.Size is sizeof(long) ? ((nint)v).Equals((nint)this) : false,
            _ => false,
        };
    }

    public override int GetHashCode() => ((nint)this).GetHashCode();

    public nint ToIntPtr() => this;

    public Enumerator Enumerate(int length)
    {
        return new Enumerator(_value, length);
    }

    public struct Enumerator : IEnumerable<T>, IEnumerator<T>
    {
        private readonly int _length;

        private readonly T* _value;

        private int _index;

        public T Current => _index > -1 && _length > _index
            ? _value[_index]
            : default;

        object IEnumerator.Current => Current;

        internal Enumerator(T* value, int length)
        {
            _value = value;
            _length = length;
        }

        public void Dispose()
        {
        }

        public IEnumerator<T> GetEnumerator()
        {
            return this;
        }

        public bool MoveNext()
        {
            if (_index is -1)
            {
                if (_length > 0)
                {
                    _index++;
                    return true;
                }

                return false;
            }

            if (_index is -2)
            {
                return false;
            }

            _index++;
            if (_index == _length)
            {
                _index = -2;
                return false;
            }

            return true;
        }

        public void Reset()
        {
            _index = -1;
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return this;
        }
    }
}

public readonly unsafe partial struct ptr : INativeIntWrapper
{
    private static MethodInfo? s_allocMethod;

    private static MethodInfo? s_allocZeroedMethod;

    public static ptr<T> Alloc<T>(int count) where T : unmanaged
    {
        return NativeMemory.Alloc((nuint)(sizeof(T) * count));
    }

    public static ptr<T> AllocZeroed<T>(int count) where T : unmanaged
    {
        return NativeMemory.AllocZeroed((nuint)(sizeof(T) * count));
    }

    public static ptr Alloc(int size)
    {
        return NativeMemory.Alloc((nuint)size);
    }

    public static object Alloc(Type ptrType, int count)
    {
        s_allocMethod ??= typeof(ptr).GetMethod(
            nameof(Alloc),
            genericParameterCount: 1,
            BindingFlags.Static | BindingFlags.Public,
            [typeof(int)])!;

        return s_allocMethod.MakeGenericMethod(ptrType).Invoke(null, [count])!;
    }

    public static object AllocZeroed(Type ptrType, int count)
    {
        s_allocZeroedMethod ??= typeof(ptr).GetMethod(
            nameof(AllocZeroed),
            genericParameterCount: 1,
            BindingFlags.Static | BindingFlags.Public,
            [typeof(int)])!;

        return s_allocZeroedMethod.MakeGenericMethod(ptrType).Invoke(null, [count])!;
    }

    public static ptr AllocZeroed(int size)
    {
        return NativeMemory.AllocZeroed((nuint)size);
    }

    public static void Free(object? value)
    {
        // Shouldn't be possible when called from pwsh but :shrug:
        if (value is PSObject pso)
        {
            value = pso.BaseObject;
        }

        if (value is null)
        {
            return;
        }

        if (value is ptr ptrValue)
        {
            Free(ptrValue);
            return;
        }

        if (value is INativeIntWrapper wrapper)
        {
            Free(wrapper.ToIntPtr());
            return;
        }

        // Will throw if it's not an nint or any of the above.
        NativeMemory.Free((void*)(nint)value);
    }

    public static void Free(ptr value)
    {
        NativeMemory.Free(value);
    }

    public static void Free<T>(ptr<T> value) where T : unmanaged
    {
        NativeMemory.Free(value);
    }

    private readonly ptr<nint> _value;

    public static implicit operator nint(ptr value) => Unsafe.As<ptr, nint>(ref value);

    public static implicit operator void*(ptr value) => value._value;

    public static implicit operator ptr(nint value) => Unsafe.As<nint, ptr>(ref value);

    public static implicit operator ptr(void* value) => Unsafe.As<nint, ptr>(ref *(nint*)&value);

    public ptr<TResult> Cast<TResult>() where TResult : unmanaged
    {
        return (ptr<TResult>)(nint)this;
    }

    public override string ToString()
    {
        return $"({Format.Type(typeof(void))}*){Format.Number("0x" + ((long)(nint)_value).ToString("X16"))}";
    }

    public override int GetHashCode() => _value.GetHashCode();

    public override bool Equals([NotNullWhen(true)] object? obj)
    {
        return obj switch
        {
            nint v => v.Equals((nint)this),
            ptr v => Equals(v),
            INativeIntWrapper v => v.ToIntPtr().Equals((nint)this),
            int v => ((nint)v).Equals((nint)this),
            long v => nint.Size is sizeof(long) ? ((nint)v).Equals((nint)this) : false,
            _ => false,
        };
    }

    public nint ToIntPtr() => this;
}

#pragma warning restore CS0649 // Field '_' is never assigned to, and will always have its default value
#pragma warning restore CS8981, IDE1006 // The type name only contains lower-cased ascii characters. Such names may become reserved for the language.