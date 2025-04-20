using System.ComponentModel;
using System.Diagnostics;
using System.Management.Automation;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using Windows.Win32;
using Windows.Win32.Foundation;

namespace Profile;

[Cmdlet(VerbsCommon.Get, "Window")]
public sealed unsafe class GetWindowCommand : PSCmdlet
{
    private const string PipedParent = "PipedParent";

    private const string Default = "Default";

    private WindowInfo[]? _allWindows;

    [Parameter(ValueFromPipeline = true)]
    public WindowInfo? Parent { get; set; }

    [Parameter(Position = 0)]
    [SupportsWildcards]
    [ValidateNotNullOrEmpty]
    public string? Text { get; set; }

    [Parameter(ValueFromPipelineByPropertyName = true)]
    [ValidateNotNullOrEmpty]
    public string? LiteralText { get; set; }

    [Parameter()]
    [SupportsWildcards]
    [ValidateNotNullOrEmpty]
    public string? ClassName { get; set; }

    [Parameter(ValueFromPipelineByPropertyName = true)]
    [ValidateNotNullOrEmpty]
    public string? LiteralClassName { get; set; }

    [Parameter(ValueFromPipeline = true)]
    public Any<int, string, Process>[]? Process { get; set; }

    [Parameter()]
    [FlagsExpressionArgumentCompleter(EnumType = typeof(WindowStyle))]
    public FlagsExpression<WindowStyle>? Style { get; set; }

    [Parameter()]
    [FlagsExpressionArgumentCompleter(EnumType = typeof(WindowExStyle))]
    public FlagsExpression<WindowExStyle>? ExStyle { get; set; }

    internal static WindowInfo[] GetAllWindows(HWND parent = default)
    {
        List<HWND> windows = [];
        GCHandle hWindows = GCHandle.Alloc(windows);
        try
        {
            // Docs say return value isn't used at all :shrug:
            Interop.EnumChildWindows(parent, &AddWindowToList, GCHandle.ToIntPtr(hWindows));
        }
        finally
        {
            hWindows.Free();
        }

        WindowInfo[] result = new WindowInfo[windows.Count];
        for (int i = 0; i < result.Length; i++)
        {
            result[i] = new WindowInfo(windows[i]);
        }

        return result;
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static BOOL AddWindowToList(HWND hWnd, LPARAM lParam)
    {
        if (GCHandle.FromIntPtr(lParam).Target is List<HWND> list)
        {
            list.Add(hWnd);
            return true;
        }

        return false;
    }

    private HashSet<uint>? GetProcessIds()
    {
        if (Process is null)
        {
            return null;
        }

        Process[]? allProcesses = null;
        HashSet<uint> results = new();
        foreach (Any<int, string, Process> process in Process)
        {
            if (process.Some(out int id))
            {
                results.Add(unchecked((uint)id));
                continue;
            }

            if (process.Some(out string? name))
            {
                if (!WildcardPattern.ContainsWildcardCharacters(name))
                {
                    foreach (Process procInstance in System.Diagnostics.Process.GetProcessesByName(name))
                    {
                        results.Add(unchecked((uint)procInstance.Id));
                    }

                    continue;
                }

                WildcardPattern pattern = WildcardPattern.Get(name, WildcardOptions.CultureInvariant | WildcardOptions.IgnoreCase);
                allProcesses ??= System.Diagnostics.Process.GetProcesses();
                foreach (Process procInstance in allProcesses)
                {
                    if (pattern.IsMatch(procInstance.ProcessName))
                    {
                        results.Add(unchecked((uint)procInstance.Id));
                    }
                }

                continue;
            }

            if (process.Some(out Process? proc))
            {
                results.Add(unchecked((uint)proc!.Id));
            }
        }

        return results;
    }

    protected override void ProcessRecord()
    {
        HashSet<uint>? processIds = GetProcessIds();
        Func<string?, bool>? textMatcher = GetMatcher(Text, LiteralText, out bool isTextPattern);
        Func<string?, bool>? classMatcher = GetMatcher(ClassName, LiteralClassName, out bool isClassPattern);

        bool shouldUseFindWindow = (textMatcher is not null || classMatcher is not null)
            && !isTextPattern
            && !isClassPattern
            && processIds is null
            && Style is null
            && ExStyle is null;

        if (shouldUseFindWindow)
        {
            UseFindWindow();
            return;
        }

        WindowInfo[] windows = _allWindows ?? GetAllWindows((HWND)(Parent?.Handle ?? 0));
        if (classMatcher is null && textMatcher is null && processIds is null && Style is null && ExStyle is null)
        {
            if (MyInvocation.ExpectingInput)
            {
                return;
            }

            WriteObject(windows, enumerateCollection: true);
            return;
        }

        foreach (WindowInfo window in windows)
        {
            if (processIds?.Contains(window.ProcessId) is false)
            {
                continue;
            }

            if (Style?.Evaluate(window.Style) is false)
            {
                continue;
            }

            if (ExStyle?.Evaluate(window.ExStyle) is false)
            {
                continue;
            }

            if (classMatcher?.Invoke(window.ClassName) is false)
            {
                continue;
            }

            if (textMatcher?.Invoke(window.Text) is false)
            {
                continue;
            }

            WriteObject(window);
        }
    }

    private Func<string?, bool>? GetMatcher(string? pattern, string? literalValue, out bool isPattern)
    {
        if (literalValue is not null)
        {
            isPattern = false;
            return value => literalValue.Equals(value, StringComparison.OrdinalIgnoreCase);
        }

        if (pattern is null)
        {
            isPattern = false;
            return null;
        }

        if (WildcardPattern.ContainsWildcardCharacters(pattern))
        {
            isPattern = true;
            return WildcardPattern.Get(pattern, WildcardOptions.IgnoreCase | WildcardOptions.CultureInvariant).IsMatch;
        }

        isPattern = false;
        return value => pattern.Equals(value, StringComparison.OrdinalIgnoreCase);
    }

    private void UseFindWindow()
    {
        HWND after = HWND.Null;
        fixed (char* className = ClassName)
        fixed (char* text = Text)
        {
            while (true)
            {
                HWND result = Interop.FindWindowEx(
                    (HWND)(Parent?.Handle ?? 0),
                    after,
                    className,
                    text);

                if (result.IsNull)
                {
                    throw new Win32Exception();
                }

                WriteObject(new WindowInfo(result));
                after = result;
            }
        }
    }
}