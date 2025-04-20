using System.Collections;
using System.Diagnostics;
using System.Management.Automation;

namespace Profile.Commands;

internal static class Sma
{
    public static object GetOutputPipe(PSCmdlet source)
    {
        if (ReflectionCache.PSScriptCmdlet.Is(source))
        {
            return ReflectionCache.PSScriptCmdlet.GetOutputPipe(source);
        }

        return ReflectionCache.MshCommandRuntime.GetOutputPipe(source.CommandRuntime);
    }
}

[Cmdlet(VerbsLifecycle.Invoke, "WithPipe")]
public sealed class InvokeWithPipeCommand : PSCmdlet
{

    [Parameter(Position = 0, Mandatory = true)]
    [ValidateNotNull]
    public PSCmdlet? Context { get; set; }

    [Parameter(Position = 1, Mandatory = true)]
    [ValidateNotNull]
    public ScriptBlock? Body { get; set; }

    [Parameter]
    [ValidateSet("WriteToCurrentErrorPipe", "WriteToExternalErrorPipe", "SwallowErrors")]
    public string ErrorHandlingBehavior { get; set; } = "WriteToCurrentErrorPipe";

    [Parameter]
    public object? DollarUnder { get; set; }

    [Parameter]
    public object? Input { get; set; }

    [Parameter]
    public object? This { get; set; }

    [Parameter]
    public object? Pipe { get; set; }

    [Parameter]
    public SwitchParameter DoNotPropagateExceptionsToTop { get; set; }

    [Parameter]
    [ValidateNotNull]
    public Hashtable? Variables { get; set; }

    [Parameter]
    [ValidateNotNull]
    public Hashtable? Functions { get; set; }

    [Parameter]
    [AllowNull, AllowEmptyCollection]
    public object?[]? ArgumentList { get; set; }

    [Parameter]
    public SwitchParameter PassThru { get; set; }

    protected override void EndProcessing()
    {
        Debug.Assert(Context is not null);
        Debug.Assert(Body is not null);
        Pipe ??= Sma.GetOutputPipe(PassThru ? this : Context);

        ScriptInfo command = ReflectionCache.ScriptInfo.ctor(
            string.Empty,
            Body,
            ReflectionCache.LocalPipeline.GetExecutionContextFromTLS());

        InvocationInfo invocationInfo = InvocationInfo.Create(
            command,
            Context.MyInvocation.DisplayScriptPosition);

        Dictionary<string, ScriptBlock>? functions = null;
        if (Functions is not null)
        {
            functions = new();
            foreach (DictionaryEntry kvp in Functions)
            {
                functions.Add(
                    LanguagePrimitives.ConvertTo<string>(kvp.Key),
                    LanguagePrimitives.ConvertTo<ScriptBlock>(kvp.Value));
            }
        }

        List<PSVariable>? variables = null;
        if (Variables is not null)
        {
            variables = new();
            foreach (DictionaryEntry kvp in Variables)
            {
                variables.Add(
                    new PSVariable(
                        LanguagePrimitives.ConvertTo<string>(kvp.Key),
                        kvp.Value));
            }
        }

        ReflectionCache.ScriptBlock.InvokeWithPipe(
            Body,
            useLocalScope: true,
            ScriptBlockErrorHandlingBehavior.WriteToCurrentErrorPipe,
            DollarUnder,
            Input,
            This,
            Pipe,
            invocationInfo,
            !DoNotPropagateExceptionsToTop,
            variables,
            functions,
            ArgumentList);
    }
}
