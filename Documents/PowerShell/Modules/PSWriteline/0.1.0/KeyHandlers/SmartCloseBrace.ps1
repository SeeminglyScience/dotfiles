function SmartCloseBrace {
    [CmdletBinding()]
    param($key, $arg)
    end {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($line[$cursor] -eq $key.KeyChar) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
        }
    }
}
