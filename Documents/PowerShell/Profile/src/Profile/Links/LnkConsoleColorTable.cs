namespace Profile.Links;

public sealed class LnkConsoleColorTable
{
    private readonly Memory<LnkConsoleColorRef> _colorTable;

    public LnkConsoleColorTable(Memory<LnkConsoleColorRef> colorTable) => _colorTable = colorTable;

    public LnkConsoleColorRef this[int index]
    {
        get => Table[index];
        set => Table[index] = value;
    }

    private Span<LnkConsoleColorRef> Table => _colorTable.Span;
}