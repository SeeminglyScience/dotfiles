using System.Collections.Concurrent;
using System.Text;

namespace ComGenerator;

internal sealed class StringBuilderPool
{
    private readonly ConcurrentBag<StringBuilder> _pool = new();

    private readonly int _cacheSize;

    public StringBuilderPool(int cacheSize = 10)
    {
        _cacheSize = cacheSize;
    }

    public StringBuilder Rent(int sizeEstimate = 0)
    {
        if (_pool.TryTake(out StringBuilder existing))
        {
            return existing;
        }

        return new StringBuilder(sizeEstimate);
    }

    public void Return(StringBuilder sb)
    {
        sb.Clear();
        if (_pool.Count >= _cacheSize)
        {
            return;
        }

        _pool.Add(sb);
    }
}
