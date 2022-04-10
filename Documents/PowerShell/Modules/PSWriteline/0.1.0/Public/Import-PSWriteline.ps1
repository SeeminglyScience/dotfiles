function Import-PSWriteline {
    [CmdletBinding()]
    param(
        [switch]
        $ViMode
    )
    end {
        $script:IS_VI_MODE = $ViMode.IsPresent

        if ($ViMode.IsPresent) {
            Set-PSReadlineOption -EditMode Vi -ViModeIndicator Cursor -ShowToolTips
            Set-PSReadlineKeyHandler -Chord k -Function HistorySearchBackward -ViMode Command
            Set-PSReadlineKeyHandler -Chord j -Function HistorySearchForward -ViMode Command
        }

        SetInternalHandler CommandPalette -CommandChord ':'
        SetInternalHandler CommandPalette -InsertChord 'CTRL+SHIFT+P'
        SetInternalHandler SmartTab -InsertChord 'TAB'
        SetInternalHandler SmartQuote -InsertChord '"', "'"
        SetInternalHandler SmartBrace -InsertChord '(', '{', '['
        SetInternalHandler SmartCloseBrace -InsertChord ')', ']', '}'
        SetInternalHandler SmartDelete -InsertChord 'Backspace'
        SetInternalHandler DeleteRealLine -CommandChord 'd,d'
        SetInternalHandler GotoStartOfBuffer -CommandChord 'g,g'
        SetInternalHandler GotoEndOfBuffer -CommandChord SHIFT+g

        Set-PSWritelineKeyHandler -Chord 'jj' -Function ViCommandMode -ViMode Insert -ViOnly -Hotstring
        Set-PSWritelineKeyHandler -Chord 'g,d' -ViMode Command -Function DeleteLine
        Set-PSWritelineKeyHandler -Chord CTRL+a -Function SelectAll -ViMode Insert
        Set-PSWritelineKeyHandler -Chord CTRL+a -Function SelectAll -ViMode Command
        Set-PSWritelineKeyHandler -Chord SHIFT+LeftArrow -Function SelectBackwardChar -ViMode Insert
        Set-PSWritelineKeyHandler -Chord SHIFT+RightArrow -Function SelectForwardChar -ViMode Insert
        Set-PSWritelineKeyHandler -Chord CTRL+SHIFT+LeftArrow -Function SelectBackwardWord -ViMode Insert
        Set-PSWritelineKeyHandler -Chord CTRL+SHIFT+RightArrow -Function SelectNextWord -ViMode Insert
        Set-PSWritelineKeyHandler -Chord SHIFT+Home -Function SelectBackwardsLine -ViMode Insert
        Set-PSWritelineKeyHandler -Chord SHIFT+End -Function SelectLine -ViMode Insert
    }
}
