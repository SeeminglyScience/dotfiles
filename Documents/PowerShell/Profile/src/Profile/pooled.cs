
using System.Management.Automation;

#pragma warning disable CS8981 // The type name only contains lower-cased ascii characters. Such names may become reserved for the language.

public sealed class pooled
{
    internal readonly ScriptBlock _scriptBlock;

    internal readonly object? _dollarThis;

    public pooled(ScriptBlock scriptBlock)
    {
        _scriptBlock = scriptBlock;
    }

    public pooled(ScriptBlock scriptBlock, object? dollarThis)
    {
        _scriptBlock = scriptBlock;
        _dollarThis = dollarThis;
    }

    public override string ToString() => _scriptBlock.ToString();

    public override int GetHashCode() => _scriptBlock.GetHashCode();
}

#pragma warning restore CS8981 // The type name only contains lower-cased ascii characters. Such names may become reserved for the language.
