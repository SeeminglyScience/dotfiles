using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("bbe1fa4c-b0e3-4583-baef-1f1b2e483e56")]
public unsafe partial struct IVectorView<T> where T : unmanaged
{
    public partial HResult GetAt(uint index, T* item);
    public partial HResult get_Size(uint* size);
    public partial HResult IndexOf(T value, uint* index, RTBool* found);
    public partial HResult GetMany(uint startIndex, uint capacity, T* value, uint* actual);

    public partial interface Interface : IMustImplement<IIterable<T>>
    {
    }
}
