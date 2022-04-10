using namespace Microsoft.PowerShell

function SmartSelfInsert {
    [CmdletBinding()]
    param(
        [Nullable[ConsoleKeyInfo]] $key,
        [object] $arg
    )
    end {
        $bindingFlags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $editQueue = [PSConsoleReadLine].
            GetField('_edits', $bindingFlags).
            GetValue((GetSingleton))

        if (0 -eq $editQueue.Count) {
            [PSConsoleReadLine]::SelfInsert($key, $arg)
            return
        }

        $char = $key.KeyChar

        $hotstrings = GetHotstring -Character $char
        if (-not $hotstrings) {
            [PSConsoleReadLine]::SelfInsert($keys, $arg)
            return
        }

        foreach ($hotstring in $hotstrings) {
            $triggers = $hotstring.Chars
            $edits    = $editQueue.Where({ $true }, 'Last', $triggers.Count - 1)
            if (($triggers.Count - 1) -gt $editQueue.Count) {
                continue
            }

            $isMatch = $true
            for ($i = 0; $i -lt $triggers.Count - 1; $i++) {
                $targetEdit = $edits[$i]
                if ($targetEdit.GetType().Name -ne 'EditItemInsertChar' -or
                    $targetEdit.GetType().
                        GetField('_insertedCharacter', $bindingFlags).
                        GetValue($targetEdit) -ne $triggers[$i])
                {
                    $isMatch = $false
                    break
                }
            }

            if (-not $isMatch) {
                continue
            }

            $cursor = $null
            [PSConsoleReadLine]::GetBufferState([ref]$null, [ref]$cursor)
            [PSConsoleReadLine]::Delete(
                $cursor - ($triggers.Count - 1),
                $triggers.Count - 1)

            & $hotstring.Action $key $arg
            return
        }

        [PSConsoleReadLine]::SelfInsert($key, $arg)
    }
}
