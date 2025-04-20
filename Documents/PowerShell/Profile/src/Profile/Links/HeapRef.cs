using System.Runtime.CompilerServices;

namespace Profile;

internal static unsafe class PinnedHeapRef
{
    public static PinnedHeapRef<T> Alloc<T>()
        where T : unmanaged
    {
        T[] pinnedArray = GC.AllocateArray<T>(1, pinned: true);
        return new PinnedHeapRef<T>(
            pinnedArray,
            (T*)Unsafe.AsPointer(ref pinnedArray[0]));
    }
}

internal readonly unsafe struct PinnedHeapRef<T> where T : unmanaged
{
    private readonly object _keepAlive;

    private readonly T* _ptr;

    public PinnedHeapRef(object pinnedKeepAlive, T* ptr)
    {
        _keepAlive = pinnedKeepAlive;
        _ptr = ptr;
    }

    public ref T Value => ref *_ptr;

    public T* Ptr => _ptr;

    public PinnedHeapRef<TResult> CreateDerivedRef<TResult>(TResult* ptr)
        where TResult : unmanaged
    {
        return new PinnedHeapRef<TResult>(_keepAlive, ptr);
    }

    public PinnedArrayMemoryManager<TResult> CreateDerivedMemory<TResult>(TResult* ptr, int length)
        where TResult : unmanaged
    {
        return new PinnedArrayMemoryManager<TResult>(_keepAlive, ptr, length);
    }
}