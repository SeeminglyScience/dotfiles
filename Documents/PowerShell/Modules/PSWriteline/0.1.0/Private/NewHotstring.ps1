using namespace System.Collections.Generic
using namespace System.Management.Automation

function NewHotstring {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Trigger,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock] $Action,

        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [switch] $ViOnly
    )
    end {
        $hotstring = [PSCustomObject]@{
            PSTypeName  = 'PSWriteline.Handler'
            Key         = '%', $Trigger, '%' -join ''
            Name        = $Name
            Description = $Description
            Action      = $Action
            Chars       = $Trigger.ToCharArray()
            TriggerChar = $Trigger.ToCharArray()[-1]
        }
        $hotstring.PSTypeNames.Insert(0, 'PSWriteline.Hotstring')

        $bindingList = GetHotstring -Character $hotstring.TriggerChar
        $bindingList.Add($hotstring)

        SetInternalHandler SmartSelfInsert -InsertChord $hotstring.TriggerChar -ViOnly:$ViOnly.IsPresent
    }
}
