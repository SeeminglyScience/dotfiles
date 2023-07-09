function SmartTab {
    param([Nullable[ConsoleKeyInfo]]$key, [object]$arg)
    end {
        $defaultIndent = '    '

        $singleton = GetSingleton
        $tabCommandCount = $singleton.GetType().
            GetField('_tabCommandCount', 60).
            GetValue($singleton)

        if ($tabCommandCount) {
            [Microsoft.PowerShell.PSConsoleReadLine]::TabCompleteNext()
            return
        }
        $buffer = $cursorLocation = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$buffer, [ref]$cursorLocation)

        # if ([string]::IsNullOrWhiteSpace($buffer)) {
        #     [Microsoft.PowerShell.PSConsoleReadLine]::Insert($defaultIndent)
        #     return
        # }

        $mappedInput = [System.Management.Automation.CommandCompletion]::MapStringInputToParsedInput(
            $buffer,
            $cursorLocation)

        # try {
        #     $completions = [System.Management.Automation.CommandCompletion]::CompleteInput(
        #         $mappedInput.Item1,
        #         $mappedInput.Item2,
        #         $mappedInput.Item3,
        #         @{})
        # } catch {
        #     [System.Management.Automation.Hidden()]
        #     $global:__LAST_TAB_COMPLETE_ERROR = $PSItem
        #     $completions = $null
        # }

        $position = $mappedInput.Item3
        if (-not [string]::IsNullOrWhiteSpace($position.Line.Substring(0, $position.ColumnNumber - 1))) {
            [Microsoft.PowerShell.PSConsoleReadLine]::TabCompleteNext()
            return
        }

        $offsetInRow = $position.ColumnNumber - 1
        $indentSize = $defaultIndent.Length
        $indent = ' ' * ((($offsetInRow % $indentSize) - $indentSize) * -1)
        if ($indent.Length -gt $defaultIndent.Length) {
            $indent = $defaultIndent
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($indent)
    }
}
