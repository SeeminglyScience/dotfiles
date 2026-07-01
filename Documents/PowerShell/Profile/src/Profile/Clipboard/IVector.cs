using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("19fda3e9-11a1-4345-a3a2-4e7f956e222d")]
public unsafe partial struct IVector<T> where T : unmanaged
{
    public partial HResult GetAt(uint index, T* item);
    public partial HResult get_Size(uint* size);
    public partial HResult GetView(ComPtr<IVectorView<T>>* view);
    public partial HResult IndexOf(T value, uint* index, RTBool* found);
    public partial HResult SetAt(uint index, T item);
    public partial HResult InsertAt(uint index, T item);
    public partial HResult RemoveAt(uint index);
    public partial HResult Append(T item);
    public partial HResult RemoveAtEnd();
    public partial HResult Clear();
    public partial HResult GetMany(uint startIndex, uint capacity, T* value, uint* actual);
    public partial HResult ReplaceAll(uint count, T* value);

    public partial interface Interface : IMustImplement<IIterable<T>>
    {
    }
}
