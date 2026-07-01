using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("00000036-0000-0000-C000-000000000046")]
public unsafe partial struct IAsyncInfo
{
    public partial HResult get_Id(uint* id);

    public partial HResult get_Status(AsyncStatus* status);

    public partial HResult get_ErrorCode(HResult* errorCode);

    public partial HResult Cancel();

    public partial HResult Close();
}
