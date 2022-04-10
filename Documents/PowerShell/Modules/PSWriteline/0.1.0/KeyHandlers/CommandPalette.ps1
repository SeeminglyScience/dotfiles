function CommandPalette {
    param(
        [System.Nullable[System.ConsoleKeyInfo]] $key,
        [object] $arg
    )
    end {
        $handlers = Get-PSWritelineKeyHandler
        $resultGetter = {
            param([string] $Query)
            end {
                return $handlers.Where{ $PSItem.Name -like "*$Query*" }
            }
        }
        $resultFormatter = {
            param([psobject] $Handler)
            end {
                return '{0} - {1}' -f $Handler.Name, $Handler.Description
            }
        }

        $result = InvokeStatusPrompt `
            -Prompt 'Command Search' `
            -ResultGetterCallback $resultGetter `
            -ResultFormatterCallback $resultFormatter

        if (-not $result) { return }

        $action = GetHandlerAction -Handler $result
        $action.Invoke()
    }
}
