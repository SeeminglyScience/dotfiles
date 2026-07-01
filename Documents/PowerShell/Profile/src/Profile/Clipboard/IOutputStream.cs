using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("905a0fe6-bc53-11df-8c49-001e4fc686da")]
public unsafe partial struct IOutputStream
{
    public partial HResult WriteAsync(IBuffer* buffer, IAsyncOperationWithProgress<uint, uint>** operation);
    public partial HResult FlushAsync(IAsyncOperation<RTBool>** operation);
}
