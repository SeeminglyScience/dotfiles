[CmdletBinding()]
param()
begin {
    function ConfirmInstallScript {
        [CmdletBinding()]
        param([string] $Name, [string] $Script)
        end {
            # bat doesn't seem to work right away. Needs a restart or two
            # $bat = Get-Command bat -CommandType Application -ErrorAction Ignore
            # $batArgs = @('-l', 'powershell')
            $bat = $null
            if (-not $bat) {
                $bat = 'more'
                $batArgs = @()
            }

            $Script | & $bat @batArgs
            if (-not $PSCmdlet.ShouldContinue('Or is it bad now :o', "Install ${Name}?")) {
                throw 'it''s bad now :o'
            }

            & ([scriptblock]::Create($Script))
        }
    }

    function MaybeInstallChocoApp {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [ValidateNotNullOrEmpty()]
            [string] $Name,

            [Parameter()]
            [AllowNull()]
            [AllowEmptyString()]
            [string] $Application,

            [switch] $SkipExistingCheck
        )
        process {
            if (-not $SkipExistingCheck) {
                if (-not $Application) {
                    $Application = $Name
                }

                if (Get-Command $Application -CommandType Application -ErrorAction Ignore) {
                    return
                }
            }

            choco install $Name
        }
    }
}
end {
    DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V /NoRestart
    DISM /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /NoRestart
    wsl --install
    DISM /Online /Add-Capability /CapabilityName:Tools.DeveloperMode.Core~~~~0.0.1.0 /NoRestart
    $null = REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"


    $oldProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    $wc = $null
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = $oldProtocol -bor 3072;
        $wc = [System.Net.WebClient]::new()
        if (-not (Get-Command choco -CommandType Application -ErrorAction Ignore)) {
            $chocoInstall = $wc.DownloadString('https://community.chocolatey.org/install.ps1')
            ConfirmInstallScript -Name choco -Script $chocoInstall
        }

        MaybeInstallChocoApp rustup.install rustup
        MaybeInstallChocoApp neovim nvim
        MaybeInstallChocoApp nodejs npm
        MaybeInstallChocoApp obs -SkipExistingCheck
        MaybeInstallChocoApp microsoft-windows-terminal wt
        MaybeInstallChocoApp powertoys -SkipExistingCheck
        MaybeInstallChocoApp cascadia-code-nerd-font -SkipExistingCheck
        MaybeInstallChocoApp pwsh
        MaybeInstallChocoApp bitwarden -SkipExistingCheck
    } finally {
        [System.Net.ServicePointManager]::SecurityProtocol = $oldProtocol
        if ($null -ne $wc) {
            $wc.Dispose()
        }
    }
}
