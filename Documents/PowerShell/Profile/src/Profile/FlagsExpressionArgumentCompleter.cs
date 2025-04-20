using System.Buffers;
using System.Collections;
using System.Management.Automation;
using System.Management.Automation.Language;

namespace Profile;

public sealed class FlagsExpressionArgumentCompleterAttribute : ArgumentCompleterFactoryAttribute, IArgumentCompleterFactory
{
    public FlagsExpressionArgumentCompleterAttribute()
    {
    }

    public required Type EnumType { get; set; }

    public override IArgumentCompleter Create()
    {
        return new FlagsExpressionArgumentCompleter(EnumType);
    }
}

internal sealed class FlagsExpressionArgumentCompleter : IArgumentCompleter
{
    public FlagsExpressionArgumentCompleter(Type type)
    {
        Type = type;
    }

    public Type Type { get; }

    public IEnumerable<CompletionResult> CompleteArgument(
        string commandName,
        string parameterName,
        string wordToComplete,
        CommandAst commandAst,
        IDictionary fakeBoundParameters)
    {
        HashSet<string> names = new(Type.GetEnumNames());
        wordToComplete = CompletionHelper.GetWordToComplete(wordToComplete, out char prefix, out char suffix);
        ReadOnlySpan<char> word = wordToComplete;
        int start = 0;
        for (int i = 0; i < word.Length; i++)
        {
            char c = word[i];
            if (c is '+' or ',' or ' ' or '!')
            {
                if (start == i)
                {
                    start++;
                    continue;
                }

                if (Enum.TryParse(Type, word[start..i], true, out object? result))
                {
                    names.Remove(result.ToString()!);
                }

                start = i + 1;
                continue;
            }
        }

        ReadOnlySpan<char> before = default;
        if (start != word.Length - 1)
        {
            before = word[..start];
            word = word[start..];
        }

        return GetCompletions(names, before.ToString(), word.ToString(), prefix, suffix, Type).ToArray();

        static IEnumerable<CompletionResult> GetCompletions(
            HashSet<string> names,
            string beforeString,
            string word,
            char prefix,
            char suffix,
            Type type)
        {
            WildcardPattern pattern = WildcardPattern.Get(word + "*", WildcardOptions.IgnoreCase | WildcardOptions.CultureInvariant);
            foreach (string name in names)
            {
                if (pattern.IsMatch(name))
                {
                    yield return new CompletionResult(
                        CompletionHelper.FinishCompletionValue(
                            $"{beforeString}{name}",
                            (prefix, suffix)),
                        name,
                        CompletionResultType.ParameterValue,
                        $"{type.Name}.{name}");
                }
            }
        }
    }
}