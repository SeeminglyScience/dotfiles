using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("9fc2b0bb-e446-44e2-aa61-9cab8f636af2")]
public unsafe partial struct IAsyncOperation<T> where T : unmanaged
{
    public partial HResult put_Completed(IAsyncOperationCompletedHandler<T>* handler);
    public partial HResult get_Completed(IAsyncOperationCompletedHandler<T>** handler);
    public partial HResult GetResults(T* results);

    public partial interface Interface : IMustImplement<IAsyncInfo>
    {
    }
}
