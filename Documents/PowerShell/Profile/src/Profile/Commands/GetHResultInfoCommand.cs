using System.Management.Automation;

namespace Profile.Commands;

[Cmdlet(VerbsCommon.Get, "HResultInfo")]
[Alias("hr")]
public sealed class GetHResultInfoCommand : PSCmdlet
{
    [Parameter(Position = 0, ValueFromPipeline = true)]
    public int HResult { get; set; }

    protected override void ProcessRecord()
    {
        WriteObject((HResult)HResult);
    }
}