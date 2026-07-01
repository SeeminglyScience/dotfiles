using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("4207a996-ca2f-42f7-bde8-8b10457a7f30")]
public unsafe partial struct IStorageItem
{
    public partial HResult RenameAsyncOverloadDefaultOptions(HSTRING desiredName, IAsyncAction** operation);
    public partial HResult RenameAsync(HSTRING desiredName, /* NameCollisionOption */ int option, IAsyncAction** operation);
    public partial HResult DeleteAsyncOverloadDefaultOptions(IAsyncAction** operation);
    public partial HResult DeleteAsync(/* StorageDeleteOption */ int option, IAsyncAction** operation);
    public partial HResult GetBasicPropertiesAsync(/* __FIAsyncOperation_1_Windows__CStorage__CFileProperties__CBasicProperties** */ void* operation);
    public partial HResult get_Name(HSTRING* value);
    public partial HResult get_Path(HSTRING* value);
    public partial HResult get_Attributes(/* ABI::Windows::Storage::FileAttributes* */ FileAttributes* value);
    public partial HResult get_DateCreated(/* ABI::Windows::Foundation::DateTime* */ void* value);
    public partial HResult IsOfType(/* ABI::Windows::Storage::StorageItemTypes */ int type, RTBool* value);
}
