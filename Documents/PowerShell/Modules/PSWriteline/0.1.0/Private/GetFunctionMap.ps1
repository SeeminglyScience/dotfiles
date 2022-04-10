function GetFunctionMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()
    end {
        $functionMap = @{}
        $functionMap.CommandPalette = [PSCustomObject]@{
            BriefDescription = 'CommandPalette'
            Description      = 'Search and invoke PSReadline key handlers by name.'
            ScriptBlock      = ${function:CommandPalette}
        }

        $functionMap.SmartBrace = [PSCustomObject]@{
            BriefDescription = 'SmartBrace'
            Description      = 'Insert matching braces'
            ScriptBlock      = ${function:SmartBrace}
        }

        $functionMap.SmartCloseBrace = [PSCustomObject]@{
            BriefDescription = 'SmartCloseBrace'
            Description      = 'Insert closing brace or skip'
            ScriptBlock      = ${function:SmartCloseBrace}
        }

        $functionMap.SmartDelete = [PSCustomObject]@{
            BriefDescription = 'SmartDelete'
            Description      = 'Delete previous character or matching quotes/parens/braces'
            ScriptBlock      = ${function:SmartDelete}
        }

        $functionMap.SmartQuote = [PSCustomObject]@{
            BriefDescription = 'SmartQuote'
            Description      = 'Insert paired quotes if not already on a quote'
            ScriptBlock      = ${function:SmartQuote}
        }

        $functionMap.SmartSelfInsert = [PSCustomObject]@{
            BriefDescription = 'SmartSelfInsert'
            Description      = 'Insert the character pressed or complete a hot string.'
            ScriptBlock      = ${function:SmartSelfInsert}
        }

        $functionMap.SmartTab = [PSCustomObject]@{
            BriefDescription = 'SmartTab'
            Description      = 'Complete the current expression or increase indent.'
            ScriptBlock      = ${function:SmartTab}
        }

        $functionMap.DeleteRealLine = [PSCustomObject]@{
            BriefDescription = 'DeleteRealLine'
            Description      = 'Delete the line that the cursor is on. This deletes the actual line instead of the entire buffer.'
            ScriptBlock      = ${function:DeleteRealLine}
        }

        $functionMap.GotoStartOfBuffer = [PSCustomObject]@{
            BriefDescription = 'GotoStartOfBuffer'
            Description      = 'Go to the start of the input buffer regardless of the current line.'
            ScriptBlock      = {
                [Microsoft.PowerShell.PSConsoleReadLine]::BeginningOfLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::BeginningOfLine()
            }
        }

        $functionMap.GotoEndOfBuffer = [PSCustomObject]@{
            BriefDescription = 'GotoEndOfBuffer'
            Description      = 'Go to the start of the input buffer regardless of the current line.'
            ScriptBlock      = {
                [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
            }
        }

        $PSCmdlet.WriteObject($functionMap, $false)
    }
}
