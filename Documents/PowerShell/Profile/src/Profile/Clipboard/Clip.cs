using System.Runtime.InteropServices;

namespace Profile.Clipboard;

// public unsafe abstract class PwshComWrapper<T> : IDisposable
//     where T : unmanaged, IUnknown.Interface
// {
//     private bool _isDisposed;

//     protected T* Ptr;

//     protected PwshComWrapper(T* ptr)
//     {
//         ArgumentNullException.ThrowIfNull(ptr);
//         Ptr = ptr;
//     }

//     protected T* GetPtr()
//     {
//         ArgumentNullException.ThrowIfNull(Ptr);
//         return Ptr;
//     }

//     ~PwshComWrapper()
//     {
//         // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
//         Dispose(disposing: false);
//     }

//     public void Dispose()
//     {
//         // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
//         Dispose(disposing: true);
//         GC.SuppressFinalize(this);
//     }

//     protected void Dispose(bool disposing)
//     {
//         if (_isDisposed)
//         {
//             return;
//         }

//         if (disposing)
//         {
//             // TODO: dispose managed state (managed objects)
//         }

//         ReleaseExtraCom();
//         if (Ptr is not null)
//         {
//             Ptr->Release();
//             Ptr = null;
//         }

//         _isDisposed = true;
//     }

//     protected virtual void ReleaseExtraCom()
//     {
//     }
// }

// public unsafe sealed class ClipboardHistoryItem : PwshComWrapper<IClipboardHistoryItem>
// {
//     public ClipboardHistoryItem(IClipboardHistoryItem* ptr) : base(ptr)
//     {
//     }

//     public string Id
//     {
//         get
//         {
//             HSTRING hstring = default;
//             GetPtr()->get_Id(&hstring).AssertSuccess();
//             return hstring.ToString();
//         }
//     }
// }

// public unsafe sealed class DataPackageView : PwshComWrapper<IDataPackageView>
// {
//     public DataPackageView(IDataPackageView* ptr) : base(ptr)
//     {
//         ptr->
//     }


// }

// public static unsafe class Clip
// {
//     public static object[] GetHistory()
//     {
//         using ComPtr<IClipboardStatics2> clip = WinRT.Create<IClipboardStatics2>();
//         IAsyncOperation<ComPtr<IClipboardHistoryItemsResult>>* asyncOp = null;
//         clip.Value->GetHistoryItemsAsync(&asyncOp).AssertSuccess();
//         using ComPtr<IClipboardHistoryItemsResult> results = asyncOp->AsTask().GetAwaiter().GetResult();
//         IVectorView<ComPtr<IClipboardHistoryItem>>* pHistory = null;
//         results.Value->get_Items(&pHistory).AssertSuccess();
//         using ComPtr<IVectorView<ComPtr<IClipboardHistoryItem>>> history = pHistory;
//         uint size = 0;
//         history.Value->get_Size(&size).AssertSuccess();

//         ComPtr<IClipboardHistoryItem>* buffer = stackalloc ComPtr<IClipboardHistoryItem>[0x20];
//         uint index = 0;
//         while (true)
//         {
//             uint count = 0;
//             history.Value->GetMany(index, 0x20, buffer, &count).AssertSuccess();
//             index += count;
//             if (count is 0)
//             {
//                 break;
//             }

//             for (uint i = 0; i < count; i++)
//             {
//                 using ComPtr<IClipboardHistoryItem> item = buffer[i];
//                 IDataPackageView* pContent = null;
//                 item.Value->get_Content(&pContent).AssertSuccess();
//                 using ComPtr<IDataPackageView> content = pContent;
//                 // content.Value->
//                 // finish this
//                 return null!;
//             }
//         }

//         return null!;
//     }
// }

internal unsafe static partial class Interop
{
    [LibraryImport("api-ms-win-core-winrt-string-l1-1-0.dll", StringMarshalling = StringMarshalling.Utf16)]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    internal static partial char* WindowsGetStringRawBuffer(
        HSTRING @string,
        uint* length);

    [LibraryImport("api-ms-win-core-winrt-string-l1-1-0.dll", StringMarshalling = StringMarshalling.Utf16)]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    internal static partial HResult WindowsCreateStringReference(
        char* sourceString,
        uint length,
        HSTRING_HEADER* hstringHeader,
        HSTRING* @string);

    [LibraryImport("api-ms-win-core-winrt-l1-1-0.dll")]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    internal static partial HResult RoGetActivationFactory(HSTRING activatableClassId, Guid* iid, void** factory);
}