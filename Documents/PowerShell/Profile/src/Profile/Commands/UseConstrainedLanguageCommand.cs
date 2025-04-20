using System.Diagnostics;
using System.Management.Automation;

namespace Profile.Commands;

[Cmdlet(VerbsOther.Use, "ConstrainedLanguage")]
public sealed class UseConstrainedLanguageCommand : PSCmdlet
{
    [Parameter(Mandatory = true, Position = 0)]
    [ValidateNotNull]
    public ScriptBlock? Body { get; set; }

    [Parameter]
    public SwitchParameter SetLockdown { get; set; }

    private const string PSLockdownPolicy = "__PSLockdownPolicy";

    protected override void EndProcessing()
    {
        Debug.Assert(Body is not null);

        PSLanguageMode? previousLangMode = ReflectionCache.ScriptBlock.LanguageMode.Get(Body);
        if (previousLangMode is not PSLanguageMode.FullLanguage)
        {
            ThrowTerminatingError(
                new ErrorRecord(
                    new InvalidOperationException("Already in constrained language mode."),
                    "CannotUseClmInClm",
                    ErrorCategory.InvalidOperation,
                    null));

            return;
        }

        if (SetLockdown)
        {
            Environment.SetEnvironmentVariable(
                PSLockdownPolicy,
                "0x80000007",
                EnvironmentVariableTarget.Machine);
        }

        try
        {
            ReflectionCache.ScriptBlock.LanguageMode.Set(Body, PSLanguageMode.ConstrainedLanguage);
            ReflectionCache.ScriptBlock.InvokeWithPipe(
                Body,
                useLocalScope: true,
                ScriptBlockErrorHandlingBehavior.WriteToCurrentErrorPipe,
                dollarUnder: null,
                input: null,
                scriptThis: null,
                ReflectionCache.MshCommandRuntime.GetOutputPipe(CommandRuntime),
                InvocationInfo.Create(
                    ReflectionCache.ScriptInfo.ctor(
                        "",
                        Body,
                        ReflectionCache.LocalPipeline.GetExecutionContextFromTLS()),
                    MyInvocation.DisplayScriptPosition),
                propagateAllExceptionsToTop: true,
                variablesToDefine: null,
                functionsToDefine: null,
                args: null);
        }
        finally
        {
            ReflectionCache.ScriptBlock.LanguageMode.Set(Body, previousLangMode);

            if (SetLockdown)
            {
                Environment.SetEnvironmentVariable(
                    PSLockdownPolicy,
                    null,
                    EnvironmentVariableTarget.Machine);
            }
        }
    }
}