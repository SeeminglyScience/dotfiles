using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

internal static unsafe class WinRTAsyncExtensions
{
    extension<T>(ref IAsyncOperation<T> operation) where T : unmanaged
    {
        public Task<T> AsTask() => WinRTAsyncOperationCompletedCallback.AsTask(operation.ToPointer());
    }
}

internal unsafe struct WinRTAsyncOperationCompletedCallback
{
    public delegate HResult CompletedDelegate<T>(
        IAsyncOperationCompletedHandler<T>* self,
        IAsyncOperation<T>* asyncInfo,
        AsyncStatus status)
        where T : unmanaged;

    private delegate HResult DelegateImpl(UnknownBase* self, void* asyncInfo, AsyncStatus status);

    private static void** s_vtbl;

    static WinRTAsyncOperationCompletedCallback()
    {
        int size = GetVtblSize<IAsyncOperationCompletedHandler<nint>>();
        s_vtbl = (void**)RuntimeHelpers.AllocateTypeAssociatedMemory(
            typeof(WinRTAsyncOperationCompletedCallback),
            size);

        UnknownBase.AddToVtbl(s_vtbl);
        s_vtbl[GetVtblSize<IUnknown>()] = (delegate* unmanaged[Stdcall]<UnknownBase*, void*, AsyncStatus, HResult>)&Invoke;
    }

    public static Task<TResult> AsTask<TResult>(IAsyncOperation<TResult>* operation) where TResult : unmanaged
    {
        TaskCompletionSource<TResult> tcs = new();
        IAsyncOperationCompletedHandler<TResult>* handler = Alloc<TResult>(
            (self, op, status) =>
            {
                if (status is AsyncStatus.Error)
                {
                    using ComPtr<IAsyncInfo> info = op->GetAsyncInfo();
                    HResult errorCode = default;
                    HResult hr = info.Value->get_ErrorCode(&errorCode);
                    if (hr.Success)
                    {
                        tcs.TrySetException(new Win32Exception(errorCode));
                    }

                    op->Release();
                    return hr;
                }

                if (status is AsyncStatus.Canceled)
                {
                    tcs.TrySetCanceled();
                    op->Release();
                    return 0;
                }

                if (status is AsyncStatus.Completed)
                {
                    TResult result = default;
                    HResult hr = op->GetResults(&result);
                    if (hr.Success)
                    {
                        tcs.TrySetResult(result);
                    }

                    op->Release();
                    return hr;
                }

                op->Release();
                return 0;
            });

        operation->put_Completed(handler).AssertSuccess();
        return tcs.Task;
    }

    public static IAsyncOperationCompletedHandler<T>* Alloc<T>(CompletedDelegate<T> onCompleted) where T : unmanaged
    {
        IAsyncOperationCompletedHandler<T>* handler = (IAsyncOperationCompletedHandler<T>*)UnknownBase.Alloc(
            s_vtbl,
            IAsyncOperationCompletedHandler<T>.IID,
            new UnknownBaseOptions()
            {
                State = new DelegateImpl((self, op, status)
                    => onCompleted(
                        (IAsyncOperationCompletedHandler<T>*)self,
                        (IAsyncOperation<T>*)op,
                        status))
            });

        handler->AddRef();
        return handler;
    }

    private static int GetVtblSize<T>() where T : IHasVtbl
    {
        return T.GetVtblSize();
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    public static HResult Invoke(UnknownBase* self, void* asyncInfo, AsyncStatus status)
    {
        const int E_UNEXPECTED = unchecked((int)0x8000FFFF);
        if (!self->TryGetOptions(out UnknownBaseOptions? options))
        {
            return E_UNEXPECTED;
        }

        if (options.State is not DelegateImpl callback)
        {
            return E_UNEXPECTED;
        }

        return callback(self, asyncInfo, status);
    }
}
