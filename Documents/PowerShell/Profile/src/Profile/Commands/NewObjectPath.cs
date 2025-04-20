using System.Buffers;
using System.Collections;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.DirectoryServices;
using System.Dynamic;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Runtime.CompilerServices;
using System.Text;

namespace Profile;

[Cmdlet(VerbsLifecycle.Invoke, "ObjectPath")]
[Alias("iop")]
public sealed class InvokeObjectPathCommand : PSCmdlet
{
    [Parameter(ValueFromPipeline = true)]
    public PSObject? InputObject { get; set; }

    [Parameter(Position = 0, Mandatory = true)]
    [ValidateNotNullOrEmpty]
    [ObjectPathCompleter(InputParameterName = nameof(InputObject))]
    public ObjectPath? Path { get; set; }

    protected override void ProcessRecord()
    {
        Debug.Assert(Path is not null);
        if (InputObject is null)
        {
            return;
        }

        WriteObject(Path.Process(InputObject), enumerateCollection: true);
    }
}

public sealed class ObjectPathCompleterAttribute : ArgumentCompleterFactoryAttribute, IArgumentCompleterFactory, IArgumentCompleter
{
    public string? InputParameterName { get; set; }

    public IEnumerable<CompletionResult> CompleteArgument(
        string commandName,
        string parameterName,
        string wordToComplete,
        CommandAst commandAst,
        IDictionary fakeBoundParameters)
    {
        StaticBindingResult binding = StaticParameterBinder.BindCommand(
            commandAst,
            resolve: true,
            [parameterName]);

        if (!binding.BoundParameters.TryGetValue(parameterName, out ParameterBindingResult? parameter))
        {
            return [];
        }

        IList<PSTypeName> inputTypes = Infer.InputTypes(commandAst, InputParameterName);
        if (inputTypes is [])
        {
            return [];
        }

        string path = parameter.ConstantValue?.ToString() ?? ".";
        return ObjectPath.GetCompletionResults(
            inputTypes,
            path,
            path.Length,
            out _);
    }

    public override IArgumentCompleter Create() => this;
}

public sealed class ObjectPath
{
    private readonly struct Entry
    {
        public readonly Any<string, int> Value;

        public readonly bool IsIndex;

        public Entry(Any<string, int> value, bool isIndex)
        {
            Value = value;
            IsIndex = isIndex;
        }
    }

    private static readonly SearchValues<char> s_entryStart = SearchValues.Create('.', '[');

    private readonly Entry[] _entries;

    private ObjectPath(Entry[] entries)
    {
        _entries = entries;
    }

    [field: MaybeNull]
    private CallSite[] CallSites
    {
        get
        {
            if (field is not null)
            {
                return field;
            }

            field = new CallSite[_entries.Length];
            for (int i = 0; i < _entries.Length; i++)
            {
                Entry entry = _entries[i];
                if (entry.IsIndex)
                {
                    if (entry.Value.Some(out string stringValue))
                    {
                        field[i] = CallSite<Func<CallSite, object, string, object>>.Create(
                            ReflectionCache.PSGetIndexBinder.Get(1, false));

                        continue;
                    }

                    entry.Value.Some(out int intValue);
                    field[i] = CallSite<Func<CallSite, object, int, object>>.Create(
                        ReflectionCache.PSGetIndexBinder.Get(1, false));

                    continue;
                }

                entry.Value.Some(out string memberName);
                field[i] = CallSite<Func<CallSite, object, object>>.Create(
                    ReflectionCache.PSGetMemberBinder.Get(memberName, false));
            }

            return field;
        }
    }

    public static ObjectPath Parse(string path)
    {
        return new(
            Parse(path, throwOnIncomplete: true)
                .Select(e => e.Entry)
                .ToArray());
    }

    public static IEnumerable<((string? Value, bool IsIndex), int Start, int End)> GetEntries(string path)
    {
        foreach ((Entry entry, int start, int end) in Parse(path, throwOnIncomplete: false))
        {
            if (entry.Value.Some(out int asInt))
            {
                yield return ((asInt.ToString(), entry.IsIndex), start, end);
                continue;
            }

            yield return ((entry.Value.UnsafeGetRef<string>(), entry.IsIndex), start, end);
        }
    }

    public static CompletionResult[] GetCompletionResults(
        IList<PSTypeName> inferredTypes,
        string path,
        int cursorPosition,
        out IList<PSInferredMember> members)
    {
        List<PSInferredMember> inferredMembers = new();
        List<CompletionResult> results = new();
        foreach ((CompletionResult completion, int start, int end) in GetCompletionResults(inferredTypes, path, cursorPosition, inferredMembers))
        {
            results.Add(
                new CompletionResult(
                    path.Remove(start, end - start)
                        .Insert(start, completion.CompletionText),
                    completion.ListItemText,
                    completion.ResultType,
                    completion.ToolTip));
        }

        members = inferredMembers.ToArray();
        return results.ToArray();
    }

    private static IEnumerable<(CompletionResult Completion, int Start, int End)> GetCompletionResults(
        IList<PSTypeName> inferredTypes,
        string path,
        int cursorPosition,
        List<PSInferredMember>? members)
    {
        if (path is not ['.' or '[', ..])
        {
            path = $".{path}";
            cursorPosition++;
        }

        foreach (((string? value, bool isIndex), int start, int end) in GetEntries(path))
        {
            if (isIndex)
            {
                break;
            }
            bool cursorIsIn = start <= cursorPosition && end >= cursorPosition;
            string memberName = cursorIsIn
                ? value is null or "" ? "*" : $"{value}*"
                : value ?? "";
            (List<CompletionResult> completions, List<PSInferredMember> inferredMembers) = Infer.Members(
                inferredTypes,
                memberName,
                propertiesOnly: true,
                completionsOnly: false);

            if (!cursorIsIn)
            {
                inferredTypes = inferredMembers
                    .SelectMany(m => m.GetOutputTypes())
                    .Distinct(PSTypeNameEqualityComparer.Instance)
                    .ToArray();
                continue;
            }

            members?.AddRange(inferredMembers);
            foreach (CompletionResult result in completions)
            {
                yield return (result, start, end);
            }

            yield break;
        }
    }

    private static IEnumerable<(Entry Entry, int Start, int End)> Parse(string path, bool throwOnIncomplete)
    {
        ArgumentException.ThrowIfNullOrEmpty(path);

        if (path[0] is not '.' or '[')
        {
            path = $".{path}";
        }

        ReadOnlyMemory<char> current = path.AsMemory();
        int i = 0;
        while (true)
        {
            if (current.IsEmpty)
            {
                break;
            }

            char c = current.Span[0];
            current = current[1..];
            i++;
            int start = i;
            if (c is '.')
            {
                if (current.IsEmpty)
                {
                    if (throwOnIncomplete)
                    {
                        ThrowParseError(path, i, "missing property name");
                    }

                    yield return (new("", isIndex: false), start, start);
                    break;
                }

                int next = current.Span.IndexOfAny(s_entryStart);
                if (next is -1)
                {
                    yield return (new(current.ToString(), false), start, path.Length);
                    break;
                }

                yield return (new(current[..next].ToString(), false), start, i + next - 1);
                current = current[next..];
                i += next;
                continue;
            }

            if (c is '[')
            {
                int endOffset = 1;
                int end = current.Span.IndexOf(']');
                if (end is -1)
                {
                    if (throwOnIncomplete)
                    {
                        ThrowParseError(path, path.Length, "missing ending '['");
                    }

                    end = current.Span.IndexOf('.');
                    if (end is -1)
                    {
                        yield return (new(current.ToString(), true), start, path.Length);
                        break;
                    }

                    endOffset = 0;
                }

                ReadOnlyMemory<char> value = current[..end];
                if (int.TryParse(value.Span, out int asInt))
                {
                    yield return (new(asInt, true), start, end - 1);
                }
                else
                {
                    yield return (new(value.ToString(), true), start, end - 1);
                }

                current = current[..(end + endOffset)];
                i += end + endOffset;
                continue;
            }

            // if (current.Span[0] is not '.' or '[')
            // {
            //     ThrowParseError(path, 0, "missing element start ('.' or '[')");
            // }
        }

        [DoesNotReturn]
        static void ThrowParseError(string path, int offset, string message)
        {
            throw new ArgumentException(
                $"Bad ObjectPath: {message} at offset {offset}",
                nameof(path));
        }
    }

    public object Process(PSObject input) => Process((object)input);

    public object Process(object input)
    {
        CallSite[] callSites = CallSites;
        for (int i = 0; i < callSites.Length; i++)
        {
            input = callSites[i] switch
            {
                CallSite<Func<CallSite, object, object>> cs => cs.Target(cs, input),
                CallSite<Func<CallSite, object, int, object>> cs => cs.Target(cs, input, _entries[i].Value.UnsafeGetRef<int>()),
                CallSite<Func<CallSite, object, string, object>> cs => cs.Target(cs, input, _entries[i].Value.UnsafeGetRef<string>()),
                _ => Throw.Unreachable<object>(),
            };
        }

        return input;
    }

    private string? _toStringCache;

    public override string ToString()
    {
        if (_toStringCache is not null)
        {
            return _toStringCache;
        }

        StringBuilder text = new();
        for (int i = 0; i < _entries.Length; i++)
        {
            if (i is not 0)
            {
                text.Append(" -> ");
            }

            Entry entry = _entries[i];
            if (!entry.IsIndex)
            {
                text.Append('.').Append(entry.Value.UnsafeGetRef<string>());
                continue;
            }

            if (entry.Value.Some(out int numberIndex))
            {
                text.Append('[').Append(numberIndex).Append(']');
                continue;
            }

            text.Append("['").Append(entry.Value.UnsafeGetRef<string>()).Append("']");
        }

        return _toStringCache = text.ToString();
    }
}

internal sealed class PSTypeNameEqualityComparer : IEqualityComparer<PSTypeName>
{
    public static PSTypeNameEqualityComparer Instance { get; } = new();

    public bool Equals(PSTypeName? x, PSTypeName? y)
    {
        if (x is null || y is null)
        {
            return x == y;
        }

        if (x.Type is not null)
        {
            return x.Type == y.Type;
        }

        if (x.TypeDefinitionAst is not null)
        {
            return x.TypeDefinitionAst == y.TypeDefinitionAst;
        }

        // If both members are null the type is probably synthetic
        return ReferenceEquals(x, y);
    }

    public int GetHashCode([DisallowNull] PSTypeName obj)
    {
        return obj.Type?.GetHashCode()
            ?? obj.TypeDefinitionAst?.GetHashCode()
            ?? obj.GetHashCode();
    }
}