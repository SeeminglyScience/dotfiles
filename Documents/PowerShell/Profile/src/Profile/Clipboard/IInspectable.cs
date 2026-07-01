using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IUnknown>("af86e2e0-b12d-4c6a-9c5a-d7aa65101e90")]
public unsafe partial struct IInspectable
{
    public partial int GetIids(uint* iidCount, Guid** riid);
    public partial int GetRuntimeClassName(HSTRING* className);
    public partial HResult GetTrustLevel(int* trustLevel);
}
