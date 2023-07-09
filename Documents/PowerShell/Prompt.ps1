using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Runtime.InteropServices
using namespace System.Security.Principal
using namespace System.Text

$global:nf_fae_comet = [char]0xE26D;
$global:nf_mdi_arrange_bring_forward = [char]0xF53C;
$global:nf_fa_folder_open_o = [char]0xF115;
$global:nf_mdi_subdirectory_arrow_right = [char]0xFB0C;

if (-not $psEditor) {
    if ($PWD.ProviderPath -eq $PSHome) {
        Set-Location $HOME
    }
}

class EscapeColor {
    [string] $Background;
    [string] $Foreground;
}

class GradientFactory {
    hidden GradientFactory() { }

    # Why not make everything static? Because I hate needing to use the type name for
    # methods inside the same class.
    static [EscapeColor[]] GetGradient([string] $start, [string] $end, [int] $count) {
        return [GradientFactory]::new().GetGradientImpl($start, $end, $count)
    }

    [EscapeColor[]] GetGradientImpl([string] $start, [string] $end, [int] $count) {
        switch ($count) {
            0 { return [EscapeColor[]]::new(0) }
            1 { return $start }
            2 { return $start, $end }
        }

        if ($count -lt 0) {
            throw [ArgumentOutOfRangeException]::new('count')
        }

        if ([string]::IsNullOrEmpty($start)) {
            throw [ArgumentNullException]::new('start')
        }

        if ([string]::IsNullOrEmpty($end)) {
            throw [ArgumentNullException]::new('end')
        }

        $startRgb = $this.ToRGB($start)
        $endRgb = $this.ToRGB($end)

        $result = [EscapeColor[]]::new($count)
        $result[0] = $this.ToEscape($startRgb[0], $startRgb[1], $startRgb[2])

        $stepCount = $count - 2
        $steps = [int[]]::new(3)

        for ($i = 0; $i -lt $startRgb.Length; $i++) {
            $steps[$i] = ($endRgb[$i] - $startRgb[$i]) / ($stepCount + 1)
        }

        $current = $startRgb.Clone()
        for ($i = 0; $i -lt $stepCount; $i++) {
            for ($j = 0; $j -lt $current.Length; $j++) {
                $current[$j] += $steps[$j]
            }

            $result[$i + 1] = $this.ToEscape($current[0], $current[1], $current[2])
        }

        $result[-1] = $this.ToEscape($endRgb[0], $endRgb[1], $endRgb[2])
        return $result
    }

    [EscapeColor] ToEscape([int] $red, [int] $green, [int] $blue) {
        $colors = "$red;$green;$blue"
        $e = [char]0x1b

        return [EscapeColor]@{
            Foreground = "$e[38;2;${colors}m"
            Background = "$e[48;2;${colors}m"
        }
    }

    [int[]] ToRGB([string] $hex) {
        if ([string]::IsNullOrEmpty($hex)) {
            throw [ArgumentNullException]::new('hex')
        }

        if ($hex[0] -ne '#') {
            throw [ArgumentException]::new(
                'Argument must be a hex color.',
                'hex')
        }

        $hex = $hex.Substring(1, $hex.Length - 1).PadLeft(6, '0')
        $rString = $hex.Substring(0, 2)
        $gString = $hex.Substring(2, 2)
        $bString = $hex.Substring(4, 2)

        $r, $g, $b = 0
        $hexStyle = [System.Globalization.NumberStyles]::HexNumber
        $culture = [cultureinfo]::InvariantCulture
        $success = [int]::TryParse($rString, $hexStyle, $culture, [ref] $r)
        if ($success) {
            $success = [int]::TryParse($gString, $hexStyle, $culture, [ref] $g)
        }

        if ($success) {
            $success = [int]::TryParse($bString, $hexStyle, $culture, [ref] $b)
        }

        if (-not $success) {
            throw [ArgumentException]::new(
                'Invalid hex color specified.',
                'hex')
        }

        return $r, $g, $b
    }
}

class PromptBuilder {
    hidden static [PromptBuilder] $s_instance;
    hidden static [bool] $s_isElevated;
    hidden static [string] $s_reset;
    hidden static [EscapeColor[][]] $s_gradientMap;

    hidden static [char] $nf_pl_left_hard_divider = 0xE0B0;

    [StringBuilder] $Builder;

    hidden [int] $_i;
    hidden [scriptblock[]] $_blocks;
    hidden [InvocationInfo] $_invocationInfo;
    hidden [List[psvariable]] $_variables;
    hidden [string] $_startColor;
    hidden [string] $_endColor;
    hidden [List[int]] $_offsets;

    static PromptBuilder() {
        [PromptBuilder]::s_gradientMap = [EscapeColor[][]]::new(0x100)
        [PromptBuilder]::s_reset = "$([char]27)[0m"
        if ([RuntimeInformation]::IsOSPlatform([OSPlatform]::Windows)) {
            [PromptBuilder]::s_isElevated = [WindowsIdentity]::GetCurrent().Owner.IsWellKnown(
                [WellKnownSidType]::BuiltinAdministratorsSid)
        }

        [PromptBuilder]::s_instance = [PromptBuilder]::new()
    }

    hidden PromptBuilder() {
        $this.Builder = [StringBuilder]::new()
        $this._variables = [List[psvariable]]::new()
        $this._variables.Add([psvariable]::new('this', $this))
        $this._offsets = [List[int]]::new()

        if ([PromptBuilder]::s_isElevated) {
            $this._startColor = '#FE0000'
            $this._endColor = '#3B0000'
        } else {
            $this._startColor = '#009600'
            $this._endColor = '#005000'
        }
    }

    [EscapeColor[]] GetGradient([int] $count) {
        $map = $this::s_gradientMap
        if ($map.Length -le $count) {
            $newLength = [Math]::Max($count + 1, $map.Length * 2)
            $newMap = [EscapeColor[][]]::new($newLength)
            [Array]::Copy($map, $newMap, $map.Length)
            $this::s_gradientMap = $map = $newMap
        }

        $result = $this::s_gradientMap[$count]
        if ($null -ne $result) {
            return $result
        }

        $result = [GradientFactory]::GetGradient($this._startColor, $this._endColor, $count)
        return $map[$count] = $result
    }

    [string] GetBGColor([EscapeColor[]] $gradient, [int] $index) {
        return $this.GetColor($gradient, $index, $true)
    }

    [string] GetFGColor([EscapeColor[]] $gradient, [int] $index) {
        return $this.GetColor($gradient, $index, $false)
    }

    [string] GetColor([EscapeColor[]] $gradient, [int] $index, [bool] $isBackground) {
        if ($isBackground) {
            return $gradient[$index].Background
        }

        return $gradient[$index].Foreground
    }

    [string] CreatePrompt(
        [InvocationInfo] $invocationInfo,
        [List[scriptblock]] $blocks)
    {
        $this._blocks = $blocks
        $this._invocationInfo = $invocationInfo;
        $this.Builder.Clear()

        $this._offsets.Clear()
        for ($i = 0; $i -lt $this._blocks.Length; $i++) {
            $this._i = $i
            $oldLength = $this.Builder.Length
            $this._blocks[$i].InvokeWithContext(
                @{},
                $this._variables,
                @())

            if ($this.Builder.Length -ne $oldLength -and $i -lt $this._blocks.Length - 1) {
                $this._offsets.Add($this.Builder.Length)
            }
        }

        $gradient = $this.GetGradient($this._offsets.Count + 1)
        for ($i = $this._offsets.Count - 1; $i -ge 0; $i--) {
            $current = $this._offsets[$i]
            $this.Builder.
                Insert($current, $this.GetBGColor($gradient, $i + 1)).
                Insert($current, $this::s_reset).
                Insert($current, $this::nf_pl_left_hard_divider).
                Insert($current, $this.GetBGColor($gradient, $i + 1)).
                Insert($current, $this.GetFGColor($gradient, $i))
        }

        return $this.Builder.
            Insert(0, $this.GetBGColor($gradient, 0)).
            Append($this::s_reset).
            Append($this.GetFGColor($gradient, $gradient.Length - 1)).
            Append($this::nf_pl_left_hard_divider).
            Append($this::s_reset).
            ToString()
    }
}

# Each script block here is a "block" in the prompt.  $this.Builder points to a StringBuilder
# instance.  Using StringBuilder instead of lots of strings helps reduce pressure on the GC,
# saving some CPU and memory.
$global:__default_prompt = $global:Prompt = $Prompt = [List[scriptblock]](
    {
        $this.Builder.
            Append(' ').
            Append($nf_mdi_subdirectory_arrow_right).
            Append($this._invocationInfo.HistoryId)
    },
    {
        if ($stackCount = $ExecutionContext.SessionState.Path.LocationStack("").Count) {
            $this.Builder.Append($nf_fa_folder_open_o).Append($stackCount)
        }
    },
    {
        if ($NestedPromptLevel) {
            $this.Builder.
                Append($nf_mdi_arrange_bring_forward).
                Append([string]$NestedPromptLevel)
        }
    },
    { $this.Builder.Append($nf_fae_comet).Append((Get-Runspace).Count) },
    {
        $pathIntrinsics = $ExecutionContext.SessionState.Path
        $location = $pathIntrinsics.CurrentLocation
        if ($location.ProviderPath -eq $env:USERPROFILE) {
            $this.Builder.Append('~')
            return
        }

        if ([string]::IsNullOrEmpty($location.ProviderPath)) {
            $this.Builder.Append($location.Provider.Name)
            return
        }

        $fullyQualifiedPath = $location.Provider.ToString() + '::' + $location.ProviderPath
        $this.Builder.Append($pathIntrinsics.ParseChildName($fullyQualifiedPath))
    })

if ($psEditor) {
    $null = $Prompt.Insert(0, { $this.Builder.Append($PID) })
}

function global:prompt {
    $promptBuilder = [PromptBuilder]::s_instance
    $sb = [StringBuilder]::new(
        # PowerShell
        10 +
        # Spaces and dashes
        6 +
        # Guess at provider path length
        30)

    # Change title to (!)(Win|Dev )PowerShell - {PID} - {CurrentLocation}
    $null = & {
        if ($promptBuilder::s_isElevated) {
            $sb.Append('!')
        }

        if (-not $IsCoreClr) {
            $sb.Append('Win ')
        }

        if ($PSVersionTable.PSVersion.PreReleaseLabel -eq 'preview.99') {
            $sb.Append('Dev ')
        }

        $sb.Append('PowerShell')
        $sb.Append(' - ').Append($PID).Append(' - ').Append($PWD.ProviderPath)
    }

    $Host.UI.RawUI.WindowTitle = $sb.ToString()

    $blocks = $global:Prompt
    if ($null -eq $blocks) {
        $blocks = $global:__default_prompt
    }

    $promptString = $promptBuilder.CreatePrompt($MyInvocation, $blocks)

    if ($global:PSRL_INSERT_MODE) {
        [Console]::Write($global:PSRL_INSERT_MODE)
    }

    # Set-PSReadLineOption -PromptText $promptString
    return $promptString
}
