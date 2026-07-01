using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("b5d036d7-e297-498f-ba60-0289e76e23dd")]
public unsafe partial struct IAsyncOperationWithProgress<TResult, TProgress>
    where TResult : unmanaged
    where TProgress : unmanaged
{
    public partial HResult put_Progress(/* IAsyncOperationProgressHandler<TResult_logical, TProgress_logical>* */ void* handler);

    public partial HResult get_Progress(/* IAsyncOperationProgressHandler<TResult_logical, TProgress_logical>** */ void** handler);

    public partial HResult put_Completed(/* IAsyncOperationWithProgressCompletedHandler<TResult_logical, TProgress_logical>* */ void* handler);

    public partial HResult get_Completed(/* IAsyncOperationWithProgressCompletedHandler<TResult_logical, TProgress_logical>** */ void** handler);

    public partial HResult GetResults(TResult* results);
}
