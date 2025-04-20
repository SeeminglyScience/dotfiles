namespace Profile.Links;

public unsafe struct DarwinLink
{
    public DataBlockHeader dbh;

    internal PathInlineArray<byte> _szDarwinId;

    public byte[] szDarwinId =>_szDarwinId.Span.ToArray();

    internal PathInlineArray<char> _szwDarwinId;

    public char[] szwDarwinId => _szwDarwinId.Span.ToArray();
}
