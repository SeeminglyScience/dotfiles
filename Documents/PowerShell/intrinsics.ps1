using namespace System.Text.RegularExpressions

$script:s_intrinsicsInitialized = $false
$script:s_intrinsics = $null
$script:s_intrinsicsDocs = $null

function EnsureIntrinsicsInitialized {
    end {
        if ($script:s_intrinsicsInitialized) {
            return
        }

        $splat = @{
            MemberType = 'ScriptMethod'
            MemberName = 'ToString'
            Value = { $this.Name }
            Force = $true
        }

        Update-TypeData -TypeName 'Deserialized.IntrinsicInfo.Raw' @splat
        Update-TypeData -TypeName 'Deserialized.IntrinsicInfo.Method' @splat
        Update-TypeData -TypeName 'Deserialized.IntrinsicInfo.Friendly' @splat

        $splat = @{
            TypeName = 'Deserialized.IntrinsicInfo.Intrinsic'
            DefaultDisplayPropertySet = 'Group', 'Method', 'Raw', 'Description'
            Force = $true
        }

        Update-TypeData @splat

        Update-TypeData -TypeName 'Deserialized.IntrinsicInfo.Intrinsic' -MemberName Docs -MemberType ScriptProperty -Value {
            & (Get-Module Utility) {
                param($instance)
                if ($null -ne $script:s_intrinsicsDocs.intrinsics_list) {
                    $script:s_intrinsicsDocs.intrinsics_list.SelectNodes("//intrinsic[@name='$($instance.Raw.Name)']")
                }
            } $this
        }

        Update-TypeData -TypeName 'Deserialized.IntrinsicInfo.Intrinsic' -MemberName Description -MemberType ScriptProperty -Value {
            return $this.Docs.description
        }

        $content = Get-Content $PSScriptRoot\intrinsics.ps1xml -ErrorAction Stop -Raw
        $script:s_intrinsics = [System.Management.Automation.PSSerializer]::Deserialize($content)

        $oldDefaults = $PSDefaultParameterValues
        $oldPref = $ProgressPreference
        try {
            $PSDefaultParameterValues = $global:PSDefaultParameterValues
            $ProgressPreference = [System.Management.Automation.ActionPreference]::Ignore
            $script:s_intrinsicsDocs = [xml](Invoke-WebRequest 'https://software.intel.com/sites/landingpage/IntrinsicsGuide/files/data-3.6.0.xml' -ErrorAction Stop).Content
        } finally {
            $PSDefaultParameterValues = $oldDefaults
            $ProgressPreference = $oldPref
        }

        $script:s_intrinsicsInitialized = $true
    }
}

function Get-Intrinsic {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline, Position = 0)]
        [SupportsWildcards()]
        [psobject] $Name,

        [Parameter()]
        [SupportsWildcards()]
        [string] $Group,

        [Parameter()]
        [SupportsWildcards()]
        [string] $RawInstruction
    )
    begin {
        EnsureIntrinsicsInitialized
        $intrinsics = $script:s_intrinsics
    }
    process {
        $notBound = -not $PSBoundParameters.ContainsKey((nameof{$Name})) -and
            -not $PSBoundParameters.ContainsKey((nameof{$Group})) -and
            -not $PSBoundParameters.ContainsKey((nameof{$RawInstruction}))

        if ($notBound -and -not $MyInvocation.ExpectingInput) {
            return $script:s_intrinsics
        }

        $string = $null
        if ($Name -is [string]) {
            $string = $Name
        } else {
            $methods = $null
            if ($Name -is [System.Management.Automation.PSMethod]) {
                $methods = $Name.ReflectionInfo
                if ($null -eq $methods) {
                    throw 'Profile ETS member "ReflectionInfo" is missing.'
                }
            } elseif ($Name -is [System.Reflection.MethodInfo]) {
                $methods = $Name
            } else {
                $string = [string]$Name
            }

            if ($null -ne $methods) {
                $string = $methods[0].Name
                $parent = $methods[0].DeclaringType
                if ($parent.Name -eq 'X64') {
                    $Group = $parent.DeclaringType.Name, $parent.Name -join '.'
                } else {
                    $Group = $parent.Name
                }
            }
        }

        $options = [System.Management.Automation.WildcardOptions]::IgnoreCase -bor
            [System.Management.Automation.WildcardOptions]::CultureInvariant
        $namePattern = if ([string]::IsNullOrEmpty($string)) { $null } else { [WildcardPattern]::new($string, $options) }
        $groupPattern = if ([string]::IsNullOrEmpty($Group)) { $null } else { [WildcardPattern]::new($Group, $options) }
        $rawInstructionPattern = if ([string]::IsNullOrEmpty($RawInstruction)) { $null } else { [WildcardPattern]::new($RawInstruction, $options) }

        foreach ($intrinsic in $intrinsics) {
            if ($namePattern -and -not $namePattern.IsMatch($intrinsic.Method.Name)) {
                continue
            }

            if ($groupPattern -and -not $groupPattern.IsMatch($intrinsic.Group)) {
                continue
            }

            if ($rawInstructionPattern -and -not $rawInstructionPattern.IsMatch($intrinsic.Raw.Name)) {
                continue
            }

            # yield
            $intrinsic
        }
    }
}
