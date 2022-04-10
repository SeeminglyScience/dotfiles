function Get-PSWritelineKeyHandler {
    [OutputType([psobject])]
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Key,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Name
    )
    begin {
        $handlers = [System.Collections.Generic.List[psobject]]::new()
        Get-PSReadlineKeyHandler | Where-Object Function -ne 'SmartSelfInsert' | ForEach-Object {
            $proxyHandler = [PSCustomObject]@{
                PSTypeName  = 'PSWriteline.Handler'
                Key         = $PSItem.Key
                Name        = $PSItem.Function
                Description = $PSItem.Description
            }

            $proxyHandler.PSTypeNames.Insert(0, 'PSWriteline.PSReadlineHandler')
            $handlers.Add($proxyHandler)
        }

        $hotstringStore = GetHotstring
        $hotstringStore.Values |
            ForEach-Object { $handlers.Add($PSItem) }

        if ($unbound = $script:UNBOUND_STORE) {
            $handlers.AddRange($unbound.Values)
        }

        $alreadyProcessed = [System.Collections.Generic.HashSet[psobject]]::new()
    }
    process {
        if (-not $Name -and -not $Key) {
            $PSCmdlet.WriteObject($handlers, $true)
            return
        }

        $handlers |
            Where-Object {
                (-not $Key -or $PSItem.Key -like $Key) -and
                (-not $Name -or $PSItem.Name -like $Name)
            } | ForEach-Object {
                if (-not $alreadyProcessed.Contains($PSItem)) {
                    $null = $alreadyProcessed.Add($PSItem)
                    $PSCmdlet.WriteObject($PSItem)
                }
            }
    }
}
