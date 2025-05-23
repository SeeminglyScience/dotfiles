using System;
using System.Management.Automation;
using System.Text;
using Microsoft.PowerShell;

namespace Profile
{
    internal static class CompletionHelper
    {
        public static string FinishCompletionValue(string completionValue, (char prefix, char suffix) state)
        {
            int length = completionValue.Length;
            if (state.prefix is not '\0')
            {
                length++;
            }

            if (state.suffix is not '\0')
            {
                length++;
            }

            int replaceCount = 0;
            bool needsQuotes = false;
            foreach (char c in completionValue)
            {
                if (c is '\'' && state.prefix is not '"')
                {
                    replaceCount++;
                    needsQuotes = true;
                    continue;
                }

                if (c is '"')
                {
                    if (state.prefix is '"')
                    {
                        replaceCount++;
                        continue;
                    }

                    needsQuotes = true;
                    continue;
                }

                if (c is ' ')
                {
                    needsQuotes = true;
                    continue;
                }

                if (c is ',')
                {
                    needsQuotes = true;
                }
            }

            if (needsQuotes && state.prefix is '\0')
            {
                length += 2;
                state.prefix = '\'';
                state.suffix = '\'';
            }

            length += replaceCount;

            return string.Create(
                length,
                (completionValue, state.prefix, state.suffix, replaceCount),
                static (buffer, state) =>
                {
                    if (state.prefix is not '\0')
                    {
                        buffer[0] = state.prefix;
                        buffer = buffer[1..];
                    }

                    if (state.replaceCount is 0)
                    {
                        state.completionValue.AsSpan().CopyTo(buffer);
                        buffer = buffer[state.completionValue.Length..];
                    }
                    else
                    {
                        int j = 0;
                        for (int i = 0; i < state.completionValue.Length; i++, j++)
                        {
                            char c = state.completionValue[i];
                            if (c == state.prefix)
                            {
                                if (c is '\'')
                                {
                                    buffer[j] = '\'';
                                    buffer[++j] = '\'';
                                    continue;
                                }

                                buffer[j] = '`';
                                buffer[++j] = '"';
                                continue;
                            }

                            buffer[j] = c;
                        }

                        buffer = buffer[j..];
                    }

                    if (state.suffix is not '\0')
                    {
                        buffer[0] = state.suffix;
                    }
                });
        }

        public static string GetWordToComplete(string wordToComplete, out char prefix, out char suffix)
        {
            if (string.IsNullOrEmpty(wordToComplete))
            {
                prefix = default;
                suffix = default;
                return wordToComplete;
            }

            prefix = default;
            if (wordToComplete[0] is '\'' or '"')
            {
                prefix = wordToComplete[0];
            }

            suffix = default;
            if (prefix is not '\0' && wordToComplete is { Length: 1 })
            {
                return string.Empty;
            }

            char lastChar = wordToComplete[^1];
            if (lastChar is '\'' or '"')
            {
                suffix = lastChar;
                if (prefix != suffix)
                {
                    suffix = default;
                }
            }

            if (suffix is not '\0' && prefix is not '\0')
            {
                return wordToComplete[1..^1];
            }

            if (prefix is not '\0')
            {
                return wordToComplete[1..];
            }

            if (suffix is not '\0')
            {
                return wordToComplete[..^1];
            }

            return wordToComplete;
        }

        public static CompletionResult GetCompletionResult(
            string completionText,
            string listItemText,
            string toolTip)
        {
            if (completionText.IndexOfAny(new[] { ',', ' ' }) is not -1)
            {
                if (completionText.IndexOf('\'') is not -1)
                {
                    completionText = completionText.Replace("'", "''");
                }

                completionText = string.Create(
                    completionText.Length + 2,
                    completionText,
                    (buffer, completionText) =>
                    {
                        buffer[0] = '\'';
                        completionText.AsSpan().CopyTo(buffer[1..]);
                        buffer[^1] = '\'';
                    });
            }

            return new CompletionResult(
                completionText,
                listItemText,
                CompletionResultType.ParameterValue,
                toolTip);
        }
    }
}
