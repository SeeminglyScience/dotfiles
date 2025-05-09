Set-StrictMode -Off
Import-Module Microsoft.PowerShell.Management -ErrorAction Ignore -WarningAction Ignore
Import-Module Microsoft.PowerShell.Utility -ErrorAction Ignore -WarningAction Ignore
try {
    Import-Module PSReadLine -ErrorAction Ignore
} catch {
}

$env:EDITOR = 'nvim'

$OutputEncoding =
    [Console]::OutputEncoding =
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new()

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
$alias:n         = 'New-Object'
$alias:new       = 'New-Object'
$alias:ib        = 'Invoke-Build'
$alias:os        = 'Out-String'
$alias:string    = 'Out-String'
$alias:vim       = 'nvim.exe'
${alias:vim.exe} = 'nvim.exe'
$alias:fms       = 'Format-MemberSignature'
$alias:eir       = 'Enable-ImpliedReflection'
$alias:dis       = 'Get-ScriptBlockDisassembly'
$alias:fet       = 'Format-ExpressionTree'
$alias:lib       = 'New-CtypesLib'
$alias:struct    = 'New-CtypesStruct'
$alias:fires     = 'Find-PSResource'
$alias:se        = 'Search-Everything'
$alias:spp       = 'Split-Path'
$alias:jp        = 'Join-Path'

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
if ($env:USERPROFILE) {
    $env:HOMEPATH = $env:USERPROFILE | Split-Path -NoQualifier
}

$__IsWindows =
    -not $PSVersionTable['PSEdition'] -or
    $PSVersionTable['PSEdition'] -eq 'Desktop' -or
    $PSVersionTable['Platform'] -eq 'Win32NT'

$__IsVSCode = $env:TERM_PROGRAM -eq 'vscode'

$__IsTerminal = [bool] $env:WT_SESSION

$__IsConHost = -not ($__IsVSCode -or $__IsTerminal)

$PSDefaultParameterValues['Find-Type:ResolutionMap'] = $PSDefaultParameterValues['Find-Member:ResolutionMap'] = @{
    anyspan = { [anyof[Span`1, ReadOnlySpan`1]] }
    anymemory = { [anyof[Memory`1, ReadOnlyMemory`1]] }
    anyspanormemory = { [anyof[anyspan, anymemory]] }
    anytask = { [anyof[System.Threading.Tasks.Task, System.Threading.Tasks.Task`1, System.Threading.Tasks.ValueTask, System.Threading.Tasks.ValueTask`1]] }
    anyvoidtask = { [allof[anytask, not[any[any]]]] }
}

# Run most of the profile (including other included files) in a new scope. I do this
# because dot sourcing makes it so the compiler cannot optimize variable lookups.
# This means we need to be more explicit about declaring things in the global scope,
# but it saved ~500ms with my profile size.
#
# An added bonus is that we can use "using namespace" statements in "included" files
# without polluting the global scope.
& {
    # Was testing transcripts. Switch the false to true if needed again
    if ($false -and $global:psEditor -and $PSVersionTable.PSVersion.Major -eq 5) {
        $transcripts = "$env:USERPROFILE/.transcripts"
        if (-not (Test-Path -LiteralPath $transcripts)) {
            $null = New-Item $transcripts -ItemType Directory
        }

        $file = 'transcript-{0:yyyy-MM-ddTHH-mm-ss}.log' -f (Get-Date)
        Start-Transcript -LiteralPath $transcripts/$file
    }

    if ($__IsWindows -and $__IsConHost) {
        & "$PSScriptRoot\SetConsoleFont.ps1" -Family 'CaskaydiaCove NF' -Size 20
    }

    if ($global:psEditor -and -not $env:DEVELOPING_ESCS) {
        Import-CommandSuite
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

    & "$PSScriptRoot\gh.Completer.ps1"

    [System.Console]::ForegroundColor = [ConsoleColor]::Gray
    $Host.UI.RawUI.ForegroundColor = [ConsoleColor]::Gray
    if ($__IsVSCode) {
        # "Black" means default in VSCode for some reason.
        [Console]::BackgroundColor = [ConsoleColor]::Black
        $Host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
    } elseif (-not $__IsTerminal) {
        [System.Console]::BackgroundColor = [ConsoleColor]::DarkGray
        $Host.UI.RawUI.BackgroundColor = [ConsoleColor]::DarkGray
    }

    if ($null -ne $Host.PrivateData -and $Host.PrivateData.psobject.Properties['ErrorForegroundColor']) {
        $Host.PrivateData.ErrorForegroundColor = [ConsoleColor]::DarkCyan
    }

    if (-not $__IsTerminal) {
        Clear-Host
    }

    if (Test-Path $PSScriptRoot/$env:USERDOMAIN.ps1) {
        & "$PSScriptRoot/$env:USERDOMAIN.ps1"
    }

    & $PSScriptRoot\PSReadLine.ps1
    & $PSScriptRoot\SetTypeCache.ps1

    if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 5 -and $IsWindows) {
        & $PSScriptRoot\CompletionExtensions.ps1
        # & $PSScriptRoot\LinqETS.ps1

        $mostRecent = Get-ChildItem -File -LiteralPath $PSScriptRoot/Profile/src/Profile -Include *.cs, *.csproj |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 |
            Select-Object -ExpandProperty LastWriteTime

        $compiledMarkerPath = Join-Path $PSScriptRoot Profile/out/lastcompiled.txt
        $shouldCompile = $false
        if (-not (Test-Path -LiteralPath $compiledMarkerPath)) {
            $shouldCompile = $true
        } elseif ($mostRecent -gt ([datetime](Get-Content -LiteralPath $compiledMarkerPath -Raw).Trim())) {
            $shouldCompile = $true
        }

        $configuration = 'Release'
        if ($env:DEBUG_PROFILE_CSPROJ) {
            $configuration = 'Debug'
            $shouldCompile = $true
        }

        if ($shouldCompile) {
            dotnet publish $PSScriptRoot/Profile/src/Profile/Profile.csproj --configuration $configuration --output $PSScriptRoot/Profile/out --nologo
            if (-not $LASTEXITCODE) {
                Set-Content -LiteralPath $compiledMarkerPath -Value (Get-Date)
            }
        }

        $peStream = $pdbStream = $null
        try {
            $peStream = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot Profile/out/Profile.dll))
            $pdbStream = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot Profile/out/Profile.pdb))

            $loadedAssembly = [System.Runtime.Loader.AssemblyLoadContext]::Default.LoadFromStream(
                $peStream,
                $pdbStream)

            Import-Module -Global -Assembly $loadedAssembly

        } finally {
            if ($pdbStream -is [System.IDisposable]) {
                ([System.IDisposable]$pdbStream).Dispose()
            }

            if ($peStream -is [System.IDisposable]) {
                ([System.IDisposable]$peStream).Dispose()
            }
        }
    }

    if ($psEditor) {
        & "$PSScriptRoot\EditorCommands.ps1"
    }

    & $PSScriptRoot\Prompt.ps1
    Update-TypeData -PrependPath "$PSScriptRoot\profile.types.ps1xml"
    Update-FormatData -PrependPath "$PSScriptRoot\profile.format.ps1xml"

    if ($PWD.ProviderPath -and ($PWD.ProviderPath | Split-Path -Leaf) -ne 'ClassExplorer') {
        Import-Module -Global -Name ClassExplorer -ErrorAction Ignore
    }

    Import-Module -Global -Name $PSScriptRoot\Utility.psm1 -DisableNameChecking
    $chocoPsm1Path = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path $chocoPsm1Path) {
        Import-Module -Global $chocoPsm1Path
    }
}

if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 3) {
    . "$PSScriptRoot\VT.ps1"
}
