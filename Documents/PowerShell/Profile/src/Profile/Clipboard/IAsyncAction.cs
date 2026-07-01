using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("5a648006-843a-4da9-865b-9d26e5dfad7b")]
public unsafe partial struct IAsyncAction : IHasWinRTTypeName
{
    public static string WinRTTypeName => "Windows.Foundation.IAsyncAction";
    public partial HResult put_Completed(/* ABI::Windows::Foundation::IAsyncActionCompletedHandler* */ void* handler);
    public partial HResult get_Completed(/* ABI::Windows::Foundation::IAsyncActionCompletedHandler** */ void** handler);
    public partial HResult GetResults();

    public partial interface Interface : IMustImplement<IAsyncInfo>
    {
    }
}
