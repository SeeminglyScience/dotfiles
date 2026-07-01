using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

public interface IMustImplement<T> where T : unmanaged, IUnknown.Interface, IComIid
{
}
