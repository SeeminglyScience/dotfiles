using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$psps = @{
    OwnerName = 'PowerShell'
    RepositoryName = 'PowerShell'
}

if (-not $env:PWSH_STORE) {
    $env:PWSH_STORE = 'C:\pwsh'
}

$removeAssetTypePattern = '-(x86|fxdependent(WinDesktop)?)$'

$shGetKnownFolderPathJob = InitAsync {
    Add-Type -CompilerOptions '-unsafe' -TypeDefinition '
        using System.Runtime.InteropServices;
        using System.Runtime.CompilerServices;
        using System;

        public unsafe class ISPInterop
        {
            [DllImport("shell32")]
            private static extern int SHGetKnownFolderPath(
                Guid* rfid,
                uint dwFlags,
                nint hHandle,
                char** ppszPath);

            private static readonly Guid RFID_LocalDownloads = new("7d83ee9b-2244-4e70-b1f5-5393042af1e4");

            public static string GetDownloadsFolder()
            {
                char* path = null;
                try
                {
                    int hr = SHGetKnownFolderPath(
                        (Guid*)Unsafe.AsPointer(ref Unsafe.AsRef(in RFID_LocalDownloads)),
                        dwFlags: /* KF_FLAG_DONT_VERIFY */ 16384,
                        hHandle: 0,
                        &path);

                    Marshal.ThrowExceptionForHR(hr);

                    return new string(path);
                }
                finally
                {
                    if (path is not null)
                    {
                        Marshal.FreeCoTaskMem(new IntPtr(path));
                    }
                }
            }
        }'
}

function NoProp {
    [CmdletBinding()]
    param([scriptblock] $Action)
    end {
        $WhatIfPreference = $false
        $ConfirmPreference = 'None'
        & $Action
    }
}

function GetTag {
    param(
        [string] $MajorAndMinor,

        [string] $Build,

        [string] $Preview,

        [string] $Rc,

        [switch] $ForInstall
    )
    end {
        if (-not ($Build -or $Preview -or $Rc)) {
            $splat = @{ }
            if ($MajorAndMinor) {
                $splat['MajorAndMinor'] = $MajorAndMinor
            }

            if ($ForInstall) {
                return (Find-Pwsh -Latest @splat).Tag
            }

            return (Get-Pwsh -Latest @splat).Tag
        }

        if ($Preview) {
            return "v$MajorAndMinor.0-preview.$Preview"
        }

        if ($Rc) {
            return "v$MajorAndMinor.0-rc.$Rc"
        }

        return "v$MajorAndMinor.$Build"
    }
}

function NewPwshVersionInfo {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('tag_name')]
        [string] $Tag
    )
    process {
        $null, $main, $pre, $null = $Tag -split '^v|-'
        $version = $main -as [version]
        $major = $version.Major
        $minor = $version.Minor
        $build = $version.Build

        $leaf = $pre ? $pre : $build

        $basePath = Join-Path $env:PWSH_STORE "$major.$minor" $leaf
        $vlessTag = $Tag -replace '^v'
        return [pscustomobject]@{
            PSTypeName = 'Utility.PwshVersionInfo'
            Version = $version
            PreReleaseTag = $pre
            Path = $basePath
            Tag = $Tag -replace $removeAssetTypePattern
            AssetNames = [pscustomobject]@{
                Zip = "PowerShell-$vlessTag-win-x64.zip"
                ZipX86 = "PowerShell-$vlessTag-win-x86.zip"
                FxDependent = "PowerShell-$vlessTag-win-fxdependent.zip"
                FxDependentWinDesktop = "PowerShell-$vlessTag-win-fxdependentWinDesktop.zip"
                Msi = "PowerShell-$vlessTag-win-x64.msi"
                MsiX86 = "PowerShell-$vlessTag-win-x86.msi"
            }
        }
    }
}

function Get-Pwsh {
    [Alias('gpwsh')]
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Partial')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $MajorAndMinor,

        [Parameter(Position = 1, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $Build,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('p')]
        [ValidateNotNullOrEmpty()]
        [string] $Preview,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('r')]
        [ValidateNotNullOrEmpty()]
        [string] $Rc,

        [Parameter(ParameterSetName = 'Tag')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [Alias('t', 'tag_name')]
        [string] $Tag,

        [Parameter(ParameterSetName = 'Partial')]
        [switch] $Latest,

        [Parameter(ParameterSetName = 'Partial')]
        [switch] $LatestStable
    )
    begin {
        function PathToTag {
            param([Parameter(ValueFromPipeline)] [string] $Path)
            process {
                $relative = $PSCmdlet.SessionState.Path.NormalizeRelativePath(
                    $Path,
                    $env:PWSH_STORE)

                $majorAndMinor = [IO.Path]::GetDirectoryName($relative)
                $leaf = [IO.Path]::GetFileName($relative) -replace $removeAssetTypePattern
                if (-not $leaf) {
                    throw 'Unreachable hopefully'
                }

                $isPreRelease = $leaf.StartsWith('preview.') -or $leaf.StartsWith('rc.')
                if ($isPreRelease) {
                    return "v$majorAndMinor.0-$leaf"
                }

                return "v$majorAndMinor.$leaf"
            }
        }

        function PathToInfo {
            param([Parameter(ValueFromPipeline)] [string] $Path)
            process {
                $tag = PathToTag $Path
                $versionInfo = NewPwshVersionInfo $tag
                $isX86 = $Path.EndsWith('x86')
                $isfxDependent = $Path.EndsWith('-fxdependent', [System.StringComparison]::OrdinalIgnoreCase)
                $isWinDesktop = $Path.EndsWith('-fxdependentWinDesktop', [System.StringComparison]::OrdinalIgnoreCase)
                $versionInfo.psobject.Properties.Add(
                    [psnoteproperty]::new('X86', $isX86))

                $versionInfo.psobject.Properties.Add(
                    [psnoteproperty]::new('FxDependent', $isfxDependent -or $isWinDesktop))

                $versionInfo.psobject.Properties.Add(
                    [psnoteproperty]::new('FxDependentWinDesktop', $isWinDesktop))

                $versionInfo.pstypenames.Insert(0, 'Utility.PwshPathVersionInfo')

                return $versionInfo
            }
        }

        function GetAllVersions {
            end {
                foreach ($mam in [System.IO.Directory]::EnumerateDirectories($env:PWSH_STORE)) {
                    $version = $null
                    $dirName = [System.IO.Path]::GetFileName($mam)
                    if (-not [version]::TryParse($dirName, [ref] $version)) {
                        continue
                    }

                    if (-not ($version.Build -eq -1 -and $version.Revision -eq -1)) {
                        continue
                    }

                    $majorAndMinor = $version.ToString()
                    foreach ($leaf in [System.IO.Directory]::EnumerateDirectories($mam)) {
                        # yield
                        PathToInfo $leaf
                    }
                }
            }
        }
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'Tag') {
            if ($Tag -match 'v(?<MajorAndMinor>\d+\.\d+)\.(?<Build>\d+)(-(?<PreTag>(rc\.|preview\.))(?<PreviewNumber>\d+)))?') {
                $MajorAndMinor = $matches['MajorAndMinor']
                $Build = $matches['Build']
                if ($matches['PreTag']) {
                    $number = $matches['PreviewNumber']
                    if ($matches['PreTag'] -eq 'rc.') {
                        $Rc = $number
                    } else {
                        $Preview = $number
                    }
                }
            } else {
                return GetAllVersions | Where-Object Tag -Like $Tag
            }
        }

        if (-not $MajorAndMinor) {
            if ($Latest) {
                return GetAllVersions | SortPwshVersion | Select-Object -First 1
            }

            if ($LatestStable) {
                return GetAllVersions | Where-Object -Not PreReleaseTag | SortPwshVersion | Select-Object -First 1
            }

            return GetAllVersions
        }

        if (-not ($Preview -or $Rc -or $Build)) {
            if ($Latest) {
                return Get-Pwsh -MajorAndMinor $MajorAndMinor | SortPwshVersion | Select-Object -First 1
            }

            if ($LatestStable) {
                return Get-Pwsh -MajorAndMinor $MajorAndMinor | Where-Object -Not PreReleaseTag | SortPwshVersion | Select-Object -First 1
            }

            foreach ($leaf in [System.IO.Directory]::EnumerateDirectories((Join-Path $env:PWSH_STORE $MajorAndMinor))) {
                # yield
                PathToInfo $leaf
            }

            return
        }

        if ($Preview) {
            $leaf = "0.-preview.$Preview"
        } elseif ($Rc) {
            $leaf = "0.-rc.$Rc"
        } else {
            $leaf = ".$Build"
        }

        $result = Join-Path $env:PWSH_STORE $MajorAndMinor $leaf
        if (-not (Test-Path $result)) {
            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    [ItemNotFoundException]::new("The pwsh version 'v${MajorAndMinor}${leaf}' is not installed."),
                    'PwshVersionNotFound',
                    [ErrorCategory]::ObjectNotFound,
                    $PSBoundParameters))
            return
        }

        PathToInfo $result
    }
}

function SortPwshVersion {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $params = @{
            Property = 'Version',
                {
                    if (-not $_.PreReleaseTag) {
                        return [int]::MaxValue
                    }

                    $isRc = $_.PreReleaseTag.StartsWith('rc.')
                    $isPreview = $_.PreReleaseTag.StartsWith('preview.')
                    $number = [int]($_.PreReleaseTag -replace '^rc\.|^preview\.')
                    if ($isRc) {
                        $number += 1000
                    }

                    return $number
                },
                {
                    if ($_.X86) {
                        return -100
                    }

                    if ($_.FxDependentWinDesktop) {
                        return -10000
                    }

                    if ($_.FxDependent) {
                        return -1000
                    }

                    return 0
                }
        }

        $pipe = { Sort-Object @params -Descending }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($PSCmdlet)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function Find-Pwsh {
    [Alias('fip')]
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Partial')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $MajorAndMinor,

        [Parameter(Position = 1, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $Build,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('p')]
        [ValidateNotNullOrEmpty()]
        [string] $Preview,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('r')]
        [ValidateNotNullOrEmpty()]
        [string] $Rc,

        [Parameter(ParameterSetName = 'Tag')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [Alias('t', 'tag_name')]
        [string] $Tag,

        [Parameter(ParameterSetName = 'Partial')]
        [switch] $Latest,

        [Parameter(ParameterSetName = 'Partial')]
        [switch] $LatestStable
    )
    end {
        if ($PSCmdlet.ParameterSetName -eq 'Partial') {
            if (-not $MajorAndMinor) {
                if ($LatestStable) {
                    return Get-GitHubRelease @psps -Latest | NewPwshVersionInfo
                }

                if ($Latest) {
                    return Find-Pwsh |
                        Select-Object -First 10 |
                        SortPwshVersion |
                        Select-Object -First 1
                }

                return Get-GitHubRelease @psps | NewPwshVersionInfo
            }

            if (-not ($Build -or $Preview -or $Rc)) {
                $Tag = "v$MajorAndMinor*"
            } else {
                $Tag = GetTag -MajorAndMinor $MajorAndMinor -Build $Build -Preview $Preview -Rc $Rc
            }
        }

        if ($Tag -and -not [WildcardPattern]::ContainsWildcardCharacters($Tag)) {
            try {
                return Get-GitHubRelease @psps -Tag $Tag -ErrorAction Stop | NewPwshVersionInfo
            } catch {
                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        <# exception: #> [ItemNotFoundException]::new("Release tag '$Tag' not found."),
                        <# errorId: #> 'CouldNotFindRelease',
                        <# errorCategory: #> [ErrorCategory]::ObjectNotFound,
                        <# targetObject: #> $Tag))
            }
        }

        if (-not $Tag) {
            if ($Latest) {
                return Get-GitHubRelease @psps | NewPwshVersionInfo | Select-Object -First 1
            }

            return Get-GitHubRelease @psps | NewPwshVersionInfo
        }

        if ($Latest) {
            return Get-GitHubRelease @psps |
                Where-Object tag_name -like $Tag |
                NewPwshVersionInfo |
                Select-Object -First 1
        }

        return Get-GitHubRelease @psps | Where-Object tag_name -like $Tag | NewPwshVersionInfo
    }
}

function Enter-Pwsh {
    [Alias('etp')]
    [CmdletBinding(SupportsShouldProcess, PositionalBinding = $false, DefaultParameterSetName = 'Partial')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $MajorAndMinor,

        [Parameter(Position = 1, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $Build,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('p')]
        [ValidateNotNullOrEmpty()]
        [string] $Preview,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('r')]
        [ValidateNotNullOrEmpty()]
        [string] $Rc,

        [Parameter(ParameterSetName = 'Tag', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [Alias('t', 'tag_name')]
        [string] $Tag,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch] $X86,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch] $FxDependent,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch] $WinDesktop,

        [Parameter(ValueFromRemainingArguments)]
        [string[]] $AdditionalArguments
    )
    end {
        if ($PSCmdlet.ParameterSetName -eq 'Partial') {
            $Tag = GetTag -MajorAndMinor $MajorAndMinor -Build $Build -Preview $Preview -Rc $Rc
        }

        $versionInfo = NewPwshVersionInfo $Tag
        $basePath = $versionInfo.Path
        if ($X86) {
            $basePath += '-x86'
        } elseif ($WinDesktop) {
            $basePath += '-fxdependentWinDesktop'
        } elseif ($FxDependent) {
            $basePath += '-fxdependent'
        }

        & { & "$basePath\pwsh.exe" @AdditionalArguments } | Out-Default
    }
}

function Install-Pwsh {
    [Alias('isp')]
    [CmdletBinding(SupportsShouldProcess, PositionalBinding = $false, DefaultParameterSetName = 'Partial')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $MajorAndMinor,

        [Parameter(Position = 1, ParameterSetName = 'Partial')]
        [ValidateNotNullOrEmpty()]
        [string] $Build,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('p')]
        [ValidateNotNullOrEmpty()]
        [string] $Preview,

        [Parameter(ParameterSetName = 'Partial')]
        [Alias('r')]
        [ValidateNotNullOrEmpty()]
        [string] $Rc,

        [Parameter(ParameterSetName = 'Tag', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [Alias('t', 'tag_name')]
        [string] $Tag,

        [switch] $X86,

        [switch] $FxDependent,

        [switch] $WinDesktop,

        [switch] $UseMsi,

        [Parameter()]
        [Alias('Force', 'f')]
        [switch] $Overwrite
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Partial') {
            $Tag = GetTag -MajorAndMinor $MajorAndMinor -Build $Build -Preview $Preview -Rc $Rc -ForInstall
        }

        $stop = @{
            ErrorAction = [ActionPreference]::Stop
        }

        $foundVersions = $null
        try {
            $foundVersions = Find-Pwsh -Tag $Tag -ErrorAction Stop
        } catch {
            $PSCmdlet.WriteError($PSItem)
            return
        }

        if ($UseMsi) {
            $target = $foundVersions | Select-Object -First 1
            $targetAsset = $target.AssetNames.Msi
            if ($X86) {
                $targetAsset = $target.AssetNames.MsiX86
            }

            $uri = "https://github.com/PowerShell/PowerShell/releases/download/$($target.Tag)/$targetAsset"
            WaitAsync ([ref] $shGetKnownFolderPathJob)
            $downloadsFolder = [ISPInterop]::GetDownloadsFolder()
            $destinationPath = Join-Path $downloadsFolder -ChildPath $targetAsset
            if (Test-Path -LiteralPath $destinationPath) {
                if (-not ($Overwrite -or $PSCmdlet.ShouldContinue("Overwrite $destinationPath"))) {
                    return
                }

                Remove-Item -LiteralPath $destinationPath
            }

            Invoke-WebRequest $uri -OutFile $destinationPath @stop
            Start-Process $destinationPath
            return
        }

        foreach ($version in $foundVersions) {
            $targetAsset = $version.AssetNames.Zip
            $basePath = $version.Path
            if ($X86) {
                $basePath += '-x86'
                $targetAsset = $version.AssetNames.ZipX86
            } elseif ($FxDependent) {
                $basePath += '-fxdependent'
                $targetAsset = $version.AssetNames.FxDependent
            } elseif ($WinDesktop) {
                $basePath += '-fxdependentWinDesktop'
                $targetAsset = $version.AssetNames.FxDependentWinDesktop
            }

            if (Test-Path $basePath) {
                if (-not ($Overwrite -or $PSCmdlet.ShouldContinue("The path '$basePath' already exists, would you like to continue?", 'Confirm'))) {
                    continue
                }
            } else {
                if ($PSCmdlet.ShouldProcess($basePath, 'NewDirectory')) {
                    NoProp { New-Item $basePath -ItemType Directory @stop | Out-Null }
                }
            }

            $uri = "https://github.com/PowerShell/PowerShell/releases/download/$($version.Tag)/$targetAsset"
            try {
                $providerPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath("Temp:\$targetAsset")
                if ($PSCmdlet.ShouldProcess("$uri -> Temp:\$targetAsset", 'Download')) {
                    NoProp { Invoke-WebRequest $uri -OutFile $providerPath @stop }
                }

                if ($PSCmdlet.ShouldProcess("Temp:\$targetAsset -> $basePath", 'ExpandArchive')) {
                    NoProp { Expand-Archive -Path $providerPath -DestinationPath $basePath -Force @stop }
                }
            } catch {
                Write-Error -ErrorRecord $PSItem
            } finally {
                if (Test-Path Temp:\$targetAsset) {
                    if ($PSCmdlet.ShouldProcess("Temp:\$targetAsset", 'RemoveItem')) {
                        NoProp { Remove-Item Temp:\$targetAsset @stop }
                    }
                }
            }
        }
    }
}

class PwshInstallCompletionHelper {
    static [IEnumerable[CompletionResult]] CompleteArgument([object[]] $argumentList, [bool] $forInstall) {
        return [PwshInstallCompletionHelper]::CompleteArgument(
            $argumentList[0],
            $argumentList[1],
            $argumentList[2],
            $argumentList[3],
            $argumentList[4],
            $forInstall)
    }

    static [IEnumerable[CompletionResult]] CompleteArgument([IDictionary] $boundParameters, [bool] $forInstall) {
        return [PwshInstallCompletionHelper]::CompleteArgument(
            $boundParameters['commandName'],
            $boundParameters['parameterName'],
            $boundParameters['wordToComplete'],
            $boundParameters['commandAst'],
            $boundParameters['fakeBoundParameters'],
            $forInstall)
    }

    static [CompletionResult[]] CompleteArgument(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $fakeBoundParameters,
        [bool] $forInstall)
    {
        $params = @{ }
        $paramNames = (
            'MajorAndMinor',
            'Rc',
            'Preview',
            'Build',
            'X86',
            'FxDependent',
            'WinDesktop')

        foreach ($paramName in $paramNames) {
            if ($paramName -eq $parameterName) {
                continue
            }

            if ($forInstall -and $paramName -in 'X86', 'FxDependent', 'WinDesktop') {
                continue
            }

            if ($fakeBoundParameters.ContainsKey($paramName)) {
                $params[$paramName] = $fakeBoundParameters[$paramName]
            }
        }

        $valueGetter = switch ($parameterName) {
            'Rc' { { $_.PreReleaseTag?.StartsWith('rc.') ? $_.PreReleaseTag.Substring(3) : $null }; break }
            'Preview' { { $_.PreReleaseTag?.StartsWith('preview.') ? $_.PreReleaseTag.Substring(8) : $null }; break }
            'Build' { { $_.PreReleaseTag ? $null : $_.Version.Build }; break }
            'MajorAndMinor' { { '{0}.{1}' -f $_.Version.Major, $_.Version.Minor }; break }
        }

        $command = 'Get-Pwsh'
        if ($forInstall) {
            $command = {
                $cache = $script:FindPwshCache
                if ($cache) {
                    return $cache
                }

                return $script:FindPwshCache = Find-Pwsh
            }
        }

        $results = & $command @params | SortPwshVersion | & { process {
            try {
                $value = $valueGetter.InvokeWithContext(@{}, [psvariable]::new('_', $_))[0]
            } catch {
                return
            }

            if ($null -eq $value) {
                return
            }

            if ($value -notlike "$wordToComplete*") {
                return
            }

            return [CompletionResult]::new(
                $value,
                $value,
                [CompletionResultType]::ParameterValue,
                $PSItem.Tag)
        }}

        # if (-not $results) {
        #     return [CompletionResult]::new(' ')
        # }

        return $results
    }
}

foreach ($command in 'Get-Pwsh', 'Enter-Pwsh') {
    foreach ($param in 'MajorAndMinor', 'Build', 'Preview', 'Rc') {
        $registerArgumentCompleterSplat = @{
            CommandName = $command
            ParameterName = $param
            ScriptBlock = { [PwshInstallCompletionHelper]::CompleteArgument($args, $false) }
        }

        Register-ArgumentCompleter @registerArgumentCompleterSplat
    }
}

foreach ($command in 'Find-Pwsh', 'Install-Pwsh') {
    foreach ($param in 'MajorAndMinor', 'Build', 'Preview', 'Rc') {
        $registerArgumentCompleterSplat = @{
            CommandName = $command
            ParameterName = $param
            ScriptBlock = { [PwshInstallCompletionHelper]::CompleteArgument($args, $true) }
        }

        Register-ArgumentCompleter @registerArgumentCompleterSplat
    }
}
