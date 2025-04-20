using System.Buffers;

namespace Profile;

internal sealed unsafe class PinnedArrayMemoryManager<T> : MemoryManager<T> where T : unmanaged
{
#pragma warning disable IDE0052
    private readonly object _keepAlive;
#pragma warning restore IDE0052

    private readonly T* _ptr;

    private readonly int _length;

    public PinnedArrayMemoryManager(object keepAlive, T* ptr, int length)
    {
        _keepAlive = keepAlive;
        _ptr = ptr;
        _length = length;
    }

    public override Span<T> GetSpan()
    {
        return new Span<T>(_ptr, _length);
    }

    public override MemoryHandle Pin(int elementIndex = 0)
    {
        return new MemoryHandle(_ptr);
    }

    public override void Unpin()
    {
    }

    protected override void Dispose(bool disposing)
    {
    }
}