namespace Profile.Clipboard;

internal static unsafe class IMustImplementExtensions
{
    extension<T>(ref T self) where T : unmanaged, IMustImplement<IRandomAccessStream>, IUnknown.Interface
    {
        public ComPtr<IRandomAccessStream> GetRandomAccessStream() => self.Handle.Cast<IRandomAccessStream>();
    }

    extension<T>(ref T self) where T : unmanaged, IMustImplement<IInputStream>, IUnknown.Interface
    {
        public ComPtr<IInputStream> GetInputStream() => self.Handle.Cast<IInputStream>();
    }

    extension<T>(ref T self) where T : unmanaged, IMustImplement<IOutputStream>, IUnknown.Interface
    {
        public ComPtr<IOutputStream> GetOutputStream() => self.Handle.Cast<IOutputStream>();
    }

    extension<T>(ref T self) where T : unmanaged, IMustImplement<IContentTypeProvider>, IUnknown.Interface
    {
        public ComPtr<IContentTypeProvider> GetContentTypeProvider() => self.Handle.Cast<IContentTypeProvider>();
    }

    extension<T>(ref T self) where T : unmanaged, IMustImplement<IClosable>, IUnknown.Interface
    {
        public ComPtr<IClosable> GetClosable() => self.Handle.Cast<IClosable>();
    }

    extension<T>(ref T self) where T : unmanaged, IMustImplement<IAsyncInfo>, IUnknown.Interface
    {
        public ComPtr<IAsyncInfo> GetAsyncInfo() => self.Handle.Cast<IAsyncInfo>();
    }
}