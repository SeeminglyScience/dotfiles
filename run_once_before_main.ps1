using namespace System.Security.Principal

[CmdletBinding()]
param()
begin {
    function MaybeInstallScoopApp {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [ValidateNotNullOrEmpty()]
            [string] $Name,

            [Parameter()]
            [AllowNull()]
            [AllowEmptyString()]
            [string] $Application
        )
        process {
            if (-not $Application) {
                $Application = $Name
            }

            if (Get-Command $Application -CommandType Application -ErrorAction Ignore) {
                return
            }

            scoop install $Name
        }
    }
}
end {
    scoop bucket add extras
    MaybeInstallScoopApp 7zip 7z

    $scoopApps = @(
        'bat'
        'less'
        'gh'
        'gpg'
        'wsl-ssh-pageant'
        'python'
        'gzip'
        'tar'
        'wget'
        'sed'
        'fzf'
        'htmlq'
        'delta'
        'clangd'
    )

    foreach ($app in $scoopApps) {
        MaybeInstallScoopApp $app
    }

    scoop install flow-launcher

    if ([WindowsIdentity]::GetCurrent().Owner.IsWellKnown([WellKnownSidType]::BuiltinAdministratorsSid)) {
        & "$PSScriptRoot\admin_tasks.ps1"
    } else {
        Start-Process powershell -Verb RunAs -Wait -ArgumentList (
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy Bypass',
            '-File', ('"{0}\admin_tasks.ps1"' -f $PSScriptRoot))
    }

    MaybeInstallScoopApp bitwarden-cli bw

    $env = @{
        'SSH_AUTH_SOCK' = '\\.\pipe\ssh-pageant'
        'GIT_SSH' = 'C:\Windows\System32\OpenSSH\ssh.exe'
        'LESS' = '--quiet --raw-control-chars --quit-on-intr --ignore-case --prompt :'
        'LESSCHARSET' = 'utf-8'
        'CLASS_EXPLORER_TRUE_CHARACTER' = [char]0x2713 # check mark
        'BAT_THEME' = 'Visual Studio Dark+'
    }

    foreach ($kvp in $env.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($kvp.Name, $kvp.Value, [EnvironmentVariableTarget]::User)
    }

    & "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile {
        if ((Import-Module PowerShellGet -PassThru).Version.Major -ge 3) {
            return
        }

        Install-Module PowerShellGet -Scope CurrentUser -AllowPrerelease -Force -AllowClobber -SkipPublisherCheck -MinimumVersion 3.0.0
    }

    & "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile {
        $modules = (
            'ClassExplorer',
            'EditorServicesCommandSuite',
            'ScriptBlockDisassembler',
            'ImpliedReflection',
            'ILAssembler',
            'ImportExcel',
            'InvokeBuild',
            'platyPS',
            'ProcessEx',
            'PSFzf',
            'PSLambda',
            'PSScriptAnalyzer',
            'ThreadJob',
            'PSEverything')

        $existingModules = Get-Module -ListAvailable |
            Group-Object Name |
            Select-Object -ExpandProperty Name

        foreach ($module in $modules) {
            if ($module -in $existingModules) {
                continue
            }

            Install-PSResource $module -Prerelease -Scope CurrentUser -TrustRepository -AcceptLicense
        }
    }
}
