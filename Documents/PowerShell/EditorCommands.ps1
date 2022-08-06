using namespace System.Collections.Generic
using namespace System.Management.Automation.Language
using namespace System.Text

function global:Get-Cursor {
    [OutputType([System.Management.Automation.Language.IScriptPosition])]
    [CmdletBinding()]
    param()
    end {
        $psEditor.GetEditorContext().CursorPosition |
            ConvertTo-ScriptExtent |
            ConvertTo-ScriptPosition
    }
}

function global:Get-NormalizedIndentation {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Line
    )
    begin {
        $lines = [List[string]]::new()
    }
    process {
        $lines.AddRange($Line -split '\r?\n')
    }
    end {
        $leastLeadingWS = -1
        foreach ($singleLine in $lines) {
            if (-not $singleLine) {
                continue
            }

            if ($singleLine -match '^( +)') {
                $leadingWS = [int]$matches[1].Length
                if ($leastLeadingWS -eq -1) {
                    $leastLeadingWS = $leadingWS
                    continue
                }

                if ($leastLeadingWS -gt $leadingWS) {
                    $leastLeadingWS = $leadingWS
                }

                continue
            }

            $leastLeadingWS = 0
            break
        }

        if ($leastLeadingWS -gt 0) {
            $lines = foreach ($singleLine in $lines) {
                if (-not $singleLine) {
                    $singleLine
                    continue
                }

                $singleLine.Substring($leastLeadingWS, $singleLine.Length - $leastLeadingWS)
            }
        }

        return $lines -join "`n"
    }
}

function global:Get-Selection {
    [OutputType([System.Management.Automation.Language.IScriptExtent])]
    [CmdletBinding()]
    param()
    end {
        $psEditor.GetEditorContext().SelectedRange | ConvertTo-ScriptExtent
    }
}

function global:ConvertTo-ScriptPosition {
    [OutputType([System.Management.Automation.Language.IScriptPosition])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.Management.Automation.Language.IScriptExtent] $Extent
    )
    process {
        if (-not $Extent) {
            return
        }

        $Extent.EndScriptPosition
    }
}

Register-EditorCommand -DisplayName 'Get Completion Results' -Name GetCompletionResults -ScriptBlock {
    param([Microsoft.PowerShell.EditorServices.Extensions.EditorContext, Microsoft.PowerShell.EditorServices] $Context)
    end {
        $psesPosition = Get-Cursor
        $startPosition = $Context.CurrentFile.Ast.Extent.StartScriptPosition
        $cursorPosition = $startPosition.GetType().
            GetMethod('CloneWithNewOffset', [System.Reflection.BindingFlags]::NonPublic -bor 'Instance').
            Invoke($startPosition, @($psesPosition.Offset))

        try {
            $tabExpansion2Splat = @{
                ast = $Context.CurrentFile.Ast
                tokens = $Context.CurrentFile.Tokens
                positionOfCursor = $cursorPosition
                ErrorAction = 'Stop'
            }

            $results = TabExpansion2 @tabExpansion2Splat

            'TextToBeReplaced = |{0}|' -f (
                $Context.CurrentFile.Ast.Extent.StartScriptPosition.GetFullScript().Substring(
                    $results.ReplacementIndex,
                    $results.ReplacementLength)) | Out-Default

            $results | Out-Default
            $results.CompletionMatches | Out-Default
            $global:__lastCompletionResult = $results
        } catch {
            $PSItem | Out-Default
        }
    }
}.Ast.GetScriptBlock()

# Register in an anonymous module so we can invoke in the REPL scope.
$null = New-Module {
    function Get-Cursor {
        [OutputType([System.Management.Automation.Language.IScriptPosition])]
        [CmdletBinding()]
        param()
        end {
            $psEditor.GetEditorContext().CursorPosition |
                ConvertTo-ScriptExtent |
                ConvertTo-ScriptPosition
        }
    }

    function Get-NormalizedIndentation {
        [OutputType([string])]
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [string] $Line
        )
        begin {
            $lines = [System.Collections.Generic.List[string]]::new()
        }
        process {
            $lines.AddRange($Line -split '\r?\n')
        }
        end {
            $leastLeadingWS = -1
            foreach ($singleLine in $lines) {
                if (-not $singleLine) {
                    continue
                }

                if ($singleLine -match '^( +)') {
                    $leadingWS = [int]$matches[1].Length
                    if ($leastLeadingWS -eq -1) {
                        $leastLeadingWS = $leadingWS
                        continue
                    }

                    if ($leastLeadingWS -gt $leadingWS) {
                        $leastLeadingWS = $leadingWS
                    }

                    continue
                }

                $leastLeadingWS = 0
                break
            }

            if ($leastLeadingWS -gt 0) {
                $lines = foreach ($singleLine in $lines) {
                    if (-not $singleLine) {
                        $singleLine
                        continue
                    }

                    $singleLine.Substring($leastLeadingWS, $singleLine.Length - $leastLeadingWS)
                }
            }

            return $lines -join "`n"
        }
    }

    function Get-Selection {
        [OutputType([System.Management.Automation.Language.IScriptExtent])]
        [CmdletBinding()]
        param()
        end {
            $psEditor.GetEditorContext().SelectedRange | ConvertTo-ScriptExtent
        }
    }

    function ConvertTo-ScriptPosition {
        [OutputType([System.Management.Automation.Language.IScriptPosition])]
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [System.Management.Automation.Language.IScriptExtent] $Extent
        )
        process {
            if (-not $Extent) {
                return
            }

            $Extent.EndScriptPosition
        }
    }

    Register-EditorCommand -DisplayName 'Evaluate selection' -Name EvaluateSelection -ScriptBlock {
        param([Microsoft.PowerShell.EditorServices.Extensions.EditorContext, Microsoft.PowerShell.EditorServices] $Context)
        end {
            $psrlOptions = Get-PSReadLineOption
            $continuationPrompt = $psrlOptions.ContinuationPrompt
            $continuationPrompt = '{0}{1}{2}' -f $psrlOptions.ContinuationPromptColor, $continuationPrompt, $PSStyle.Reset
            [StringBuilder] $sb = [StringBuilder]::new()
            [ScriptBlockAst] $sbAst = $Context.CurrentFile.Ast
            foreach ($usingStatement in $sbAst.UsingStatements) {
                if ($usingStatement.UsingStatementKind -ne [UsingStatementKind]::Namespace) {
                    continue
                }

                if (-not $sb.Length) {
                    $null = $sb.AppendLine()
                }

                $null = $sb.AppendFormat('using namespace {0}', $usingStatement.Name).
                    AppendLine()
            }

            if ($sb.Length) {
                $null = $sb.AppendLine()
            }

            $currentSelection = Get-Selection
            $evalScript = $null
            if ($currentSelection.StartOffset -eq $currentSelection.EndOffset) {
                $evalScript = $currentSelection.StartScriptPosition.Line
            } else {
                $evalScript = $currentSelection.Text
            }

            $evalScript = $evalScript | Get-NormalizedIndentation
            $evalScript = $sb.Append($evalScript).ToString()

            $promptResult = prompt
            $Host.UI.Write($promptResult)
            $first = $true
            $prettyScript = $evalScript | bat -l powershell --color=always --paging=never --style=plain | ForEach-Object {
                if ($first) {
                    $first = $false
                } else {
                    return $continuationPrompt, $PSItem -join ''
                }

                return $PSItem
            }

            $Host.UI.WriteLine($prettyScript -join "`n")
            $targetModule = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Module

            # If the frame above us is not in a module then we want the global session state.
            if (-not $targetModule) {
                $tempModule = [psmoduleinfo]::new($false)
                $flags = [System.Reflection.BindingFlags]::Instance -bor 'NonPublic'
                $ec = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
                $tlss = $ec.GetType().GetProperty('TopLevelSessionState', $flags).GetValue($ec)
                $pss = $tlss.GetType().GetProperty('PublicSessionState', $flags).GetValue($tlss)

                $tempModule.SessionState = $pss
                $targetModule = $tempModule
            }

            # Point both errors and output to Out-Default. Done this way instead of a try catch so
            # it doesn't mess up flow control.
            & {
                . $targetModule ([scriptblock]::Create($evalScript))
            } 2>&1 | Out-Default
        }
    }
}
