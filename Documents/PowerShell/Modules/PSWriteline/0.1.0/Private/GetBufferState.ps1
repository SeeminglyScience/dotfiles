using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.PowerShell
function GetBufferState {
    [CmdletBinding()]
    param()
    end {
        $buffer, $cursorLocation = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
            [ref]$buffer,
            [ref]$cursorLocation)

        if ([string]::IsNullOrWhiteSpace($buffer)) {
            $tokens = $null
            $ast = [Parser]::ParseInput(
                    '',
                    [ref]$tokens,
                    [ref]$null)

            return [PSCustomObject]@{
                Ast               = $ast
                Tokens            = $tokens
                Cursor            = $ast.Extent.StartScriptPosition
                CommandCompletion = [CommandCompletion]::new(@(), 0, 0, 0)
            }
        }

        $mappedInput = [CommandCompletion]::
            MapStringInputToParsedInput(
                $buffer,
                $cursorLocation)
        try {
            $completions = [CommandCompletion]::
                CompleteInput(
                    $mappedInput.Item1,
                    $mappedInput.Item2,
                    $mappedInput.Item3,
                    @{})
        } catch {
            $completions = [CommandCompletion]::new(@(), 0, 0, 0)
        }

        return [PSCustomObject]@{
            Ast               = $mappedInput.Item1
            Tokens            = $mappedInput.Item2
            Cursor            = $mappedInput.Item3
            CommandCompletion = $completions
        }
    }
}
