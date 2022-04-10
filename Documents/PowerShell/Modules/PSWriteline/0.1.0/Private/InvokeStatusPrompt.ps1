function InvokeStatusPrompt {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', '')]
    param(
        [ValidateNotNull()]
        [string] $Prompt,

        [ValidateNotNull()]
        [Func[string, object]] $ResultGetterCallback,

        [ValidateNotNull()]
        [Func[object, string]] $ResultFormatterCallback,

        [ValidateNotNull()]
        [Action[ConsoleKeyInfo, psobject]] $PromptKeyHandler
    )
    begin {
        # Save the current buffer, cursor position, selection range and selection command count to
        # be restored after the command is found.
        function ExportState {
            end {
                $start = $length = $cursor = $inputBuffer = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$inputBuffer, [ref]$cursor)
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$start, [ref]$length)
                if ($start -ne -1) {
                    $selectionState = [PSCustomObject]@{
                        Start    = $start
                        End      = $start + $length
                        Commands = $instance.GetType().
                            GetField('_visualSelectionCommandCount', $flags).
                            GetValue($instance)
                    }
                }

                return [PSCustomObject]@{
                    PSTypeName  = 'PSWriteline.BufferState'
                    InputBuffer = $inputBuffer
                    CursorIndex = $cursor
                    Selection   = $selectionState
                }
            }
        }

        # Import inital state after command is found.
        function ImportState {
            param([PSTypeName('PSWriteline.BufferState')] $State)
            end {
                $null = & {
                    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

                    $buffer.Clear()
                    $promptState.Prompt.Clear()
                    $statusPromptField.SetValue($instance, $null)

                    if ($State.InputBuffer) {
                        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($State.InputBuffer)
                    }

                    if ($State.Selection) {
                        $start = $State.Selection.Start
                        $end   = $State.Selection.End
                        if ($State.Selection.Start -eq $State.CursorIndex) {
                                $start = $State.Selection.End
                                $end   = $State.Selection.Start
                        }

                        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($start)

                        $instance.GetType().
                            GetMethod('VisualSelectionCommon', $flags).
                            CreateDelegate([Action[Action]], $instance).
                            Invoke({ [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end) })

                        $instance.GetType().
                            GetField('_visualSelectionCommandCount', $flags).
                            SetValue($instance, $State.Selection.Commands + 1)

                    } elseif ($State.CursorIndex) {
                        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($State.CursorIndex)
                    }
                }
            }
        }

        function RenderPrompt {
            [Microsoft.PowerShell.PSConsoleReadLine].
                GetMethod('Render', $flags).
                Invoke($instance, @())
        }

        # Draw the current search prompt
        function RenderPalette {
            end {
                if (-not $ResultGetterCallback) {
                    RenderPrompt
                    return
                }

                $null = & {
                    # Setting this to 0 clears selection
                    $instance.GetType().
                        GetField('_visualSelectionCommandCount', $flags).
                        SetValue($instance, 0)

                    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                    $buffer.Clear()
                    $currentMatch = $promptState.GetCurrent()
                    if ($currentMatch) {
                        $resultText = $currentMatch
                        if ($ResultFormatterCallback) {
                            $resultText = $ResultFormatterCallback.Invoke($currentMatch)
                        }

                        $buffer.Append($resultText)
                    }

                    RenderPrompt
                }
            }
        }

        function UpdateMatches {
            end {
                if (-not $ResultGetterCallback) {
                    return
                }

                $promptState.MatchList.Clear()
                if ($promptState.Prompt.Length) {
                    [object[]]$results = $ResultGetterCallback.Invoke($promptState.Prompt.ToString())
                    if ($results.Count) {
                        $promptState.MatchList.AddRange($results)
                    }
                }

                $promptState.MatchIndex = 0
            }
        }

        function HandleKey {
            param([ConsoleKeyInfo] $Key, [psobject] $State)
            switch ($Key.Key) {
                Backspace {
                    if ($State.Prompt.Length) {
                        $null = $State.Prompt.Remove($state.Prompt.Length - 1, 1)
                        $State.ShouldUpdate = $true
                    }
                }
                Escape {
                    $State.ShouldExit = $true
                }
                Tab {
                    if ($Key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) {
                        $State.MoveNext()
                    } else {
                        $State.MovePrevious()
                    }
                }
                Enter {
                    $State.ShouldExit = $true
                    if ($currentMatch = $State.GetCurrent()) {
                        return $currentMatch
                    }
                }
                default {
                    if (-not $Key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
                        $null = $State.Prompt.Append($Key.KeyChar)
                        $State.ShouldUpdate = $true
                    }
                }
            }
        }

        $flags              = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $instance           = GetSingleton
        $buffer             = $instance.GetType().GetField('_buffer', $flags).GetValue($instance)
        $statusBuffer       = $instance.GetType().GetField('_statusBuffer', $flags).GetValue($instance)
        $statusPromptField  = $instance.GetType().GetField('_statusLinePrompt', $flags)

        if ($ResultGetterCallback) {
            $bufferState        = ExportState
        }

        $promptState = New-Module -AsCustomObject -ArgumentList $statusBuffer -ScriptBlock {
            $Prompt       = $args[0]
            $MatchList    = [System.Collections.Generic.List[object]]::new()
            $MatchIndex   = 0
            $ShouldUpdate = $false
            $ShouldExit   = $false

            function GetCurrent {
                end {
                    if (-not $this.MatchList.Count) { return }

                    return $this.MatchList[$this.MatchIndex]
                }
            }

            # Increment match index (for tab handling)
            function MoveNext {
                end {
                    if ($this.MatchIndex + 1 -eq $this.MatchList.Count) {
                        $this.MatchIndex = 0
                        return
                    }

                    $this.MatchIndex++
                }
            }

            function MovePrevious {
                end {
                    if ($this.MatchIndex -eq 0) {
                        $this.MatchIndex = $this.MatchList.Count - 1
                        return
                    }

                    $this.MatchIndex--
                }
            }

            Export-ModuleMember -Function * -Variable *
        }
    }
    end {
        if (-not [string]::IsNullOrEmpty($Prompt)) {
            $null = $statusPromptField.SetValue($instance, $Prompt + ': ')
        }

        try {
            while (-not $promptState.ShouldExit) {
                $null = RenderPalette
                $pressedKey = [Console]::ReadKey()

                HandleKey -Key $pressedKey -State $promptState
                if ($PromptKeyHandler) {
                    $PromptKeyHandler.Invoke($pressedKey, $promptState)

                    if ($promptState.ShouldExit) {
                        $PSCmdlet.WriteObject($promptState.Prompt.ToString())
                        continue
                    }
                }

                if ($promptState.ShouldUpdate) {
                    $promptState.ShouldUpdate = $false
                    UpdateMatches
                }
            }
        } finally {
            $null = $statusPromptField.SetValue($instance, $null)
            $null = $statusBuffer.Clear()
            if ($ResultGetterCallback) {
                ImportState $bufferState
            }

            RenderPrompt
        }
    }
}
