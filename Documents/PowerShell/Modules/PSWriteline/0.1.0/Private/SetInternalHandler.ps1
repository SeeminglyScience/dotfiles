function SetInternalHandler {
    [CmdletBinding()]
    param(
        [string] $Name,
        [string[]] $CommandChord,
        [string[]] $InsertChord,
        [switch] $ViOnly,
        [switch] $Hotstring,
        [switch] $Unbound
    )
    end {
        $isVi        = $script:IS_VI_MODE
        $functionMap = GetFunctionMap
        $mapping     = $functionMap.$Name
        if (-not $mapping) { return }

        if ($Hotstring.IsPresent) {
            NewHotstring `
                -Trigger $InsertChord[0] `
                -Name $mapping.BriefDescription `
                -Description $mapping.Description `
                -Action $mapping.ScriptBlock
            return
        }

        if ($Unbound.IsPresent) {
            NewUnboundHandler `
                -Name $mapping.BriefDescription `
                -Description $mapping.Description `
                -Action $mapping.ScriptBlock
            return
        }

        $splat = @{
            ScriptBlock      = $mapping.ScriptBlock
            BriefDescription = $mapping.BriefDescription
            Description      = $mapping.Description
        }

        if (-not $isVi -and ($ViOnly.IsPresent -or -not $InsertChord)) {
            return
        }

        if ($isVi) {
            if ($CommandChord) {
                $splat.ViMode = 'Command'
                $splat.Chord = $CommandChord
            } else {
                $splat.ViMode = 'Insert'
            }
        }

        if (-not $splat.Chord) {
            $splat.Chord = $InsertChord
        }

        Set-PSReadlineKeyHandler @splat
    }
}
