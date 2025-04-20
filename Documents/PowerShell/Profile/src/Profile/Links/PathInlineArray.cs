using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Profile.Links;

[InlineArray(MAX_PATH)]
internal struct PathInlineArray<T> where T : unmanaged
{
    public const int MAX_PATH = 260;

    private T _element0;

    public Span<T> Span => MemoryMarshal.CreateSpan(ref _element0, MAX_PATH);
}

internal static class FaceNameInlineArray
{
    public const int LF_FACESIZE = 32;
}

[InlineArray(FaceNameInlineArray.LF_FACESIZE)]
internal struct FaceNameInlineArray<T> where T : unmanaged
{
    private T _element0;

    public Span<T> Span => MemoryMarshal.CreateSpan(ref _element0, FaceNameInlineArray.LF_FACESIZE);
}