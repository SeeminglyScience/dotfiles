function DeleteRealLine {
    [CmdletBinding()]
    param()
    end {
        $state = GetBufferState

        if ($state.Ast.Extent.EndLineNumber -eq 1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::DeleteLine()
            return
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Delete(
            $state.Cursor.Offset - $state.Cursor.ColumnNumber,
            $state.Cursor.Line.Length)
    }
}
