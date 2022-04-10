# Originally this was going to make symlinks but that doesn't seem to work either :/
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ApexPath
)
end {
    if (-not $ApexPath) {
        $ApexPath = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Apex Legends"
    }

    $configFolder = Join-Path $ApexPath cfg
    $autoExec = Join-Path $configFolder autoexec.cfg
    $apexConfig = Join-Path $configFolder apex-config.cfg
    $splat = @{ ErrorAction = 'Stop' }
    Copy-Item @splat -Path (Join-Path $PSScriptRoot autoexec.cfg) -Destination $autoExec
    Copy-Item @splat -Path (Join-Path $PSScriptRoot apex-config.cfg) -Destination $apexConfig
}
