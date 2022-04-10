function Set-PSWritelineKeyHandler {
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [Parameter(Mandatory)]
        [Alias('Key')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Chord,

        [ValidateSet('Command', 'Insert')]
        [string] $ViMode = 'Insert',

        [Parameter(Mandatory, ParameterSetName='Function')]
        [ValidateNotNullOrEmpty()]
        [string] $Function,

        [Parameter(Mandatory, ParameterSetName='ScriptBlock')]
        [ValidateNotNull()]
        [scriptblock] $ScriptBlock,

        [Parameter(ParameterSetName='ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $BriefDescription,

        [Parameter(ParameterSetName='ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [switch] $Hotstring,

        [switch] $ViOnly
    )
    end {
        if ($Hotstring.IsPresent) {
            $action = $ScriptBlock
            if ($PSCmdlet.ParameterSetName -eq 'Function') {
                $targetFunction = Get-PSReadlineKeyHandler | Where-Object Function -eq $Function
                if (-not $targetFunction) {
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                            [ArgumentException]::new('Unable to find the PSReadline method "{0}".' -f $Function),
                            'MissingPSReadlineMethod',
                            'ObjectNotFound',
                            $Function))
                }

                $action = [scriptblock]::Create(
                    $PSCmdlet.InvokeCommand.ExpandString(
                        '[Microsoft.PowerShell.PSConsoleReadLine]::$Function.Invoke(`$args)'))
                $BriefDescription = $Function
                $Description      = $targetFunction.Description
            }

            NewHotstring `
                -Trigger $Chord[0] `
                -Action $action `
                -Name $BriefDescription `
                -Description $Description `
                -ViOnly:$ViOnly.IsPresent
            return
        }

        $splat = @{ Chord = $Chord }

        if ($script:IS_VI_MODE) {
            $splat.ViMode = $ViMode
        } elseif ($ViOnly.IsPresent) {
            return
        }

        if ($PSCmdlet.ParameterSetName -eq 'Function') {
            $splat.Function = $Function
        } else {
            $splat.ScriptBlock      = $ScriptBlock
            $splat.BriefDescription = $BriefDescription
            $splat.Description      = $Description
        }

        Set-PSReadlineKeyHandler @splat
    }
}
