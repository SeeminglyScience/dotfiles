using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IUnknown>("fcdcf02c-e5d8-4478-915a-4d90b74b83a5")]
public unsafe partial struct IAsyncOperationCompletedHandler<T> where T : unmanaged
{
    public partial HResult Invoke(IAsyncOperation<T>* asyncInfo, AsyncStatus asyncStatus);
}
