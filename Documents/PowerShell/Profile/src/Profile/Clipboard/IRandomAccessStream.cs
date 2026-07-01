using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("905a0fe1-bc53-11df-8c49-001e4fc686da")]
public unsafe partial struct IRandomAccessStream
{
    public partial HResult get_Size(ulong* value);
    public partial HResult put_Size(ulong value);
    public partial HResult GetInputStreamAt(ulong position, IInputStream** stream);
    public partial HResult GetOutputStreamAt(ulong position, IOutputStream** stream);
    public partial HResult get_Position(ulong* value);
    public partial HResult Seek(ulong position);
    public partial HResult CloneStream(IRandomAccessStream** stream);
    public partial HResult get_CanRead(RTBool* value);
    public partial HResult get_CanWrite(RTBool* value);
}
