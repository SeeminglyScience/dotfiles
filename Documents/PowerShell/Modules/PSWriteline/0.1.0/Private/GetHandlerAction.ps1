function GetHandlerAction {
    [CmdletBinding()]
    param(
        [PSTypeName('PSWriteline.Handler')] $Handler
    )
    begin {
        $flags              = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $instance           = GetSingleton
        $dispatchTable      = $instance.GetType().GetField('_dispatchTable', $flags).GetValue($instance)
        $chordDispatchTable = $instance.GetType().GetField('_chordDispatchTable', $flags).GetValue($instance)
    }
    end {
        if ($Handler.Action) {
            return $Handler.Action
        }

        $realHandler = $dispatchTable.
            Values.
            Where({ $_.BriefDescription -eq $Handler.Name }, 'First')

        if (-not $realHandler) {
            $realHandler = $chordDispatchTable.
                Values.
                Values.
                Where({ $_.BriefDescription -eq $Handler.Name }, 'First')
        }

        if ($realHandler.ScriptBlock) {
            return $realHandler.ScriptBlock
        }

        return [Microsoft.PowerShell.PSConsoleReadLine]::($Handler.Name)
    }
}
