# (Recommended items are referenced in some way in this profile)
# Recommend modules:
# - ClassExplorer
# - ImpliedReflection
# - EditorServicesCommandSuite
# - InvokeBuild

# Recommended choco packages:
# - dnSpy
# - bat
# - Neovim

$alias:w         = 'Where-Object'
$alias:f         = 'ForEach-Object'
$alias:s         = 'Select-Object'
$alias:m         = 'Measure-Object'
$alias:a         = 'Get-Assembly'
$alias:n         = 'New-Object'
$alias:new       = 'New-Object'
$alias:ib        = 'Invoke-Build'
$alias:apm       = 'Add-PrivateMember'
$alias:fit       = 'Find-Type'
$alias:fime      = 'Find-Member'
$alias:fins      = 'Find-Namespace'
$alias:gpa       = 'Get-Parameter'
$alias:os        = 'Out-String'
$alias:string    = 'Out-String'
$alias:vim       = 'nvim.exe'
${alias:vim.exe} = 'nvim.exe'

# Aliases from Utility.psm1
# number       = ConvertTo-Number
# base, base64 = ConvertTo-Base64String
# hex          = ConvertTo-HexString
# char         = ConvertTo-Char
# convert      = Convert-Object
# bits         = ConvertTo-BitString
# first, top   = Select-FirstObject
# last         = Select-LastObject
# at           = Select-ObjectIndex
# skip         = Skip-Object
# default      = Get-TypeDefaultValue
# nameof       = Get-ElementName
# cast         = ConvertTo-Array
# append       = Join-After
# prepend      = Join-Before
# e            = Get-BaseException
# se           = Show-Exception
# show         = Show-FullObject
# tostring     = ConvertTo-String
# await        = Wait-AsyncResult
# ??           = Invoke-Conditional
# code         = Invoke-VSCode
# ishim        = Install-Shim
# p            = Set-AndPass
# up           = Start-ElevatedSession
# sms          = Show-MemberSource
# emi          = Expand-MemberInfo
# pslambda     = Invoke-PSLambda

$env:HOMEDRIVE = $env:SystemDrive
$env:HOMEPATH = $env:USERPROFILE | Split-Path -NoQualifier

$__IsWindows =
    -not $PSVersionTable['PSEdition'] -or
    $PSVersionTable['PSEdition'] -eq 'Desktop' -or
    $PSVersionTable['Platform'] -eq 'Win32NT'

$__IsVSCode = $env:TERM_PROGRAM -eq 'vscode'

$__IsTerminal = [bool] $env:WS_SESSION

$__IsConHost = -not ($__IsVSCode -or $__IsTerminal)

# Run most of the profile (including other included files) in a new scope. I do this
# because dot sourcing makes it so the compiler cannot optimize variable lookups.
# This means we need to be more explicit about declaring things in the global scope,
# but it saved ~500ms with my profile size.
#
# An added bonus is that we can use "using namespace" statements in "included" files
# without polluting the global scope.
& {
    if ($__IsWindows -and -not $__IsVSCode) {
        & "$PSScriptRoot\SetConsoleFont.ps1" -Family 'FuraCode NF' -Size 20
    }

    if ($psEditor) {
        $escs = Import-Module EditorServicesCommandSuite -PassThru
        if ($null -ne $escs -and $escs.Version.Major -lt 0.5.0) {
            Import-EditorCommand -Module EditorServicesCommandSuite
        }
    }

    if ($ibac = Get-Command Invoke-Build.ArgumentCompleters.ps1 -ErrorAction Ignore -CommandType Script) {
        & $ibac
    }

    Import-Module DockerCompletion -ErrorAction Ignore

    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param(
            [string] $wordToComplete,
            [System.Management.Automation.Language.CommandAst] $commandAst,
            [int] $cursorPosition
        )
        end {
            dotnet.exe complete --position $cursorPosition $commandAst.Extent.Text | ForEach-Object {
                if ($PSItem -notlike "$wordToComplete*") {
                    return
                }

                $completionType = if ($PSItem.StartsWith('-')) {
                    [System.Management.Automation.CompletionResultType]::ParameterName
                } else {
                    [System.Management.Automation.CompletionResultType]::ParameterValue
                }

                [System.Management.Automation.CompletionResult]::new($PSItem, $PSItem, $completionType, $PSItem)
            }
        }
    }

    [System.Console]::ForegroundColor = [ConsoleColor]::Gray
    $Host.UI.RawUI.ForegroundColor = [ConsoleColor]::Gray
    if ($__IsVSCode) {
        # "Black" means default in VSCode for some reason.
        [Console]::BackgroundColor = [ConsoleColor]::Black
        $Host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
    } else {
        [System.Console]::BackgroundColor = [ConsoleColor]::DarkGray
        $Host.UI.RawUI.BackgroundColor = [ConsoleColor]::DarkGray
    }

    if ($null -ne $Host.PrivateData -and $Host.PrivateData.psobject.Properties['ErrorForegroundColor']) {
        $Host.PrivateData.ErrorForegroundColor = [ConsoleColor]::DarkCyan
    }

    Clear-Host

    if (Test-Path $PSScriptRoot/$env:USERDOMAIN.ps1) {
        & "$PSScriptRoot/$env:USERDOMAIN.ps1"
    }

    & $PSScriptRoot\PSReadLine.ps1
    & $PSScriptRoot\SetTypeCache.ps1

    # Editor intellisense should only care about using statements in the current file,
    # so don't enable namespace aware completion if we're in the integrated console.
    if (-not $psEditor) {
        & $PSScriptRoot\NamespaceAwareCompletion.ps1
    }

    & $PSScriptRoot\Prompt.ps1

    Update-TypeData -PrependPath "$PSScriptRoot\profile.types.ps1xml"
    Update-FormatData -PrependPath "$PSScriptRoot\profile.format.ps1xml"
    Import-Module -Global -Name ClassExplorer -ErrorAction Ignore
    Import-Module -Global -Name $PSScriptRoot\Utility.psm1
}
