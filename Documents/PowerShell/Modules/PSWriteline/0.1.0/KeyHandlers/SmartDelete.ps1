function SmartDelete {
    [CmdletBinding()]
    param($key, $arg)
    end {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($cursor -gt 0) {
            if ($line[$cursor - 1] -eq ' ') {
                $mappedInput = [System.Management.Automation.CommandCompletion]::
                    MapStringInputToParsedInput(
                        $line,
                        $cursor)
                if ($mappedInput.Item3.ColumnNumber -ge 4) {
                    $totalOffset = 1
                    foreach($offset in 2..4) {
                        if ($line[$cursor - $offset] -ne ' ') {
                            break
                        }

                        $totalOffset++
                    }

                    [Microsoft.PowerShell.PSConsoleReadLine]::
                        Delete(
                            $cursor - $totalOffset,
                            $totalOffset)
                    return
                }
            }

            $toMatch = $null
            if ($cursor -lt $line.Length) {
                switch ($line[$cursor]) {
                    '"' { $toMatch = '"' }
                    "'" { $toMatch = "'" }
                    ')' { $toMatch = '(' }
                    ']' { $toMatch = '[' }
                    '}' { $toMatch = '{' }
                }
            }

            if ($toMatch -ne $null -and $line[$cursor-1] -eq $toMatch) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
            } else {
                [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
            }
        }
    }
}
