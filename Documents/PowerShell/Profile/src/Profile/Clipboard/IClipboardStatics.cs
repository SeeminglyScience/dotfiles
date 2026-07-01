using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("c627e291-34e2-4963-8eed-93cbb0ea3d70")]
public unsafe partial struct IClipboardStatics : IHasWinRTTypeName
{
    public static string WinRTTypeName => "Windows.ApplicationModel.DataTransfer.IClipboardStatics";
    public partial HResult GetContent(IDataPackageView** result);
    public partial HResult SetContent(IDataPackage* content);
    public partial HResult Flush();
    public partial HResult Clear();
    public partial HResult add_ContentChanged(/*__FIEventHandler_1_IInspectable* */ void* handler, EventRegistrationToken* token);
    public partial HResult remove_ContentChanged(EventRegistrationToken token);
}

public enum ClipboardHistoryItemsResultStatus
{
    Success = 0,
    AccessDenied = 1,
    ClipboardHistoryDisabled = 2,
}
[ComStruct<IInspectable>("e6dfdee6-0ee2-52e3-852b-f295db65939a")]
public unsafe partial struct IClipboardHistoryItemsResult
{
    public partial HResult get_Status(ClipboardHistoryItemsResultStatus* value);
    public partial HResult get_Items(IVectorView<ComPtr<IClipboardHistoryItem>>** value);
}

[ComStruct<IInspectable>("0173bd8a-afff-5c50-ab92-3d19f481ec58")]
public unsafe partial struct IClipboardHistoryItem
{
    public partial HResult get_Id(HSTRING* value);
    public partial HResult get_Timestamp(DateTime* value);
    public partial HResult get_Content(IDataPackageView** value);
}

public enum SetHistoryItemAsContentStatus
{
    Success = 0,
    AccessDenied = 1,
    ItemDeleted = 2,
}

[ComStruct<IInspectable>("d2ac1b6a-d29f-554b-b303-f0452345fe02")]
public unsafe partial struct IClipboardStatics2 : IHasWinRTTypeName
{
    public static string WinRTTypeName => "Windows.ApplicationModel.DataTransfer.IClipboardStatics2";
    public partial HResult GetHistoryItemsAsync(IAsyncOperation<ComPtr<IClipboardHistoryItemsResult>>** operation);
    public partial HResult ClearHistory(RTBool* result);
    public partial HResult DeleteItemFromHistory(IClipboardHistoryItem* item, RTBool* result);
    public partial HResult SetHistoryItemAsContent(IClipboardHistoryItem* item, SetHistoryItemAsContentStatus* result);
    public partial HResult IsHistoryEnabled(RTBool* result);
    public partial HResult IsRoamingEnabled(RTBool* result);
    public partial HResult SetContentWithOptions(IDataPackage* content, IClipboardContentOptions* options, RTBool* result);
    public partial HResult add_HistoryChanged(
        /* __FIEventHandler_1_Windows__CApplicationModel__CDataTransfer__CClipboardHistoryChangedEventArgs* */ void* handler,
        EventRegistrationToken* token);
    public partial HResult remove_HistoryChanged(EventRegistrationToken token);
    public partial HResult add_RoamingEnabledChanged(
        /* __FIEventHandler_1_IInspectable* */ void* handler,
        EventRegistrationToken* token);
    public partial HResult remove_RoamingEnabledChanged(EventRegistrationToken token);
    public partial HResult add_HistoryEnabledChanged(
        /* __FIEventHandler_1_IInspectable* */ void* handler,
        EventRegistrationToken* token);

    public partial HResult remove_HistoryEnabledChanged(EventRegistrationToken token);
}

[ComStruct<IInspectable>("e888a98c-ad4b-5447-a056-ab3556276d2b")]
public unsafe partial struct IClipboardContentOptions : IHasWinRTTypeName
{
    public static string WinRTTypeName => "Windows.ApplicationModel.DataTransfer.IClipboardContentOptions";
    public partial HResult get_IsRoamable(RTBool* value);
    public partial HResult put_IsRoamable(RTBool value);
    public partial HResult get_IsAllowedInHistory(RTBool* value);
    public partial HResult put_IsAllowedInHistory(RTBool value);
    public partial HResult get_RoamingFormats(IVector<HSTRING>** value);
    public partial HResult get_HistoryFormats(IVector<HSTRING>** value);
}