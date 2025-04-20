using System.ComponentModel;
using System.Diagnostics.CodeAnalysis;
using System.Management.Automation;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.System.Com;
using Windows.Win32.System.Com.StructuredStorage;
using Windows.Win32.System.Variant;
using Windows.Win32.UI.Shell.PropertiesSystem;

namespace Profile;

internal static unsafe class To
{
    public static ref T Ref<T>(ref readonly T self)
    {
        return ref Unsafe.AsRef(in self);
    }

    public static ref T* Ref<T>(scoped ref readonly T* self)
        where T : unmanaged
    {
        fixed (T** pSelf = &self)
        {
            return ref *pSelf;
        }
    }

    public static ref T** Ref<T>(scoped ref readonly T** self)
        where T : unmanaged
    {
        fixed (T*** pSelf = &self)
        {
            return ref *pSelf;
        }
    }
}

internal static unsafe class VariantOps
{
    private static T[] GetArray<T>(uint count, T* ptr)
        where T : unmanaged
    {
        T[] result = new T[count];
        for (int i = 0; i < count; i++)
        {
            result[i] = ptr[i];
        }

        return result;
    }

    private static string[] GetArray(uint count, BSTR* ptr)
    {
        string[] result = new string[count];
        for (int i = 0; i < count; i++)
        {
            result[i] = ptr[i].ToString();
        }

        return result;
    }

    private static string[] GetArray(uint count, PWSTR* ptr)
    {
        string[] result = new string[count];
        for (int i = 0; i < count; i++)
        {
            result[i] = ptr[i].ToString();
        }

        return result;
    }

    private static ptr<T>[] GetArray<T>(uint count, T** ptr)
        where T : unmanaged
    {
        ptr<T>[] result = new ptr<T>[count];
        for (int i = 0; i < count; i++)
        {
            result[i] = ptr[i];
        }

        return result;
    }

    public static object? GetObject(ref PROPVARIANT variant)
    {
        ref PropVariant var = ref Unsafe.As<PROPVARIANT, PropVariant>(ref variant);
        VARENUM vt = var.vt;
        if (vt.HasFlag(VARENUM.VT_VECTOR))
        {
            vt &= ~VARENUM.VT_VECTOR;
            return vt switch
            {
                VARENUM.VT_I1 => GetArray(var.cac.cElems, (sbyte*)(void*)var.cac.pElems),
                VARENUM.VT_UI1 => GetArray(var.caub.cElems, var.caub.pElems),
                VARENUM.VT_I2 => GetArray(var.cai.cElems, var.cai.pElems),
                VARENUM.VT_UI2 => GetArray(var.caui.cElems, var.caui.pElems),
                VARENUM.VT_I4 => GetArray(var.cal.cElems, var.cal.pElems),
                VARENUM.VT_UI4 => GetArray(var.caul.cElems, var.caul.pElems),
                VARENUM.VT_INT => GetArray(var.cal.cElems, var.cal.pElems),
                VARENUM.VT_UINT => GetArray(var.caul.cElems, var.caul.pElems),
                VARENUM.VT_R4 => GetArray(var.caflt.cElems, var.caflt.pElems),
                VARENUM.VT_R8 => GetArray(var.cadbl.cElems, var.cadbl.pElems),
                VARENUM.VT_BOOL => GetArray(var.cabool.cElems, var.cabool.pElems),
                VARENUM.VT_DECIMAL => GetArray(var.cabool.cElems, (DECIMAL*)var.cabool.pElems),
                VARENUM.VT_ERROR => GetArray(var.cascode.cElems, var.cascode.pElems),
                VARENUM.VT_CY => GetArray(var.cacy.cElems, var.cacy.pElems),
                VARENUM.VT_DATE => GetArray(var.cadate.cElems, var.cadate.pElems),
                VARENUM.VT_BSTR => GetArray(var.cabstr.cElems, var.cabstr.pElems),
                VARENUM.VT_DISPATCH => GetArray(var.cai.cElems, (IDispatch**)var.cai.pElems),
                VARENUM.VT_UNKNOWN => GetArray(var.cai.cElems, (IUnknown**)var.cai.pElems),
                VARENUM.VT_VARIANT => GetArray(var.capropvar.cElems, var.capropvar.pElems),
                VARENUM.VT_LPWSTR => GetArray(var.calpwstr.cElems, var.calpwstr.pElems),
            _ => throw new ArgumentOutOfRangeException(nameof(variant), $"VT type '{vt}' not handled in a VT_VECTOR."),
            };
        }

        if (var.vt is (VARENUM.VT_VECTOR | VARENUM.VT_LPWSTR))
        {
            string[] result = new string[var.calpwstr.cElems];
            for (int i = 0; i < result.Length; i++)
            {
                result[i] = var.calpwstr.pElems[i].ToString();
            }

            return result;
        }

        return var.vt switch
        {
            VARENUM.VT_EMPTY => null,
            VARENUM.VT_BSTR => var.bstrVal.ToString(),
            VARENUM.VT_I1 => var.cVal.Value,
            VARENUM.VT_UI1 => var.bVal,
            VARENUM.VT_I2 => var.iVal,
            VARENUM.VT_UI2 => var.uiVal,
            VARENUM.VT_I4 => var.intVal,
            VARENUM.VT_UI4 => var.uintVal,
            VARENUM.VT_I8 => var.hVal,
            VARENUM.VT_UI8 => var.uhVal,
            VARENUM.VT_LPWSTR => var.pwszVal.ToString(),
            VARENUM.VT_BOOL => var.boolVal.Value is not 0,
            VARENUM.VT_FILETIME => var.filetime,
            VARENUM.VT_CLSID => GetOrNull(var.puuid),
            _ => throw new ArgumentOutOfRangeException(nameof(variant), $"VT type '{var.vt}' not handled."),
        };

        static object? GetOrNull<T>(T* ptr)
            where T : unmanaged
        {
            return ptr is null ? null : *ptr;
        }
    }
}

internal static unsafe class UnsafeExtensions
{
    [SupportedOSPlatform("windows6.0.6000")]
    public static Dictionary<string, object?> DumpProperties(this ref IPropertyStore props)
    {
        uint count = 0;
        props.GetCount(&count).AssertSuccess();

        Dictionary<string, object?> results = new((int)count);
        for (uint i = 0; i < count; i++)
        {
            PROPERTYKEY key = default;
            IPropertyDescription* desc = null;
            PWSTR canonicalName = default;

            try
            {
                props.GetAt(i, &key).AssertSuccess();
                HRESULT hr = Interop.PSGetPropertyDescription(
                    &key,
                    To.Ref(in IPropertyDescription.IID_Guid).ToPointer(),
                    (void**)&desc);

                string? name = null;
                if (hr.Succeeded)
                {
                    desc->GetCanonicalName(&canonicalName).AssertSuccess();
                    name = canonicalName.ToString();
                }
                else
                {
                    name = $"{key.pid},{key.fmtid}";
                }

                PROPVARIANT propVariant = default;
                props.GetValue(&key, &propVariant).AssertSuccess();
                results.Add(name, VariantOps.GetObject(ref propVariant));
            }
            finally
            {
                if (canonicalName.Value is not null)
                {
                    Marshal.FreeCoTaskMem((nint)canonicalName.Value);
                }

                if (desc is not null)
                {
                    desc->Release();
                }
            }
        }

        return results;
    }

    public static T* ToPointer<T>(this ref T self) where T : unmanaged
    {
        return (T*)Unsafe.AsPointer(ref self);
    }

    public static ref T ToRef<T>(this ref T self) where T : unmanaged
    {
        return ref self;
    }

    public static Castable<T> Cast<T>(this ref T self) where T : unmanaged
    {
        return new Castable<T>(ref self);
    }

    public static bool QueryInterface<TComInterface, TVTable>(void* punk, out TComInterface* result)
        where TComInterface : unmanaged, IVTable<TComInterface, TVTable>, IComIID
        where TVTable : unmanaged
    {
        fixed (TComInterface** pp = &result)
        {
            Windows.Win32.Foundation.HRESULT hr = ((IUnknown*)punk)->QueryInterface(
                To.Ref(in TComInterface.Guid).ToPointer(),
                (void**)pp);

            return hr.Succeeded;
        }
    }

    public static IUnknown* ToUnknown<T>(this ref T self) where T : unmanaged
    {
        return (IUnknown*)self.ToPointer();
    }

    public static TComInterface* GetInterface<TComInterface>(this ref IUnknown punk)
        where TComInterface : unmanaged, IComIID
    {
        TComInterface* pp = null;
        HRESULT hr = punk.QueryInterface(
            To.Ref(in TComInterface.Guid).ToPointer(),
            (void**)&pp);

        if (hr.Succeeded)
        {
            return pp;
        }

        Exception innerException = Marshal.GetExceptionForHR(hr.Value) ?? new Win32Exception(hr.Value);
        throw new InvalidOperationException(
            $"Could not acquire interface '{typeof(TComInterface).FullName}' due to message: {innerException.Message}",
            innerException);
    }

    public static void AssertSuccess(this HRESULT hr, [CallerArgumentExpression(nameof(hr))] string expression = "")
    {
        if (hr.Succeeded)
        {
            return;
        }

        IErrorInfo* errorInfo = null;
        try
        {
            if (!Interop.GetErrorInfo(0, &errorInfo).Succeeded)
            {
                errorInfo = null;
            }

            throw ComException.Create(expression, hr, errorInfo);
        }
        finally
        {
            if (errorInfo is not null)
            {
                errorInfo->Release();
            }
        }


        // if (expression is "")
        // {
        //     Marshal.ThrowExceptionForHR(hr.Value);
        //     return;
        // }

        // throw new InvalidOperationException(
        //     $"Expression '{expression}' failed with exit code 0x{hr.Value.ToString("X8")}.");
    }

    public static Span<char> SliceToNull(this Span<char> value)
    {
        int index = value.IndexOf('\0');
        if (index is -1)
        {
            return value;
        }

        return value[..index];
    }

    public static ReadOnlySpan<char> SliceToNull(this ReadOnlySpan<char> value)
    {
        int index = value.IndexOf('\0');
        if (index is -1)
        {
            return value;
        }

        return value[..index];
    }
}

public sealed unsafe class ComException : Exception
{
    public override string Message { get; }

    public string Description { get; }

    public Guid Guid { get; }

    public uint HelpContext { get; }

    public string HelpFile { get; }

    public string ComSource { get; }

    private ComException(
        string action,
        HRESULT hr,
        string? description,
        Guid guid,
        uint helpContext,
        string? helpFile,
        string? source)
    {
        description ??= "";
        helpFile ??= "";
        source ??= "";
        if (description is "")
        {
            Message = $"Action '{action}' failed with HR {WinError.FormatHR(hr)}.";
        }
        else
        {
            Message = $"Action '{action}' failed with message '{description}'.";
        }

        HResult = hr.Value;
        Description = description;
        Guid = guid;
        HelpContext = helpContext;
        HelpFile = helpFile;
        ComSource = source;
    }

    internal static ComException Create(string action, HRESULT hr, IErrorInfo* errorInfo)
    {
        if (errorInfo is null)
        {
            return new ComException(action, hr, default, default, default, default, default);
        }

        BSTR desc = default;
        BSTR helpFile = default;
        BSTR source = default;
        try
        {
            Guid guid = default;
            uint helpContext = default;

            if (!errorInfo->GetDescription(&desc).Succeeded)
            {
                desc = default;
            }

            if (!errorInfo->GetGUID(&guid).Succeeded)
            {
                guid = default;
            }

            if (!errorInfo->GetHelpContext(&helpContext).Succeeded)
            {
                helpContext = default;
            }

            if (!errorInfo->GetHelpFile(&helpFile).Succeeded)
            {
                helpFile = default;
            }

            if (!errorInfo->GetSource(&source).Succeeded)
            {
                source = default;
            }

            return new ComException(
                action,
                hr,
                desc.ToString(),
                guid,
                helpContext,
                helpFile.ToString(),
                source.ToString());
        }
        finally
        {
            if (desc.Value is not null)
            {
                Marshal.FreeCoTaskMem((nint)desc.Value);
            }

            if (helpFile.Value is not null)
            {
                Marshal.FreeCoTaskMem((nint)helpFile.Value);
            }

            if (source.Value is not null)
            {
                Marshal.FreeCoTaskMem((nint)source.Value);
            }
        }
    }
}

internal readonly ref struct Castable<T>
{
    private readonly ref T _value;

    public Castable(ref T value)
    {
        _value = ref value;
    }

    public ref TResult As<TResult>()
    {
        return ref Unsafe.As<T, TResult>(ref _value);
    }
}