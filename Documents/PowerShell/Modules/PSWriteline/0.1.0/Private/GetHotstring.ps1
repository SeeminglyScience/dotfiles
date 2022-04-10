using namespace System.Collections.Generic

function GetHotstring {
    [OutputType([System.Collections.Generic.List[psobject]], ParameterSetName='Character')]
    [OutputType([System.Collections.Generic.Dictionary[char, System.Collections.Generic.List[psobject]]])]
    [CmdletBinding(DefaultParameterSetName='__AllParameterSets')]
    param(
        [Parameter(Mandatory, ParameterSetName='Character')]
        [ValidateNotNullOrEmpty()]
        [char] $Character
    )
    end {
        if (-not $script:HOTSTRING_STORE) {
            $script:HOTSTRING_STORE = [Dictionary[char, List[psobject]]]::new()
        }

        $store = $script:HOTSTRING_STORE
        if ($null -eq $Character) {
            $PSCmdlet.WriteObject($store, $false)
            return
        }

        $bindingList = $null
        if ($store.TryGetValue($Character, [ref]$bindingList)) {
            $PSCmdlet.WriteObject($bindingList, $false)
            return
        }

        $bindingList = [List[psobject]]::new()
        $store.Add($Character, $bindingList)

        $PSCmdlet.WriteObject($bindingList, $false)
        return
    }
}
