using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.UI.Shell;
using Windows.Win32.UI.Shell.Common;
using Windows.Win32.UI.Shell.PropertiesSystem;

namespace Profile.Links;

[SupportedOSPlatform("windows6.0.6000")]
public unsafe sealed class LinkIdList : IDisposable
{
    private const uint SHGDFIL_FINDDATA = 1;

    private const uint SHGDFIL_NETRESOURCE = 2;

    private const uint SHGDFIL_DESCRIPTIONID = 3;

    private readonly ITEMIDLIST* _list;

    private readonly bool _ownsList;

    private bool _isDisposed;

    internal LinkIdList(ITEMIDLIST* list, bool ownsList = false)
    {
        _list = list;
        _ownsList = ownsList;
    }

    public object DumpPropertyStore()
    {
        IPropertyStore* props = null;
        try
        {
            Interop.SHGetPropertyStoreFromIDList(
                _list,
                GETPROPERTYSTOREFLAGS.GPS_OPENSLOWITEM,
                To.Ref(in IPropertyStore.IID_Guid).ToPointer(),
                (void**)&props)
                .AssertSuccess();

            return props->DumpProperties();
        }
        finally
        {
            if (props is not null)
            {
                props->Release();
            }
        }
    }

    public List<byte[]> UnsafeGetItemIdListBytes()
    {
        List<byte[]> items = [];
        byte* p = (byte*)_list;
        while (true)
        {
            ushort cb = *(ushort*)p;
            p += sizeof(ushort);
            if (cb is 0)
            {
                break;
            }

            items.Add(new Span<byte>(p, cb).ToArray());
            p += cb;
        }

        return items;
    }

    public LinkIdListDescriptionId GetDescriptionId()
    {
        LinkIdListDescriptionId descriptionId = default;
        Interop.SHGetDataFromIDList(
            null,
            _list,
            SHGDFIL_FORMAT.SHGDFIL_DESCRIPTIONID,
            &descriptionId,
            sizeof(LinkIdListDescriptionId))
            .AssertSuccess();

        return descriptionId;
    }

    public string GetName(LinkSigDn dn = LinkSigDn.NormalDisplay)
    {
        PWSTR pName = default;
        try
        {
            Interop.SHGetNameFromIDList(
                _list,
                (SIGDN)dn,
                &pName)
                .AssertSuccess();

            return pName.ToString();
        }
        finally
        {
            if (pName.Value is not null)
            {
                Marshal.FreeCoTaskMem((nint)pName.Value);
            }
        }
    }

    [SkipLocalsInit]
    public string GetPath(GpfIdlFlags flags = GpfIdlFlags.Default)
    {
        const int MAX_PATH = 260;
        char* path = stackalloc char[MAX_PATH];
        Unsafe.InitBlock(path, 0, MAX_PATH * sizeof(char));
        if (!Interop.SHGetPathFromIDListEx(_list, path, MAX_PATH, (GPFIDL_FLAGS)flags))
        {
            throw new Win32Exception();
        }

        return new string(path);
    }

    public void Dispose()
    {
        if (_isDisposed || !_ownsList)
        {
            return;
        }

        Marshal.FreeCoTaskMem((nint)_list);
        _isDisposed = true;
    }
}
