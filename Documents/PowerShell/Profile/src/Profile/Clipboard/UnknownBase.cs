using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Profile.Clipboard;

[StructLayout(LayoutKind.Sequential)]
internal unsafe struct UnknownBase
{
    public void** lpVtbl;

    public int RefCount;

    public Guid* CurrentIid;

    private nint _options;

    public static UnknownBase* Alloc(
        void** vtbl,
        Guid* iid,
        UnknownBaseOptions? options)
    {
        UnknownBase* punk = (UnknownBase*)NativeMemory.AllocZeroed((nuint)sizeof(UnknownBase), 1);
        punk->lpVtbl = vtbl;
        punk->CurrentIid = iid;
        if (options is not null)
        {
            punk->_options = GCHandle.ToIntPtr(GCHandle.Alloc(options));
        }

        return punk;
    }

    public static void AddToVtbl(void** vtbl)
    {
        vtbl[0] = (delegate* unmanaged[Stdcall]<UnknownBase*, Guid*, IUnknown**, HResult>)&QueryInterface;
        vtbl[1] = (delegate* unmanaged[Stdcall]<UnknownBase*, int>)&AddRef;
        vtbl[2] = (delegate* unmanaged[Stdcall]<UnknownBase*, int>)&Release;
    }

    public bool TryGetOptions([NotNullWhen(true)] out UnknownBaseOptions? options)
    {
        if (_options is 0)
        {
            options = null;
            return false;
        }

        GCHandle handle = GCHandle.FromIntPtr(_options);
        if (handle.Target is UnknownBaseOptions foundOptions)
        {
            options = foundOptions;
            return true;
        }

        options = null;
        return false;
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static HResult QueryInterface(UnknownBase* self, Guid* riid, IUnknown** ppvObject)
    {
        const int E_POINTER = unchecked((int)0x80004003);
        const int E_NOINTERFACE = unchecked((int)0x80004002);
        if (riid is null || ppvObject is null)
        {
            return E_POINTER;
        }

        if (riid->Equals(*self->CurrentIid))
        {
            self->RefCount++;
            *ppvObject = (IUnknown*)self;
            return 0;
        }

        if (self->_options is 0)
        {
            return E_NOINTERFACE;
        }

        if (GCHandle.FromIntPtr(self->_options).Target
            is UnknownBaseOptions { QueryFallback: UnknownBaseOptions.QueryInterfaceDelegate query })
        {
            return query(self, riid, ppvObject);
        }

        return E_NOINTERFACE;
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int AddRef(UnknownBase* self)
    {
        return ++self->RefCount;
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int Release(UnknownBase* self)
    {
        int newValue = self->RefCount - 1;
        self->RefCount = newValue;
        if (newValue is not 0)
        {
            return newValue;
        }

        if (!self->TryGetOptions(out UnknownBaseOptions? options))
        {
            return 0;
        }

        options.OnFinalRelease?.Invoke(self);
        return 0;
    }
}
