using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.Storage.FileSystem;
using Windows.Win32.System.Com;
using Windows.Win32.System.Com.StructuredStorage;
using Windows.Win32.UI.Shell;
using Windows.Win32.UI.Shell.Common;
using Windows.Win32.UI.Shell.PropertiesSystem;
using Windows.Win32.UI.WindowsAndMessaging;

namespace Profile.Links;

[SupportedOSPlatform("windows6.0.6000")]
public unsafe class LnkFile : IDisposable
{
    private const int INPLACE_S_TRUNCATED = 0x000401A0;

    private const int INFOTIPSIZE = 0x400;

    private const int MAX_PATH = 260;

    private bool _isDisposed;

    private string _path;

    private IShellLinkW* _link;

    private LnkFile(string path, IShellLinkW* link, IPersistFile* persist)
    {
        _path = path;
        _link = link;
        Persist = persist;
    }

    private IShellLinkW* Link
    {
        get
        {
            if (_isDisposed || _link is null)
            {
                ThrowInvalidOperation();
                return null;
            }

            return _link;

            [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
            static void ThrowInvalidOperation()
            {
                throw new InvalidOperationException();
            }
        }
    }

    private IPropertyStore* _props;

    private IPropertyStore* Props => AcquireInterface(ref _props);

    private IPersistFile* _persist;

    private IPersistFile* Persist
    {
        get => AcquireInterface(ref _persist);
        set => _persist = value;
    }

    private IShellLinkDataList* _dataList;

    internal IShellLinkDataList* DataList => AcquireInterface(ref _dataList);

    private T* AcquireInterface<T>(ref T* location) where T : unmanaged, IComIID
    {
        if (_isDisposed)
        {
            ThrowInvalidOperation();
            return null;
        }

        if (location is not null)
        {
            return location;
        }

        return location = ((IUnknown*)_link)->GetInterface<T>();

        [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
        static void ThrowInvalidOperation()
        {
            throw new InvalidOperationException();
        }
    }

    public string Path
    {
        [SkipLocalsInit]
        get
        {
            char* buffer = stackalloc char[MAX_PATH];
            Unsafe.InitBlock(buffer, 0, MAX_PATH * sizeof(char));
            WIN32_FIND_DATAW findData = default;
            Link->GetPath(buffer, MAX_PATH, &findData, 0).ThrowOnFailure();
            return new string(buffer);
        }
        set
        {
            fixed (char* buffer = value)
            {
                Link->SetPath(buffer).ThrowOnFailure();
            }
        }
    }

    private LinkIdList? _idList;

    public LinkIdList? IdList
    {
        get
        {
            if (_idList is not null)
            {
                return _idList;
            }

            ITEMIDLIST* idList = null;
            Link->GetIDList(&idList).ThrowOnFailure();
            if (idList is not null)
            {
                return _idList = new(idList);
            }

            return null;
        }
    }

    public string Description
    {
        [SkipLocalsInit]
        get
        {
            char* buffer = stackalloc char[INFOTIPSIZE];
            Unsafe.InitBlock(buffer, 0, INFOTIPSIZE * sizeof(char));
            Link->GetDescription(buffer, INFOTIPSIZE).ThrowOnFailure();
            return new string(buffer);
        }
        set
        {
            fixed (char* buffer = value)
            {
                Link->SetDescription(buffer).ThrowOnFailure();
            }
        }
    }

    public string WorkingDirectory
    {
        [SkipLocalsInit]
        get
        {
            char* buffer = stackalloc char[MAX_PATH];
            Unsafe.InitBlock(buffer, 0, sizeof(char) * MAX_PATH);
            Link->GetWorkingDirectory(buffer, MAX_PATH).ThrowOnFailure();
            return new string(buffer);
        }
        set
        {
            fixed (char* buffer = value)
            {
                Link->SetWorkingDirectory(buffer).ThrowOnFailure();
            }
        }
    }

    public string Arguments
    {
        get
        {
            PROPVARIANT variant = default;
            HRESULT hr = Props->GetValue(
                To.Ref(in Interop.PKEY_Link_Arguments).ToPointer(),
                &variant);

            BSTR str = default;
            try
            {
                hr.ThrowOnFailure();
                Interop.PropVariantToBSTR(&variant, &str).ThrowOnFailure();
                return str.ToString()!;
            }
            finally
            {
                if (str.Value is not null)
                {
                    Interop.SysFreeString(str);
                }

                Interop.PropVariantClear(&variant);
            }
        }
    }

    public ushort Hotkey
    {
        get
        {
            ushort wHotkey = 0;
            Link->GetHotkey(&wHotkey).ThrowOnFailure();
            return wHotkey;
        }
        set => Link->SetHotkey(value).ThrowOnFailure();
    }

    public string? GetIconPath() => GetIconPath(unexpanded: false);

    public string? GetIconPath(bool unexpanded)
    {
        ShortcutFlags flags = Flags;
        if (!flags.HasFlag(ShortcutFlags.HasIconLocation))
        {
            return null;
        }

        DarwinLink* link = null;
        try
        {
            DataList->CopyDataBlock((uint)LinkDataBlockSignature.Link, (void**)&link).AssertSuccess();
            string result = link->_szwDarwinId[..link->_szwDarwinId.Span.IndexOf('\0')].ToString();
            return unexpanded ? result : Environment.ExpandEnvironmentVariables(result);
        }
        finally
        {
            if (link is not null)
            {
                Marshal.FreeHGlobal((nint)link);
            }
        }
    }

    public ShowWindowCmd ShowCmd
    {
        get
        {
            SHOW_WINDOW_CMD iShowCmd = 0;
            Link->GetShowCmd(&iShowCmd).ThrowOnFailure();
            return (ShowWindowCmd)iShowCmd;
        }
        set => Link->SetShowCmd((SHOW_WINDOW_CMD)value).ThrowOnFailure();
    }

    public ShortcutFlags Flags
    {
        get
        {
            ShortcutFlags result = default;
            DataList->GetFlags((uint*)&result).AssertSuccess();
            return result;
        }
        set => DataList->SetFlags((uint)value).AssertSuccess();
    }

    public LnkConsoleSettings GetConsoleSettings() => LnkConsoleSettings.Create(this);

    public void SetConsoleSettings(LnkConsoleSettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        DataList->AddDataBlock(settings.Ptr);
        GC.KeepAlive(settings);
    }

    public T CopyDataBlock<T>(LinkDataBlockSignature signature) where T : unmanaged
    {
        T* result = null;
        try
        {
            DataList->CopyDataBlock((uint)signature, (void**)&result).AssertSuccess();
            return *result;
        }
        finally
        {
            if (result is not null)
            {
                Marshal.FreeHGlobal((nint)result);
            }
        }
    }

    public Dictionary<string, object?> DumpPropertyStore() => Props->DumpProperties();

    public static LnkFile Create(string path)
    {
        IUnknown* punk = null;
        IPersistFile* persist = null;
        try
        {
            Guid clsid = typeof(ShellLink).GUID;
            Guid IID_IShellLinkW = IShellLinkW.IID_Guid;
            Interop.CoCreateInstance(
                &clsid,
                null,
                CLSCTX.CLSCTX_INPROC_SERVER,
                &IID_IShellLinkW,
                (void**)&punk)
                .ThrowOnFailure();

            persist = punk->GetInterface<IPersistFile>();
            fixed (char* pPath = path)
            {
                persist->Load(pPath, 0).ThrowOnFailure();
            }

            return new LnkFile(path, (IShellLinkW*)punk, persist);
        }
        catch
        {
            if (persist is not null)
            {
                persist->Release();
            }

            if (punk is not null)
            {
                punk->Release();
            }

            throw;
        }
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_isDisposed)
        {
            return;
        }

        if (disposing)
        {
        }

        IPersistFile* persist = _persist;
        if (persist is not null)
        {
            persist->Release();
            _persist = null;
        }

        IShellLinkDataList* dataList = _dataList;
        if (dataList is not null)
        {
            dataList->Release();
            _dataList = null;
        }

        IPropertyStore* props = _props;
        if (props is not null)
        {
            props->Release();
            _props = null;
        }

        IShellLinkW* link = _link;
        if (link is not null)
        {
            link->Release();
            _link = null;
        }

        _isDisposed = true;
    }

    ~LnkFile()
    {
        Dispose(disposing: false);
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }
}
