using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using System.Runtime.Versioning;

namespace Profile.Links;

[SupportedOSPlatform("windows6.0.6000")]
public unsafe partial class LnkConsoleSettings
{
    private readonly PinnedHeapRef<LnkConsoleProps> _props;

    private LnkConsoleSettings(PinnedHeapRef<LnkConsoleProps> props)
    {
        _props = props;
    }

    internal static LnkConsoleSettings Create(LnkFile shortcut)
    {
        PinnedHeapRef<LnkConsoleProps> props = PinnedHeapRef.Alloc<LnkConsoleProps>();
        LnkConsoleSettings result = new(props);

        shortcut.DataList->CopyDataBlock(
            (uint)LinkDataBlockSignature.Console,
            (void**)props.Ptr)
            .AssertSuccess();

        return result;
    }

    public ushort ForegroundColorIndex
    {
        get => _props.Ptr->wFillAttribute;
        set
        {
            Assert.IndexInRange(value < 16);
            _props.Ptr->wFillAttribute = value;
        }
    }

    public ushort PopupForegroundColorIndex
    {
        get => _props.Ptr->wPopupFillAttribute;
        set
        {
            Assert.IndexInRange(value < 16);
            _props.Ptr->wPopupFillAttribute = value;
        }
    }

    public LnkCoordProxy ScreenBufferSize => new(CreatePinnedHeapRef(&_props.Ptr->dwScreenBufferSize));

    public LnkCoordProxy WindowSize => new(CreatePinnedHeapRef(&_props.Ptr->dwWindowSize));

    public LnkCoordProxy WindowOrigin => new(CreatePinnedHeapRef(&_props.Ptr->dwWindowOrigin));

    public int FontIndex
    {
        get => (int)_props.Ptr->nFont;
        set
        {
            ArgumentOutOfRangeException.ThrowIfNegative(value);
            _props.Ptr->nFont = (uint)value;
        }
    }

    public int InputBufferSize
    {
        get => (int)_props.Ptr->nInputBufferSize;
        set
        {
            ArgumentOutOfRangeException.ThrowIfNegative(value);
            _props.Ptr->nInputBufferSize = (uint)value;
        }
    }

    public LnkCoordProxy FontSize => new(CreatePinnedHeapRef(&_props.Ptr->dwFontSize));

    public PitchAndFamily PitchAndFamily
    {
        get => (PitchAndFamily)_props.Ptr->uFontFamily;
        set => _props.Ptr->uFontFamily = (uint)value;
    }

    public int FontWeight
    {
        get => (int)_props.Ptr->uFontWeight;
        set
        {
            ArgumentOutOfRangeException.ThrowIfNegative(value);
            _props.Ptr->uFontWeight = (uint)value;
        }
    }

    public string FontFaceName
    {
        get => _props.Ptr->FaceName.Span.SliceToNull().ToString();
        set
        {
            ReadOnlySpan<char> valueSpan = value.AsSpan();
            if (valueSpan.Length > FaceNameInlineArray.LF_FACESIZE)
            {
                valueSpan = valueSpan[..FaceNameInlineArray.LF_FACESIZE];
            }

            Span<char> faceName = _props.Ptr->FaceName.Span;
            valueSpan.CopyTo(faceName);
            if (valueSpan.Length is not FaceNameInlineArray.LF_FACESIZE)
            {
                faceName[valueSpan.Length + 1] = '\0';
            }
        }
    }

    public int CursorSize
    {
        get => (int)_props.Ptr->uCursorSize;
        set
        {
            ArgumentOutOfRangeException.ThrowIfNegative(value);
            _props.Ptr->uCursorSize = (uint)value;
        }
    }

    public bool FullScreen
    {
        get => _props.Ptr->bFullScreen is not 0;
        set => _props.Ptr->bFullScreen = value ? 1 : 0;
    }

    public bool QuickEdit
    {
        get => _props.Ptr->bQuickEdit is not 0;
        set => _props.Ptr->bQuickEdit = value ? 1 : 0;
    }

    public bool InsertMode
    {
        get => _props.Ptr->bInsertMode is not 0;
        set => _props.Ptr->bInsertMode = value ? 1 : 0;
    }

    public bool AutoPosition
    {
        get => _props.Ptr->bAutoPosition is not 0;
        set => _props.Ptr->bAutoPosition = value ? 1 : 0;
    }

    public int HistoryBufferSize
    {
        get => (int)_props.Ptr->uHistoryBufferSize;
        set
        {
            ArgumentOutOfRangeException.ThrowIfNegative(value);
            _props.Ptr->uHistoryBufferSize = (uint)value;
        }
    }

    public int NumberOfHistoryBuffers
    {
        get => (int)_props.Ptr->uNumberOfHistoryBuffers;
        set
        {
            ArgumentOutOfRangeException.ThrowIfNegative(value);
            _props.Ptr->uNumberOfHistoryBuffers = (uint)value;
        }
    }

    public bool HistoryNoDuplicates
    {
        get => _props.Ptr->bHistoryNoDup is not 0;
        set => _props.Ptr->bHistoryNoDup = value ? 1 : 0;
    }

    internal void* Ptr => _props.Ptr;

    [field: MaybeNull]
    public LnkConsoleColorTable Colors =>
        field ??= new(
            CreateMemory(
                (LnkConsoleColorRef*)&_props.Ptr->ColorTable,
                LnkConsoleProps.ColorTableInlineArray.Length));

    internal Memory<T> CreateMemory<T>(T* ptr, int length)
        where T : unmanaged
    {
        return _props.CreateDerivedMemory(ptr, length).Memory;
    }

    internal PinnedHeapRef<T> CreatePinnedHeapRef<T>(T* ptr)
        where T : unmanaged
    {
        return _props.CreateDerivedRef(ptr);
    }

    public struct LnkCoordProxy
    {
        private readonly PinnedHeapRef<LnkCoord> _target;

        internal LnkCoordProxy(PinnedHeapRef<LnkCoord> target) => _target = target;

        public short X
        {
            get => _target.Value.X;
            set => _target.Value.X = value;
        }

        public short Y
        {
            get => _target.Value.Y;
            set => _target.Value.Y = value;
        }
    }
}
