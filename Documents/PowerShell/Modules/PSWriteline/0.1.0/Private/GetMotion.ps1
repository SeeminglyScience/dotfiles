function GetMotion {
    [CmdletBinding()]
    param(
        [string] $Prompt,

        [char[]] $AdditionalCharacters
    )
    end {
        if ($Prompt) {
            $splat = @{ Prompt = $Prompt }
        }

        $motionState = [PSCustomObject]@{
            ShouldExitAfterNext = $false
        }

        $motionText = InvokeStatusPrompt @splat -PromptKeyHandler {
            param([ConsoleKeyInfo] $PromptKey, [psobject] $State)
            end {
                if ($motionState.ShouldExitAfterNext) {
                    $State.ShouldExit = $true
                    return
                }

                switch -Regex ($PromptKey.KeyChar) {
                    '\d' {
                        if ($State.Prompt.Length -ne 1) {
                            $null = $State.Prompt.Clear()
                            $State.ShouldExit = $true
                        }
                    }
                    '[weblh]' {
                        $State.ShouldExit = $true
                    }
                    '[tf]' {
                        $motionState.ShouldExitAfterNext = $true
                    }
                    default {
                        if ($AdditionalCharacters -and $PromptKey.KeyChar -in $AdditionalCharacters) {
                            return
                        }

                        $null = $State.Prompt.Clear()
                        $State.ShouldExit = $true
                    }
                }
            }
        }

        $pattern = [regex]::new(
            '
                (?<Digit>\d)?
                (?<Action>[webhltf])
                (?<Arg>.)?
                (?<Unknown>.+)?
            ',
            [System.Text.RegularExpressions.RegexOptions]'ExplicitCapture, IgnorePatternWhitespace')

        $motionMatches = $pattern.Match($motionText)
        $motionMatches.Groups
        $motionResult = [PSCustomObject]@{
            Digit   = $motionMatches.Groups['Digit'].Value -as [int]
            Action  = $motionMatches.Groups['Action'].Value -as [char]
            Arg     = $motionMatches.Groups['Arg'].Value -as [char]
            Unknown = $motionMatches.Groups['Unknown'].Value -as [string]
        }
    }
}
