using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("cd1c93eb-4c4c-443a-a8d3-f5c241e91689")]
public unsafe partial struct IDataPackagePropertySet
{
    public partial HResult get_Title(HSTRING* value);
    public partial HResult put_Title(HSTRING value);
    public partial HResult get_Description(HSTRING* value);
    public partial HResult put_Description(HSTRING value);
    public partial HResult get_Thumbnail(IRandomAccessStreamReference** value);
    public partial HResult put_Thumbnail(IRandomAccessStreamReference* value);
    public partial HResult get_FileTypes(IVector<HSTRING>** value);
    public partial HResult get_ApplicationName(HSTRING* value);
    public partial HResult put_ApplicationName(HSTRING value);
    public partial HResult get_ApplicationListingUri(IUriRuntimeClass** value);
    public partial HResult put_ApplicationListingUri(IUriRuntimeClass* value);
};
