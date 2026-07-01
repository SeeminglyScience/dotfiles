using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("9e365e57-48b2-4160-956f-c7385120bbfc")]
public unsafe partial struct IUriRuntimeClass
{
    public partial HResult get_AbsoluteUri(HSTRING* value);
    public partial HResult get_DisplayUri(HSTRING* value);
    public partial HResult get_Domain(HSTRING* value);
    public partial HResult get_Extension(HSTRING* value);
    public partial HResult get_Fragment(HSTRING* value);
    public partial HResult get_Host(HSTRING* value);
    public partial HResult get_Password(HSTRING* value);
    public partial HResult get_Path(HSTRING* value);
    public partial HResult get_Query(HSTRING* value);
    public partial HResult get_QueryParsed(/* ABI::Windows::Foundation::IWwwFormUrlDecoderRuntimeClass** */ void** ppWwwFormUrlDecoder);
    public partial HResult get_RawUri(HSTRING* value);
    public partial HResult get_SchemeName(HSTRING* value);
    public partial HResult get_UserName(HSTRING* value);
    public partial HResult get_Port(int* value);
    public partial HResult get_Suspicious(RTBool* value);
    public partial HResult Equals(IUriRuntimeClass* pUri, RTBool* value);
    public partial HResult CombineUri(HSTRING relativeUri, IUriRuntimeClass** instance);
}
