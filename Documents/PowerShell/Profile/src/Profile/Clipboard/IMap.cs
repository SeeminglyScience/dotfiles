using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>]
public unsafe partial struct IMap<TKey, TValue>
    where TKey : unmanaged
    where TValue : unmanaged
{
    public partial HResult Lookup(TKey key, TValue* value);
    public partial HResult get_Size(uint* size);
    public partial HResult HasKey(TKey key, RTBool* found);
    public partial HResult GetView(IMapView<TKey, TValue>** view);
    public partial HResult Insert(TKey key, TValue value, RTBool* replaced);
    public partial HResult Remove(TKey key);
    public partial HResult Clear();
}
