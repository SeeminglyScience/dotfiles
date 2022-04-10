function SmartBrace {
    [CmdletBinding()]
    param($key, $arg)
    end {

        $closeChar = switch ($key.KeyChar) {
            '(' { [char]')'; break }
            '{' { [char]'}'; break }
            '[' { [char]']'; break }
        }

        # Added selection test - pmm
        $selectionStart = $selectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

        $line = $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($selectionStart -ne -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                $selectionStart,
                $selectionLength,
                $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                return
        }

        if ($line[$cursor] -match '\w') {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
            return
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}
