using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("7b840471-5900-4d85-a90b-10cb85fe3552")]
public unsafe partial struct IDataPackageView
{
    public partial HResult get_Properties(IDataPackagePropertySetView** value);
    public partial HResult get_RequestedOperation(DataPackageOperation* value);
    public partial HResult ReportOperationCompleted(DataPackageOperation value);
    public partial HResult get_AvailableFormats(IVectorView<HSTRING>** formatIds);
    public partial HResult Contains(HSTRING formatId, RTBool* value);
    public partial HResult GetDataAsync(HSTRING formatId, IAsyncOperation<ComPtr<IInspectable>>** operation);
    public partial HResult GetTextAsync(IAsyncOperation<HSTRING>** operation);
    public partial HResult GetCustomTextAsync(HSTRING formatId, IAsyncOperation<HSTRING>** operation);
    public partial HResult GetUriAsync(IUriRuntimeClass* operation);
    public partial HResult GetHtmlFormatAsync(IAsyncOperation<HSTRING>** operation);
    public partial HResult GetResourceMapAsync(
        IAsyncOperation<ComPtr<IMapView<HSTRING, ComPtr<IRandomAccessStreamReference>>>>** operation);
    public partial HResult GetRtfAsync(IAsyncOperation<HSTRING>** operation);
    public partial HResult GetBitmapAsync(IAsyncOperation<ComPtr<IRandomAccessStreamReference>>* operation);
    public partial HResult GetStorageItemsAsync(IAsyncOperation<ComPtr<IVectorView<ComPtr<IStorageItem>>>>** operation);
}
