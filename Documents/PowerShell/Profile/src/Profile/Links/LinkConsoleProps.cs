using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Profile.Links;

internal unsafe struct LnkConsoleProps
{
    public DataBlockHeader dbh;
    public ushort wFillAttribute;
    public ushort wPopupFillAttribute;
    public LnkCoord dwScreenBufferSize;
    public LnkCoord dwWindowSize;
    public LnkCoord dwWindowOrigin;
    public uint nFont;
    public uint nInputBufferSize;
    public LnkCoord dwFontSize;
    public uint uFontFamily;
    public uint uFontWeight;
    public FaceNameInlineArray<char> FaceName;
    public uint uCursorSize;
    public int bFullScreen;
    public int bQuickEdit;
    public int bInsertMode;
    public int bAutoPosition;
    public uint uHistoryBufferSize;
    public uint uNumberOfHistoryBuffers;
    public int bHistoryNoDup;
    public ColorTableInlineArray ColorTable;

    [InlineArray(Length)]
    internal struct ColorTableInlineArray
    {
        public const int Length = 16;

        private uint _element0;

        public Span<uint> Span => MemoryMarshal.CreateSpan(ref _element0, Length);
    }
}
