using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("905a0fe0-bc53-11df-8c49-001e4fc686da")]
public unsafe partial struct IBuffer
{
    public partial HResult get_Capacity(uint* value);
    public partial HResult get_Length(uint* value);
    public partial HResult put_Length(uint value);
}
