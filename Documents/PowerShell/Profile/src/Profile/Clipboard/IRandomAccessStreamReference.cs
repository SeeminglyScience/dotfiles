using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("33ee3134-1dd6-4e3a-8067-d1c162e8642b")]
public unsafe partial struct IRandomAccessStreamReference
{
    public partial HResult OpenReadAsync(IAsyncOperation<ComPtr<IRandomAccessStreamWithContentType>>** operation);
}
