using System.Collections.Concurrent;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace Profile;

internal sealed class PooledRunspaces
{
    public static PooledRunspaces Instance { get; } = new();

    private readonly ConcurrentBag<Runspace> _runspaces = new();

    public Runspace Rent()
    {
        if (_runspaces.TryPeek(out Runspace? existing))
        {
            return existing;
        }

        return CreateRunspace();
    }

    public void Return(Runspace runspace)
    {
        runspace.ResetRunspaceState();
        _runspaces.Add(runspace);
    }

    private Runspace CreateRunspace()
    {
        Runspace rs = RunspaceFactory.CreateRunspace();
        rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
        rs.Open();
        return rs;
    }

    internal static object? InvokeWithCachedRunspace(
        ScriptBlock scriptBlock,
        PooledRunspaces runspaces,
        object? dollarUnder,
        object? dollarThis,
        object?[]? args)
    {
        Runspace? previous = Runspace.DefaultRunspace;
        Runspace toReturn = runspaces.Rent();
        try
        {
            Runspace.DefaultRunspace = toReturn;
            return ReflectionCache.ScriptBlock.InvokeAsDelegateHelper(
                scriptBlock,
                dollarUnder,
                dollarThis,
                args);
        }
        finally
        {
            runspaces.Return(toReturn);
        }
    }
}