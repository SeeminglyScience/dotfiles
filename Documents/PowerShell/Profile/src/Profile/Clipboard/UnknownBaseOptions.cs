namespace Profile.Clipboard;

internal class UnknownBaseOptions
{
    public delegate HResult QueryInterfaceDelegate(UnknownBase* self, Guid* riid, IUnknown** ppvObject);

    public delegate void OnFinalReleaseDelegate(UnknownBase* self);

    public OnFinalReleaseDelegate? OnFinalRelease { get; init; }

    public QueryInterfaceDelegate? QueryFallback { get; init; }

    public object? State { get; init; }
}
