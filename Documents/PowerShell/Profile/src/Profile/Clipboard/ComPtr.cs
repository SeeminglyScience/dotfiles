using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

public unsafe readonly struct ComPtr<T> : IDisposable where T : unmanaged, IUnknown.Interface
{
    private readonly T* _value;

    private ComPtr(T* value) => _value = value;

    public T* Value => _value;

    public static implicit operator ComPtr<T>(T* value) => new(value);

    public static implicit operator T*(ComPtr<T> value) => value._value;

    public void Dispose()
    {
        if (_value is null)
        {
            return;
        }

        _value->Release();
    }

    internal ComPtr<TResult> Cast<TResult>() where TResult : unmanaged, IUnknown.Interface, IComIid
    {
        _value->QueryInterface(out TResult* result).AssertSuccess();
        return result;
    }

    internal bool TryCast<TResult>(out ComPtr<TResult> result) where TResult : unmanaged, IUnknown.Interface, IComIid
    {
        const uint E_NOINTERFACE = 0x80004002;
        HResult hr = _value->QueryInterface(out TResult* temp);
        if (hr.Success)
        {
            result = temp;
            return true;
        }

        if (hr == E_NOINTERFACE)
        {
            result = null;
            return false;
        }

        hr.AssertSuccess();

        // Unreachable
        result = null;
        return false;
    }
}
