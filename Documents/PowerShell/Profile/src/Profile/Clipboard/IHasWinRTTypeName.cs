using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

internal interface IHasWinRTTypeName
{
    static abstract string WinRTTypeName { get; }
}

internal static class WinRT
{
    public static unsafe ComPtr<TWinRT> Create<TWinRT>() where TWinRT : unmanaged, IComIid, IHasWinRTTypeName, IInspectable.Interface
    {
        string typeName = TWinRT.WinRTTypeName;
        fixed (char* pName = typeName)
        {
            HSTRING_HEADER header = default;
            HSTRING hTypeName = null;
            Interop.WindowsCreateStringReference(
                pName,
                (uint)typeName.Length,
                &header,
                &hTypeName)
                .AssertSuccess();

            TWinRT* result = null;
            Interop.RoGetActivationFactory(hTypeName, TWinRT.IID, (void**)&result)
                .AssertSuccess();

            return result;
        }
    }
}