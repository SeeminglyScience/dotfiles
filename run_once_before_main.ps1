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
    MaybeInstallScoopApp bat
    MaybeInstallScoopApp less
    MaybeInstallScoopApp gh
    MaybeInstallScoopApp gpg
    MaybeInstallScoopApp 7zip 7z

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
            'ThreadJob')

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
