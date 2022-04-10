& {
    if ($importPSWriteLine = Get-Command Import-PSWriteline -ErrorAction Ignore) {
        & $importPSWriteLine -ViMode
        # Set-PSWritelineKeyHandler -Chord 'jj' -ViMode Insert -Hotstring -ViOnly -BriefDescription 'CommandMode' -Description 'asdf' -ScriptBlock {
        #     [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
        #     [Console]::Write($global:PSRL_COMMAND_MODE)
        # }
    }
}

Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
    if ($args[0] -eq 'Command') {
        [Console]::Write($global:PSRL_COMMAND_MODE)
    } else {
        [Console]::Write($global:PSRL_INSERT_MODE)
    }
}

Import-Module PSLambda

class BoxCache {
    static [object] $BoolTrue = $true
}

$addToHistoryDelegate = il { [object]([string] $promptText) } {
    call { [object] [BoxCache]::get_BoolTrue() }
    ret
}

Set-PSReadLineOption -AddToHistoryHandler $addToHistoryDelegate

$esc = [char]0x1b
$global:PSRL_INSERT_MODE = "${esc}[5 q"
$global:PSRL_COMMAND_MODE = "${esc}[1 q"

$bg = "${esc}[48;2;40;40;40m"
$reset = "${esc}[27m${esc}[24m$bg"
$underline = "${esc}[27m${esc}[4m$bg"
Set-PSReadLineOption -Colors @{
    Member             = "${reset}${esc}[38;2;228;228;228m"   #e4e4e4
    Parameter          = "${reset}${esc}[38;2;228;228;228m"   #e4e4e4
    Default            = "${reset}${esc}[38;2;228;228;228m"   #e4e4e4
    ContinuationPrompt = "${reset}${esc}[38;2;90;90;90m"      #5a5a5a
    Operator           = "${reset}${esc}[38;2;197;197;197m"   #c5c5c5
    Keyword            = "${reset}${esc}[38;2;197;134;192m"   #c586c0
    Command            = "${reset}${esc}[38;2;220;220;170m"   #dcdcaa
    Emphasis           = "${underline}${esc}[48;2;38;79;120m" #264f78
    Selection          = "${reset}${esc}[48;2;38;79;120m"     #264f78
    Type               = "${reset}${esc}[38;2;78;201;176m"    #4ec9b0
    Variable           = "${reset}${esc}[38;2;124;220;254m"   #7cdcfe
    String             = "${reset}${esc}[38;2;206;145;120m"   #ce9178
    Comment            = "${reset}${esc}[38;2;96;139;78m"     #608b4e
    Number             = "${reset}${esc}[38;2;147;206;168m"   #93cea8
    Error              = "${reset}${esc}[38;2;139;0;0m"       #8b0000
}

if ($PSStyle) {
    # $resetField = $PSStyle.GetType().GetField(
    #     '<Reset>k__BackingField',
    #     [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)

    # if ($null -ne $resetField) {
    #     $resetField.SetValue($PSStyle, $reset)
    # }

    $PSStyle.Formatting.TableHeader = $PSStyle.Foreground.FromRgb(0x7D, 0xC8, 0x64)
}

if ($__IsVSCode) {
    # Use with the VSCode extension terminal-input to bind otherwise unbindable key combos.
    # e.g. Map shift + enter from VSCode to send char 0x2665 (heart) as input.
    Set-PSReadLineKeyHandler -Chord "$([char]0x2665)" -Function AddLine -ViMode Insert
    Set-PSReadLineKeyHandler -Chord "$([char]0x2714)" -Function Paste -ViMode Insert
}

# When editing a multi-line prompt, PSReadLine will typically prefix each line with `>>`. That's
# pretty helpful visually, but it makes copying a bit of pain. I used to have this as an empty string,
# but that causes some rendering issues that I need to report. In the mean time, four spaces is nice
# because it visually distinguishes the line, and also puts it at the right indent for reddit/stackoverflow's
# code formatting syntax.
Set-PSReadLineOption -ContinuationPrompt '    '

if ($psEditor) {
    # Use the same history file for VSCode.
    $currentSavePath = (Get-PSReadLineOption).HistorySavePath
    Set-PSReadLineOption -HistorySavePath $currentSavePath.Replace($Host.Name, 'ConsoleHost')
}

if ($__IsVSCode -or -not $__IsWindows) {
    Set-PSReadLineKeyHandler -Chord "ctrl+@" -Function PossibleCompletions -ViMode Insert
    Set-PSReadLineKeyHandler -Chord 'ctrl+h' -Function BackwardKillWord -ViMode Insert
}


if ($__IsWindows) {
    Set-PSReadLineKeyHandler -Chord PageDown -Function ScrollDisplayDown
    Set-PSReadLineKeyHandler -Chord PageUp -Function ScrollDisplayUp
    Set-PSReadLineKeyHandler -Chord ctrl+b -Function ScrollDisplayUp
    Set-PSReadLineKeyHandler -Chord ctrl+f -Function ScrollDisplayDown
}

Set-PSReadLineKeyHandler -Chord UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord 'ctrl+w' -Function BackwardKillWord -ViMode Insert

Set-PSReadLineKeyHandler -Chord i -BriefDescription Insert -ViMode Command -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
    [Console]::Write($global:PSRL_INSERT_MODE)
}

Set-PSReadLineKeyHandler `
    -Chord ctrl+v `
    -BriefDescription SmartPaste `
    -Description (
        'If pasting a valid path outside of a quoted string literal, surround ' +
        'with quotes and escape. Otherwise paste normally.') `
    -ScriptBlock {
        param([Nullable[ConsoleKeyInfo]] $key, [object] $arg) end {
            $psrl = [Microsoft.PowerShell.PSConsoleReadLine]
            $clipText = Get-Clipboard
            $shouldSkipQuoting = [string]::IsNullOrEmpty($clipText) -or
                -not $clipText.Contains(' ') -or
                -not (Test-Path $clipText) -or
                # Use Regex.IsMatch to avoid changing global `$matches` variable.
                [regex]::IsMatch($clipText, '^(?<quote>''|").*\k<quote>$')

            if ($shouldSkipQuoting) {
                $psrl::Paste($key, $arg)
                return
            }

            $sbAst = $cursor = $null
            $psrl::GetBufferState(
                <# ast:         #> [ref] $sbAst,
                <# tokens:      #> [ref] $null,
                <# parseErrors: #> [ref] $null,
                <# cursor:      #> [ref] $cursor)

            $relatedAsts = $sbAst.FindAll(
                {
                    param([System.Management.Automation.Language.Ast] $a) end {
                        return $a.Extent.StartOffset -le $cursor -and
                            $a.Extent.EndOffset -ge $cursor
                    }
                },
                <# searchNestedScriptBlocks: #> $true)

            $startingPosition = @{
                Descending = $true
                Expression = { $PSItem.Extent.StartOffset }
            }

            $nodeLength = @{
                Descending = $false
                Expression = { $PSItem.Extent.EndOffset - $PSItem.Extent.StartOffset }
            }

            $parentCount = @{
                Descending = $true
                Expression = {
                    $count = 0
                    for ($node = $PSItem; $null -ne $node; $node = $node.Parent) {
                        $count++
                    }

                    return $count
                }
            }

            $closestAst = $relatedAsts |
                Sort-Object $startingPosition, $nodeLength, $parentCount |
                Select-Object -First 1

            $isInQuotedString = $closestAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $closestAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord

            if ($isInQuotedString) {
                $psrl::Paste($key, $arg)
                return
            }

            # Use insert for the whole string instead of building with separate
            # inserts and paste so PSRL considers it a single edit group for undos.
            $clipText = "'" + ($clipText -replace "([\u2018\u2019\u201a\u201b'])", '$1$1') + "'"
            $psrl::Insert($clipText)
        }
    }
