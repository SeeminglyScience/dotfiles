using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct<IInspectable>("71af914d-c10f-484b-bc50-14bc623b3a27")]
public unsafe partial struct IBufferFactory : IHasWinRTTypeName
{
    public static string WinRTTypeName => "Windows.Storage.Streams.IBufferFactory";
    public partial HResult Create(uint capacity, IBuffer** value);
}
