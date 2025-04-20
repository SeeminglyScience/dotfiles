using System.Buffers;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Windows.Win32;
using Windows.Win32.Foundation;
using Windows.Win32.UI.WindowsAndMessaging;

[assembly: SupportedOSPlatform("windows5.0")]

namespace Profile;

[Flags]
public enum WindowStyle : uint
{
    Tiled = 0,
    Overlapped = 0,
    MaximizeBox = 1 << 16,
    TabStop = 1 << 16,
    Group = 1 << 17,
    MinimizeBox = 1 << 17,
    SizeBox = 1 << 18,
    ThickFrame = 1 << 18,
    SysMenu = 1 << 19,
    HScroll = 1 << 20,
    VScroll = 1 << 21,
    DlgFrame = 1 << 22,
    Border = 1 << 23,
    Caption = Border | DlgFrame,
    TiledWindow = OverlappedWindow,
    OverlappedWindow = Overlapped | Caption | SysMenu | ThickFrame | MinimizeBox | MaximizeBox,
    Maximize = 1 << 24,
    ClipChildren = 1 << 25,
    ClipSiblings = 1 << 26,
    Disabled = 1 << 27,
    Visible = 1 << 28,
    Minimize = 1 << 29,
    Iconic = 1 << 29,
    Child = 1 << 30,
    ChildWindow = 1 << 30,
    Popup = 1u << 31,
    PopupWindow = Popup | Border | SysMenu,
}

[Flags]
public enum WindowExStyle : uint
{
    Left = 0u,
    LtrReading = 0u,
    DialogModalFrame = 1 << 0,
    Unused1 = 1 << 1,
    NoParentNotify = 1 << 2,
    TopMost = 1 << 3,
    AcceptFiles = 1 << 4,
    Transparent = 1 << 5,
    MdiChild = 1 << 6,
    ToolWindow = 1 << 7,
    WindowEdge = 1 << 8,
    PaletteWindow = WindowEdge | ToolWindow | TopMost,
    OverlappedWindow = WindowEdge | ClientEdge,
    ClientEdge = 1 << 9,
    ContextHelp = 1 << 10,
    MakeVisibleWhenUnghosted = 1 << 11,
    Right = 1 << 12,
    RtlReading = 1 << 13,
    LeftScrollBar = 1 << 14,
    Unused2 = 1 << 15,
    ControlParent = 1 << 16,
    StaticEdge = 1 << 17,
    AppWindow = 1 << 18,
    Layered = 1 << 19,
    NoInheritLayout = 1 << 20,
    NoRedirectionBitmap = 1 << 21,
    LayoutRtl = 1 << 22,
    NoPaddedBorder = 1 << 23,
    Unused4 = 1 << 24,
    Composited = 1 << 25,
    UIStateActive = 1 << 26,
    NoActivate = 1 << 27,
    CompositedCompositing = 1 << 28,
    Redirected = 1 << 29,
    UIStateKbdAccelHidden = 1 << 30,
    UIStateFocusRectHidden = 1u << 31,
}

public sealed unsafe class WindowInfo
{
    private HWND _hwnd;

    private Data _data;

    private struct Data
    {
        public RECT Rect;

        public bool IsRectSet;

        public string? WindowText;

        public WINDOWINFO Info;

        public bool IsInfoSet;

        public HINSTANCE Instance;

        public string? ClassName;

        public uint ProcessId;

        public bool IsProcessIdSet;

        public Process? Process;
    }

    public WindowInfo(nint hwnd)
    {
        _hwnd = (HWND)hwnd;
    }

    public nint Handle => _hwnd;

    public Process Process
    {
        get
        {
            if (_data.Process is not null)
            {
                return _data.Process;
            }

            return _data.Process = Process.GetProcessById(unchecked((int)ProcessId));
        }
    }

    internal uint ProcessId
    {
        get
        {
            if (_data.IsProcessIdSet)
            {
                return _data.ProcessId;
            }

            fixed (uint* pPid = &_data.ProcessId)
            {
                uint threadId = Interop.GetWindowThreadProcessId(_hwnd, pPid);
                if (threadId is 0)
                {
                    throw new Win32Exception();
                }

            }

            _data.IsProcessIdSet = true;
            return _data.ProcessId;
        }
    }

    public string ClassName
    {
        get
        {
            if (_data.ClassName is not null)
            {
                return _data.ClassName;
            }

            return _data.ClassName = GetClassName(_hwnd);

            [SkipLocalsInit]
            static unsafe string GetClassName(HWND hwnd)
            {
                const int MaxClassNameLength = 0x100;
                char* buff = stackalloc char[MaxClassNameLength];
                Unsafe.InitBlock(
                    buff,
                    0,
                    MaxClassNameLength * sizeof(char));

                int length = Interop.GetClassName(hwnd, buff, MaxClassNameLength);
                if (length is 0)
                {
                    throw new Win32Exception();
                }

                return new string(buff, 0, length);
            }
        }
    }

    private ref WINDOWINFO Info
    {
        get
        {
            if (!_data.IsInfoSet)
            {
                fixed (WINDOWINFO* pInfo = &_data.Info)
                {
                    if (!Interop.GetWindowInfo(_hwnd, pInfo))
                    {
                        throw new Win32Exception();
                    }

                    _data.IsInfoSet = true;
                }
            }

            return ref _data.Info;
        }
    }

    public string Text
    {
        get
        {
            if (_data.WindowText is not null)
            {
                return _data.WindowText;
            }

            int length = Interop.GetWindowTextLength(_hwnd);
            if (length is 0)
            {
                int hr = Marshal.GetLastPInvokeError();
                if (hr is 0)
                {
                    return _data.WindowText = "";
                }

                throw new Win32Exception(hr);
            }

            return _data.WindowText = GetText(_hwnd, length);

            [SkipLocalsInit]
            static string GetText(HWND hwnd, int length)
            {
                int lengthWithTerm = length + 1;
                const int Threshold = 0x200;
                char[]? arrayToReturn = null;
                try
                {
                    Span<char> buffer = lengthWithTerm > Threshold
                        ? arrayToReturn = ArrayPool<char>.Shared.Rent(lengthWithTerm)
                        : stackalloc char[Threshold];

                    Unsafe.InitBlock(
                        ref Unsafe.As<char, byte>(ref MemoryMarshal.GetReference(buffer)),
                        0,
                        0x200 * sizeof(char));

                    fixed (char* pBuffer = buffer)
                    {
                        int resultCount = Interop.GetWindowText(
                            hwnd,
                            pBuffer,
                            lengthWithTerm);

                        return buffer[0..resultCount].ToString();
                    }
                }
                finally
                {
                    if (arrayToReturn is not null)
                    {
                        ArrayPool<char>.Shared.Return(arrayToReturn);
                    }
                }
            }
        }
    }

    public Rect WindowArea => Unsafe.As<RECT, Rect>(ref Info.rcWindow);

    public Rect ClientArea => Unsafe.As<RECT, Rect>(ref Info.rcClient);

    public WindowStyle Style => Unsafe.As<WINDOW_STYLE, WindowStyle>(ref Info.dwStyle);

    public WindowExStyle ExStyle => Unsafe.As<WINDOW_EX_STYLE, WindowExStyle>(ref Info.dwExStyle);

    public bool IsActive => Info.dwWindowStatus is 0x01;

    public uint BorderWidth => Info.cxWindowBorders;

    public uint BorderHeight => Info.cyWindowBorders;

    public ushort CreatorVersion => Info.wCreatorVersion;

    public void Refresh()
    {
        _data = default;
        // _isInfoSet = false;
        // _windowText = null;
    }
}