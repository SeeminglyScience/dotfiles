function NewUnboundHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateNotNull()]
        [string] $Description,

        [ValidateNotNull()]
        [scriptblock] $Action
    )
    end {
        if ($null -eq $script:UNBOUND_STORE) {
            $script:UNBOUND_STORE = [System.Collections.Generic.Dictionary[string, psobject]]::new()
        }

        $handler = [PSCustomObject]@{
            PSTypeName  = 'PSWriteLine.Handler'
            Key         = 'Unbound'
            Name        = $Name
            Description = $Description
            Action      = $Action
        }

        $handler.PSTypeNames.Insert(0, 'PSWriteline.UnboundHandler')
        $store = $script:UNBOUND_STORE
        if ($store.ContainsKey($Name)) {
            $store[$Name] = $handler
            return
        }

        $store.Add($Name, $handler)
    }
}
