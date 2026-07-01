using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("6a79e863-4300-459a-9966-cbb660963ee1")]
public unsafe partial struct IIterator<T> where T : unmanaged
{
    public partial HResult get_Current(T* current);
    public partial HResult get_HasCurrent(RTBool* hasCurrent);
    public partial HResult MoveNext(RTBool* hasCurrent);
    public partial HResult GetMany(uint capacity, T* value, uint* actual);
}
