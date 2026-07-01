using System.Runtime.InteropServices;

namespace Profile.Clipboard;

public static unsafe class Clip
{
    public static object[] GetHistory()
    {
        using ComPtr<IClipboardStatics2> clip = WinRT.Create<IClipboardStatics2>();
        IAsyncOperation<ComPtr<IClipboardHistoryItemsResult>>* asyncOp = null;
        clip.Value->GetHistoryItemsAsync(&asyncOp).AssertSuccess();
        using ComPtr<IClipboardHistoryItemsResult> results = asyncOp->AsTask().GetAwaiter().GetResult();
        IVectorView<ComPtr<IClipboardHistoryItem>>* pHistory = null;
        results.Value->get_Items(&pHistory).AssertSuccess();
        using ComPtr<IVectorView<ComPtr<IClipboardHistoryItem>>> history = pHistory;
        uint size = 0;
        history.Value->get_Size(&size).AssertSuccess();

        ComPtr<IClipboardHistoryItem>* buffer = stackalloc ComPtr<IClipboardHistoryItem>[0x20];
        uint index = 0;
        while (true)
        {
            uint count = 0;
            history.Value->GetMany(index, 0x20, buffer, &count).AssertSuccess();
            index += count;
            if (count is 0)
            {
                break;
            }

            for (uint i = 0; i < count; i++)
            {
                using ComPtr<IClipboardHistoryItem> item = buffer[i];
                IDataPackageView* pContent = null;
                item.Value->get_Content(&pContent).AssertSuccess();
                using ComPtr<IDataPackageView> content = pContent;
                // content.Value->
                // finish this
                return null!;
            }
        }
    }
}

internal unsafe static partial class Interop
{
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