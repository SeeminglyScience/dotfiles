using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("905a0fe2-bc53-11df-8c49-001e4fc686da")]
public unsafe partial struct IInputStream
{
    public partial HResult ReadAsync(
        IBuffer* buffer,
        uint count,
        InputStreamOptions options,
        IAsyncOperationWithProgress<ComPtr<IBuffer>, ptr<uint>>** operation);
}
