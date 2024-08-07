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
    scoop install https://gist.github.com/SeeminglyScience/8dc717be6e6d362ad65efbdf124922b8/raw/psudad.json

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
        'BAT_PAGER' = 'less --quiet --raw-control-chars --quit-on-intr --ignore-case --prompt : --no-init --chop-long-lines'
    }

    foreach ($kvp in $env.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($kvp.Name, $kvp.Value, [EnvironmentVariableTarget]::User)
    }

    if (-not (Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet)) {
        & "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile {
            Install-Module Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -AllowPrerelease -SkipPublisherCheck
        }
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
            'PSEverything',
            'Microsoft.PowerShell.SecretManagement',
            'Microsoft.PowerShell.SecretStore')

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
