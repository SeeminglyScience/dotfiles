using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("faa585ea-6214-4217-afda-7f46de5869b3")]
public unsafe partial struct IIterable<T> where T : unmanaged
{
    public partial HResult First(ComPtr<IIterator<T>>* first);
}
