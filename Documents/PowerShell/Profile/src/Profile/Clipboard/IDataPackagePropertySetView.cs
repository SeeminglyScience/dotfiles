using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("b94cec01-0c1a-4c57-be55-75d01289735d")]
public unsafe partial struct IDataPackagePropertySetView
{
    public partial HResult get_Title(HSTRING* value);
    public partial HResult get_Description(HSTRING* value);
    public partial HResult get_Thumbnail(IRandomAccessStreamReference** value);
    public partial HResult get_FileTypes(IVectorView<HSTRING>** value);
    public partial HResult get_ApplicationName(HSTRING* value);
    public partial HResult get_ApplicationListingUri(IUriRuntimeClass** value);
}
