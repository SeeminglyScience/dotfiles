using System.Runtime;
using System.Runtime.CompilerServices;
using SeeminglyScience.ComGenerator;

namespace Profile.Clipboard;

[ComStruct("00000000-0000-0000-c000-000000000046")]
public unsafe partial struct IUnknown
{
    public partial HResult QueryInterface(Guid* riid, IUnknown** ppvObject);

    public partial int AddRef();

    public partial int Release();
}

internal static unsafe class IUnknownExtensions
{
    extension<TComObject>(ref TComObject self) where TComObject : unmanaged, IUnknown.Interface
    {
        public ComPtr<TComObject> Handle => self.ToPointer();

        public HResult QueryInterface<TResult>(out TResult* result) where TResult : unmanaged, IUnknown.Interface, IComIid
        {
            IUnknown* punk = null;
            HResult hr = self.QueryInterface(TResult.IID, &punk);
            if (!hr.Success)
            {
                result = null;
                return hr;
            }

            result = (TResult*)punk;
            return hr;
        }
    }
}