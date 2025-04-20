namespace Profile;

internal readonly struct LooseHandle<T> : IDisposable
    where T : IDisposable
{
    public readonly T? Value;

    public LooseHandle(T? value = default) => Value = value;

    public void Dispose() => Value?.Dispose();
}