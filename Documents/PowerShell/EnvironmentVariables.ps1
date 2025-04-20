using namespace System.Collections.Generic
using namespace Microsoft.PowerShell.Commands

class EnvironmentVariable {
    [string] $Name

    [string] $Value

    [EnvironmentVariableValue] $User

    [EnvironmentVariableValue] $Machine

    EnvironmentVariable(
        [string] $name,
        [string] $value,
        [EnvironmentVariableValue] $user,
        [EnvironmentVariableValue] $machine)
    {
        $this.Name = $name
        $this.Value = $value
        $this.User = $user
        $this.Machine = $machine
        $this.PSTypeNames.Insert(
            0,
            'UtilityProfile.EnvironmentVariable')
    }
}

class EnvironmentVariableValue {
    [string] $Value

    [Microsoft.Win32.RegistryValueKind] $Kind

    hidden [string] $_expandedCache

    EnvironmentVariableValue([string] $value, [Microsoft.Win32.RegistryValueKind] $kind) {
        $this.Value = $value
        $this.Kind = $kind
    }

    [bool] Equals([object] $other) {
        if ($other -is [string]) {
            return $this.GetExpanded() -eq $other
        }

        if ($other -is [EnvironmentVariableValue]) {
            return $this.GetExpanded() -eq $other.GetExpanded()
        }

        return $false
    }

    [string] GetExpanded() {
        if ($this.Kind -ne 'ExpandString') {
            return $this.Value
        }

        if (-not $this.Value) {
            return $null
        }

        return $this._expandedCache ??= [Environment]::ExpandEnvironmentVariables($this.Value)
    }

    [string] ToString() {
        return $this.Value
    }

    [bool] IsPresent() {
        return $this.Kind -ne 'None'
    }
}

class PathEntryBase {
    hidden static [char[]] $TrimChars = [char[]]" $([System.IO.Path]::PathSeparator)"

    static [string] Trim([string] $value) {
        if (-not $value) {
            return $value
        }

        return $value.Trim([char[]][PathEntryBase]::TrimChars)
    }
}

class PartialPathEntry : PathEntryBase <#, IEquatable[PathEntryBase] #> {
    [string] $Expanded

    hidden [string[]] $_expandedParts

    PartialPathEntry([string] $value) {
        $value = $global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($value)
        $this.Expanded = $value
        $this._expandedParts = $value -split '[\\/]'
    }

    hidden PartialPathEntry([string] $value, [string[]] $expandedParts) {
        $this.Expanded = $value
        $this._expandedParts = $expandedParts
    }

    [bool] Equals([PathEntryBase] $other) {
        if ($this._expandedParts.Length -ne $other._expandedParts.Length) {
            return $false
        }

        for ($i = 0; $i -lt $this._expandedParts.Length; $i++) {
            if ($this._expandedParts[$i] -ne $other._expandedParts[$i]) {
                return $false
            }
        }

        return $true
    }

    [bool] Equals([object] $other) {
        return $other -is [PathEntryBase] -and $this.Equals([PathEntryBase]$other)
    }

    [int] GetHashCode() {
        $hash = [HashCode]::new()
        foreach ($part in $this._expandedParts) {
            $hash.Add($part)
        }

        return $hash.ToHashCode()
    }

    [PathEntry] Complete(
        [int] $index,
        [string] $unexpanded,
        [string] $variableName,
        [EnvironmentVariableTarget] $scope)
    {
        return [PathEntry]::new(
            $this.Expanded,
            $this._expandedParts,
            $unexpanded,
            $index,
            $scope,
            $variableName)
    }
}

class PathEntry : PartialPathEntry {
    [int] $Index

    [string] $Unexpanded

    [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process

    [string] $VariableName

    hidden PathEntry(
        [string] $expanded,
        [string] $unexpanded,
        [int] $index,
        [EnvironmentVariableTarget] $target,
        [string] $variableName)
        : base($expanded)
    {
        $this.Index = $index
        $this.Scope = $target
        $this.Unexpanded = $unexpanded
        $this.VariableName = $variableName
        $this.AddTypeName()
    }

    hidden PathEntry(
        [string] $expanded,
        [string[]] $expandedParts,
        [string] $unexpanded,
        [int] $index,
        [EnvironmentVariableTarget] $target,
        [string] $variableName)
        : base($expanded, $expandedParts)
    {
        $this.Index = $index
        $this.Scope = $target
        $this.Unexpanded = $unexpanded
        $this.VariableName = $variableName
        $this.AddTypeName()
    }

    [void] AddTypeName() {
        $this.PSTypeNames.Insert(0, 'UtilityProfile.PathEntry')
    }

    static [PathEntryBase[]] FromEntryString([string] $value) {
        $parts = $value -split [System.IO.Path]::PathSeparator
        $result = [List[PathEntryBase]]::new($parts.Length)
        foreach ($part in $parts) {
            $part = [PathEntryBase]::Trim($part)
            if (-not $part) {
                continue
            }

            $result.Add([PartialPathEntry]::new($part))
        }

        return $result.ToArray()
    }

    static [void] AddAllFromUnexpanded(
        [List[PathEntryBase]] $target,
        [int] $start,
        [string] $unexpanded,
        [EnvironmentVariableTarget] $scope,
        [string] $variableName)
    {
        $parts = $unexpanded -split [System.IO.Path]::PathSeparator
        foreach ($part in $parts) {
            $part = [PathEntry]::Trim($part)
            if (-not $part) {
                continue
            }

            $target.Add(
                [PathEntry]::new(
                    [Environment]::ExpandEnvironmentVariables($part),
                    (Compress-EnvironmentVariable $part),
                    $start++,
                    $scope,
                    $variableName))
        }
    }
}

function Get-EnvironmentVariable {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string] $Name,

        [Parameter()]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )
    process {
        $machineKey = $userKey = $null
        try {
            $machineKey = [Microsoft.Win32.Registry]::LocalMachine.
                OpenSubKey('System\CurrentControlSet\Control\Session Manager\Environment')

            $userKey = [Microsoft.Win32.Registry]::CurrentUser.
                OpenSubKey('Environment')

            $machineValues = $machineKey.GetValueNames()

            $userValues = $userKey.GetValueNames()

            if ($Name) {
                return [EnvironmentVariable]::new(
                    $Name,
                    [Environment]::GetEnvironmentVariable($Name),
                    [EnvironmentVariableValue]::new(
                        $userKey.GetValue($Name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames),
                        $userValues -contains $Name ? $userKey.GetValueKind($Name) : [Microsoft.Win32.RegistryValueKind]::None),
                    [EnvironmentVariableValue]::new(
                        $machineKey.GetValue($Name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames),
                        $machineValues -contains $Name ? $machineKey.GetValueKind($Name) : [Microsoft.Win32.RegistryValueKind]::None))
            }

            foreach ($kvp in [System.Environment]::GetEnvironmentVariables().GetEnumerator()) {
                # yield
                [EnvironmentVariable]::new(
                    $kvp.Key,
                    $kvp.Value,
                    [EnvironmentVariableValue]::new(
                        $userKey.GetValue($kvp.Key, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames),
                        $userValues -contains $kvp.Key ? $userKey.GetValueKind($kvp.Key) : [Microsoft.Win32.RegistryValueKind]::None),
                    [EnvironmentVariableValue]::new(
                        $machineKey.GetValue($kvp.Key, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames),
                        $machineValues -contains $kvp.Key ? $machineKey.GetValueKind($kvp.Key) : [Microsoft.Win32.RegistryValueKind]::None))
            }
        } finally {
            if ($machineKey -is [System.IDisposable]) {
                $machineKey.Dispose()
            }

            if ($userKey -is [System.IDisposable]) {
                $userKey.Dispose()
            }
        }
    }
}

function Set-EnvironmentVariable {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [string] $Value,

        [Parameter()]
        [switch] $Expandable,

        [Parameter()]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )
    process {
        if ($Scope -eq 'Process') {
            [Environment]::SetEnvironmentVariable(
                $Name,
                $Value)

            return
        }

        $key = $null
        try {
            if ($Scope -eq 'User') {
                $key = [Microsoft.Win32.Registry]::CurrentUser.
                    OpenSubKey('Environment', $true)
            } else {
                $key = [Microsoft.Win32.Registry]::LocalMachine.
                    OpenSubKey('System\CurrentControlSet\Control\Session Manager\Environment', $true)
            }

            $kind = $Expandable ? 'ExpandString' : 'String'

            $whatIfMessage = "Updating value `"{0}`" at scope `"{1}`" to `n`n{2}" -f (
                $Name,
                $Scope,
                $Value)

            $confirmMessage = "If you continue the value `"{0}`" at path `"{1}`" will be updated to `n`n{2}`n`nWould you like to continue?" -f (
                $Name,
                $Scope,
                $Value)

            if ($PSCmdlet.ShouldProcess($whatIfMessage, $confirmMessage, 'Continue?')) {
                $key.SetValue(
                    $Name,
                    $Value,
                    $kind)
            }
        } finally {
            if ($key -is [IDisposable]) {
                $key.Dispose()
            }
        }
    }
}

function Get-PathEntry {
    [OutputType('UtilityProfile.PathEntry')]
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Pattern')]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ParameterSetName = 'Pattern')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Pattern,

        [Parameter()]
        [ValidateNotNull()]
        [EnvironmentVariableTarget[]] $Scope,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $VariableName = 'PATH',

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Literal')]
        [Alias('FullName')]
        [string] $LiteralPath,

        [Parameter()]
        [switch] $Refresh
    )
    begin {
        # This is way over engineered and also quite finicky if your paths are outdated. But
        # it's good enough for me.
        class EntryParser {
            [string] $Value

            [int] $Index

            [List[PathEntryBase]] $Entries = [List[PathEntryBase]]::new()

            [string] $VariableName

            [bool] $Refresh

            static [PathEntryBase[]] Parse([string] $processValue, [string] $variableName, [bool] $refresh) {
                $parser = [EntryParser]@{
                    Value = $processValue
                    VariableName = $variableName
                    Refresh = $refresh
                }

                $parser.Parse()
                return $parser.Entries.ToArray()
            }

            [void] Parse() {
                $machine = $user = $null
                if ($this.VariableName -ne 'PATH') {
                    $machine = [Environment]::GetEnvironmentVariable($this.VariableName, [EnvironmentVariableTarget]::Machine)
                    $user = [Environment]::GetEnvironmentVariable($this.VariableName, [EnvironmentVariableTarget]::User)
                } else {
                    $machine = $script:PathSnapshot.Machine.GetExpanded()
                    $user = $script:PathSnapshot.User.GetExpanded()
                }

                $machine = [PathEntry]::FromEntryString($machine)
                $user = [PathEntry]::FromEntryString($user)
                $process = [PathEntry]::FromEntryString($this.Value)

                $current = 0
                $machineIndex = $this.IndexOfSequence($process, $machine, $current)
                if ($machineIndex -gt -1) {
                    for ($i = 0; $i -lt $machineIndex; $i++) {
                        $this.Entries.Add(
                            $process[$i].Complete(
                                $i,
                                $process[$i].Expanded,
                                $this.VariableName,
                                [EnvironmentVariableTarget]::Process))
                    }

                    $this.AddUnexpanded([EnvironmentVariableTarget]::Machine, $machineIndex)
                    $current = $machineIndex + $machine.Length
                }

                $userIndex = $this.IndexOfSequence($process, $user, $current)
                if ($userIndex -gt -1) {
                    for ($i = $current; $i -lt $userIndex; $i++) {
                        $this.Entries.Add(
                            $process[$i].Complete(
                                $i,
                                $process[$i].Expanded,
                                $this.VariableName,
                                [EnvironmentVariableTarget]::Process))
                    }

                    $this.AddUnexpanded([EnvironmentVariableTarget]::User, $userIndex)
                    $current = $userIndex + $user.Length
                }

                for ($i = $current; $i -lt $process.Length; $i++) {
                    $this.Entries.Add(
                        $process[$i].Complete(
                            $i,
                            $process[$i].Expanded,
                            $this.VariableName,
                            [EnvironmentVariableTarget]::Process))
                }
            }

            [void] AddUnexpanded([EnvironmentVariableTarget] $scope, [int] $start) {
                $unexpanded = $null
                if ($this.Refresh -or $this.VariableName -ne 'PATH') {
                    $unexpanded = (Get-EnvironmentVariable $this.VariableName).($scope.ToString()).Value
                } else {
                    $unexpanded = $script:PathSnapshot.($scope.ToString()).Value
                }

                [PathEntry]::AddAllFromUnexpanded(
                    $this.Entries,
                    $start,
                    $unexpanded,
                    $scope,
                    $this.VariableName)
            }

            [int] IndexOfSequence([PathEntryBase[]] $source, [PathEntryBase[]] $target, [int] $start) {
                $t = 0
                $match = -1
                for ($i = $start; $i -lt $source.Length; $i++) {
                    if ($source[$i] -ne $target[$t]) {
                        $match = -1
                        $t = 0
                        continue
                    }

                    if ($t -eq ($target.Length - 1)) {
                        return $match
                    }

                    if ($t -eq 0) {
                        $match = $i
                    }

                    $t++
                }

                return -1
            }
        }

        $entries = [EntryParser]::Parse(
            [Environment]::GetEnvironmentVariable($VariableName),
            $VariableName,
            $Refresh.IsPresent)
    }
    process {
        foreach ($entry in $entries) {
            if ($Scope -and $entry.Scope -notin $Scope) {
                continue
            }

            if ($Pattern -and $entry.Expanded -notlike $Pattern) {
                continue
            }

            if ($LiteralPath -and $entry.Expanded -ne $LiteralPath) {
                continue
            }

            $entry
        }
    }
}

function Update-PathEntry {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $VariableName = 'PATH'
    )
    end {
        $entryVar = Get-EnvironmentVariable $VariableName
        $processEntries = [PathEntry]::FromEntryString($entryVar.Value)

        $machineEntries = $null
        if ($entryVar.Machine.IsPresent()) {
            $machineEntries = [PathEntry]::FromEntryString($entryVar.Machine.GetExpanded())
            $processEntries = $processEntries | Where-Object { $_ -notin $machineEntries }
        }

        $userEntries = $null
        if ($entryVar.User.IsPresent()) {
            $userEntries = [PathEntry]::FromEntryString($entryVar.User.GetExpanded())
            $processEntries = $processEntries | Where-Object { $_ -notin $userEntries }
        }

        $allEntries = & {
            $i = 0
            $processEntries = $processEntries
            $machineEntries = $machineEntries
            $userEntries = $userEntries
            $VariableName = $VariableName
            foreach ($entry in $processEntries) {
                $entry.Complete(
                    $i++,
                    $entry.Expanded,
                    $VariableName,
                    [EnvironmentVariableTarget]::Process)
            }

            foreach ($entry in $machineEntries) {
                $entry.Complete(
                    $i++,
                    $entry.Expanded,
                    $VariableName,
                    [EnvironmentVariableTarget]::Machine)
            }

            foreach ($entry in $userEntries) {
                $entry.Complete(
                    $i++,
                    $entry.Expanded,
                    $VariableName,
                    [EnvironmentVariableTarget]::User)
            }
        }

        [Environment]::SetEnvironmentVariable(
            $VariableName,
            $allEntries.Expanded -join [System.IO.Path]::PathSeparator)

        $script:PathSnapshot = $entryVar
    }
}

function Remove-PathEntry {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSTypeName('UtilityProfile.PathEntry')]
        [ValidateNotNull()]
        [psobject] $PathEntry
    )
    process {
        if ($PathEntry.Scope -eq $Process) {
            $entries = Get-PathEntry -VariableName $PathEntry.VariableName |
                Where-Object { $_.Scope -eq 'Process' -and $_ -ne $PathEntry }
                Select-Object -ExpandProperty Expanded

            [Environment]::SetEnvironmentVariable(
                $PathEntry.VariableName,
                $entries -join [System.IO.Path]::PathSeparator)

            return
        }

        $entries = Get-PathEntry -VariableName $PathEntry.VariableName -Scope $PathEntry.Scope -Refresh |
            Where-Object { $_ -ne $PathEntry } |
            Select-Object -ExpandProperty Unexpanded


        $newValue = $entries -join [System.IO.Path]::PathSeparator

        $whatIfMessage = "Updating value `"{0}`" at scope `"{1}`" to `n`n{2}" -f (
            $PathEntry.VariableName,
            $PathEntry.Scope,
            $newValue)

        $confirmMessage = "If you continue the value `"{0}`" at scope `"{1}`" will be updated to `n`n{2}`n`nWould you like to continue?" -f (
            $PathEntry.VariableName,
            $PathEntry.Scope,
            $newValue)

        if ($PSCmdlet.ShouldProcess($whatIfMessage, $confirmMessage, 'Continue?')) {
            Set-EnvironmentVariable -Name $PathEntry.VariableName -Value $newValue -Expandable -Scope $PathEntry.Scope
        }
    }
}

function Compress-EnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Value
    )
    process {
        if (-not $Value) {
            return
        }

        if ($Value -match '^%') {
            return $Value
        }

        $variables = (
            'APPDATA',
            'LOCALAPPDATA',
            'ProgramData',
            'ProgramFiles(x86)',
            'ProgramW6432',
            'SystemRoot',
            'USERPROFILE',
            'SystemDrive')

        foreach ($var in $variables) {
            $envValue = [Environment]::GetEnvironmentVariable($var)
            if ($Value.StartsWith($envValue, [StringComparison]::OrdinalIgnoreCase)) {
                return '%{0}%{1}' -f $var, $Value.Substring($envValue.Length)
            }
        }

        return $Value
    }
}

function Add-PathEntry {
    [OutputType('UtilityProfile.PathEntry')]
    [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName', 'PSPath')]
        [string[]] $Path,

        [Parameter()]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process,

        [Parameter()]
        [switch] $Prefix,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [string] $VariableName = 'PATH'
    )
    process {
        $shared = @{
            VariableName = $VariableName
            ErrorAction = [ActionPreference]::Stop
        }

        $yesToAll = $false
        foreach ($singlePath in $Path) {
            $hasEnvironmentVar = $singlePath.IndexOf([char]'%') -gt -1
            if (-not $hasEnvironmentVar) {
                $drive = $provider = $null
                $singlePath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                    $singlePath,
                    [ref] $provider,
                    [ref] $drive)

                if ($provider -and $provider.Name -ne [FileSystemProvider]::ProviderName) {
                    $PSCmdlet.WriteError(
                        [ErrorRecord]::new(
                            <# exception: #> [InvalidOperationException]::new(
                                'Path must be a FileSystem provider path.'),
                            <# errorId: #> 'PathMustBeFileSystem',
                            <# errorCategory: #> [ErrorCategory]::InvalidArgument,
                            <# targetObject: #> $singlePath))

                    continue
                }
            } elseif ($Scope -eq [EnvironmentVariableTarget]::Process) {
                $singlePath = [Environment]::ExpandEnvironmentVariables($singlePath)
            }

            if (-not $Force) {
                if ($Scope -eq [EnvironmentVariableTarget]::Process) {
                    if (Get-PathEntry -LiteralPath $singlePath @shared) {
                        continue
                    }
                } elseif (Get-PathEntry -LiteralPath $singlePath -Scope $Scope @shared) {
                    continue
                }
            }

            if ($Scope -eq [EnvironmentVariableTarget]::Process) {
                if ($Prefix) {
                    [Environment]::SetEnvironmentVariable(
                        $VariableName,
                        ($singlePath, [Environment]::GetEnvironmentVariable($VariableName) -join [System.IO.Path]::PathSeparator))

                    continue
                }

                [Environment]::SetEnvironmentVariable(
                    $VariableName,
                    ([Environment]::GetEnvironmentVariable($VariableName), $singlePath -join [System.IO.Path]::PathSeparator))

                continue
            }

            [string] $oldValue = $null
            try {
                $oldValue = (Get-EnvironmentVariable $VariableName -ErrorAction Stop).$Scope.Value
            } catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }

            $newValue = $null
            if (-not $hasEnvironmentVar) {
                $singlePath = Compress-EnvironmentVariable $singlePath
            }

            if ($Prefix) {
                $newValue = $singlePath, $oldValue -join [System.IO.Path]::PathSeparator
            } else {
                $newValue = $oldValue, $singlePath -join [System.IO.Path]::PathSeparator
            }

            $whatIfMessage = "Updating value `"{0}`" at scope `"{1}`" to `n`n{2}" -f (
                $VariableName,
                $Scope,
                $newValue)

            $confirmMessage = "If you continue the value `"{0}`" at scope `"{1}`" will be updated to `n`n{2}`n`nWould you like to continue?" -f (
                $VariableName,
                $Scope,
                $newValue)

            if ($PSCmdlet.ShouldProcess($whatIfMessage, $confirmMessage, 'Continue?')) {
                try {
                    Set-EnvironmentVariable $VariableName -Value $newValue -Expandable -Scope $Scope -ErrorAction Stop
                } catch {
                    $PSCmdlet.ThrowTerminatingError($PSItem)
                }
            }
        }
    }
}

$PathSnapshot = Get-EnvironmentVariable PATH
