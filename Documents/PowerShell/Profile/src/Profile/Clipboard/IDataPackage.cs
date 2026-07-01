using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("61ebf5c7-efea-4346-9554-981d7e198ffe")]
public unsafe partial struct IDataPackage
{
    public partial HResult GetView(ComPtr<IDataPackageView>* result);
    public partial HResult get_Properties(ComPtr<IDataPackagePropertySet>* value);
    public partial HResult get_RequestedOperation(DataPackageOperation* value);
    public partial HResult put_RequestedOperation(DataPackageOperation value);
    public partial HResult add_OperationCompleted(
        /* __FITypedEventHandler_2_Windows__CApplicationModel__CDataTransfer__CDataPackage_Windows__CApplicationModel__CDataTransfer__COperationCompletedEventArgs* */ void* handler,
        EventRegistrationToken * token
        );
    public partial HResult remove_OperationCompleted(EventRegistrationToken token);
    public partial HResult add_Destroyed(
        /* __FITypedEventHandler_2_Windows__CApplicationModel__CDataTransfer__CDataPackage_IInspectable* */ void* handler,
        EventRegistrationToken* token);
    public partial HResult remove_Destroyed(EventRegistrationToken token);
    public partial HResult SetData(HSTRING formatId, IInspectable* value);
    public partial HResult SetDataProvider(
        HSTRING formatId,
        /* ABI::Windows::ApplicationModel::DataTransfer::IDataProviderHandler* */ void* delayRenderer);
    public partial HResult SetText(HSTRING value);

    [Obsolete("SetUri may be altered or unavailable for releases after Windows Phone 'OSVersion' (TBD).Instead, use SetWebLink or SetApplicationLink.")]
    public partial HResult SetUri(IUriRuntimeClass* value);
    public partial HResult SetHtmlFormat(HSTRING value);
    public partial HResult get_ResourceMap(IMap<HSTRING, ComPtr<IRandomAccessStreamReference>>** value);
    public partial HResult SetRtf(HSTRING value);
    public partial HResult SetBitmap(IRandomAccessStreamReference* value);
    public partial HResult SetStorageItemsReadOnly(/* __FIIterable_1_Windows__CStorage__CIStorageItem* */ void* value);
    public partial HResult SetStorageItems(
        /* __FIIterable_1_Windows__CStorage__CIStorageItem* */ void* value,
        RTBool readOnly);
};