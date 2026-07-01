using System.Runtime.InteropServices;
using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("cc254827-4b3d-438f-9232-10c76bc7e038")]
public partial struct IRandomAccessStreamWithContentType :
    IMustImplement<IRandomAccessStream>,
    IMustImplement<IInputStream>,
    IMustImplement<IOutputStream>,
    IMustImplement<IContentTypeProvider>,
    IMustImplement<IClosable>
{
    public partial interface Interface :
        IMustImplement<IRandomAccessStream>,
        IMustImplement<IInputStream>,
        IMustImplement<IOutputStream>,
        IMustImplement<IContentTypeProvider>,
        IMustImplement<IClosable>
    {
    }
}
