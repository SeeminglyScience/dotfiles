using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>]
public unsafe partial struct IMapView<TKey, TValue>
    where TKey : unmanaged
    where TValue : unmanaged
{
    public partial HResult Lookup(TKey key, TValue* value);
    public partial HResult get_Size(uint* size);
    public partial HResult HasKey(TKey key, RTBool* found);
    public partial HResult Split(IMapView<TKey, TValue>** firstPartition, IMapView<TKey, TValue>** secondPartition);
}
