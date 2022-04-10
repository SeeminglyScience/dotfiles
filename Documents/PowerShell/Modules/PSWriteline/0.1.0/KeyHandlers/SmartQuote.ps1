function SmartQuote {
    [CmdletBinding()]
    param($key, $arg)
    end {
        $selectionStart = $selectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

        $line = $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($selectionStart -ne -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                $selectionStart,
                $selectionLength,
                $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $key.KeyChar)
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                return
        }

        $quoteNumber = Select-String -InputObject $line -Pattern $key.KeyChar -AllMatches
        if ($quoteNumber.Matches.Count % 2 -eq 1) {
            # Oneven amount of quotes, put just one quote
            [Microsoft.PowerShell.PSConsoleReadline]::Insert($key.KeyChar)
        } elseif ($line[$cursor] -eq $key.KeyChar) {
            # Just move the cursor
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            # Clause added - pmm
        } elseif ($line[$cursor] -match '\w' -or $line[$cursor - 1] -match '\w') {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
        } else {
            # Insert matching quotes, move cursor to be in between the quotes
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)" * 2)
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
        }
    }
}
