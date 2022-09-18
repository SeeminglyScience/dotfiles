using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.ComponentModel
using namespace System.Diagnostics
using namespace System.Diagnostics.CodeAnalysis
using namespace System.IO
using namespace System.Linq.Expressions
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Runspaces
using namespace System.Net
using namespace System.Net.NetworkInformation
using namespace System.Net.Sockets
using namespace System.Reflection
using namespace System.Reflection.Emit
using namespace System.Reflection.PortableExecutable
using namespace System.Resources
using namespace System.Runtime.InteropServices
using namespace System.Security.AccessControl
using namespace System.Text
using namespace System.Text.RegularExpressions
using namespace System.Threading.Tasks
using namespace Microsoft.PowerShell.Commands
using namespace Microsoft.Win32

[SuppressMessage('PSAvoidUsingCmdletAliases', '', Target = '??')]
param()

class EncodingArgumentCompleter : IArgumentCompleter {
    hidden static [string[]] $s_encodings

    static EncodingArgumentCompleter() {
        $allEncodings = [Encoding]::GetEncodings()
        $names = [string[]]::new($allEncodings.Length + 7)
        $names[0] = 'ASCII'
        $names[1] = 'BigEndianUnicode'
        $names[2] = 'Default'
        $names[3] = 'Unicode'
        $names[4] = 'UTF32'
        $names[5] = 'UTF7'
        $names[6] = 'UTF8'

        for ($i = 0; $i -lt $allEncodings.Length; $i++) {
            $names[$i + 7] = $allEncodings[$i].Name
        }

        [EncodingArgumentCompleter]::s_encodings = $names
    }

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $fakeBoundParameters)
    {
        $results = [List[CompletionResult]]::new(<# capacity: #> 4)
        foreach ($name in $this::s_encodings) {
            if ($name -notlike "$wordToComplete*") {
                continue
            }

            $results.Add(
                [CompletionResult]::new(
                    <# completionText: #> $name,
                    <# listItemText:   #> $name,
                    <# resultType:     #> [CompletionResultType]::ParameterValue,
                    <# toolTip:        #> $name))
        }

        return $results.ToArray()
    }
}

class EncodingArgumentConverterAttribute : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics] $engineIntrinsics, [object] $inputData) {
        if ($null -eq $inputData) {
            return $null
        }

        if ($inputData -is [Encoding]) {
            return $inputData
        }

        $convertedValue = default([Encoding])
        if ([LanguagePrimitives]::TryConvertTo($inputData, [Encoding], [ref] $convertedValue)) {
            return $convertedValue
        }

        if ($inputData -isnot [string]) {
            $inputData = $inputData -as [string]
            if ([string]::IsNullOrEmpty($inputData)) {
                return $null
            }
        }

        switch ($inputData) {
            ASCII { return [Encoding]::ASCII }
            BigEndianUnicode { return [Encoding]::BigEndianUnicode }
            'Default' { return [Encoding]::Default }
            Unicode { return [Encoding]::Unicode }
            UTF32 { return [Encoding]::UTF32 }
            UTF7 { return [Encoding]::UTF7 }
            UTF8 { return [Encoding]::UTF8 }
        }

        return [Encoding]::GetEncoding($inputData)
    }
}

class CommandInfoArgumentConverterAttribute : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics] $engineIntrinsics, [object] $inputData) {
        if ($inputData -is [CommandInfo]) {
            return $inputData
        }

        $asString = [string]$inputData
        return Get-Command $asString | Select-Object -First 1
    }
}

# Terrible dirty hack to get around using non-exported classes in some of the function
# parameter blocks. Don't use this in a real module pls
$typeAccel = [ref].Assembly.GetType('System.Management.Automation.TypeAccelerators')
$typeAccel::Add('EncodingArgumentConverterAttribute', [EncodingArgumentConverterAttribute])
$typeAccel::Add('EncodingArgumentConverter', [EncodingArgumentConverterAttribute])
$typeAccel::Add('EncodingArgumentCompleter', [EncodingArgumentCompleter])
$typeAccel::Add('CommandInfoArgumentConverterAttribute', [CommandInfoArgumentConverterAttribute])
$typeAccel::Add('CommandInfoArgumentConverter', [CommandInfoArgumentConverterAttribute])

function EnsureCommandStopperInitialized {
    [CmdletBinding()]
    param()
    end {
        if ('UtilityProfile.CommandStopper' -as [type]) {
            return
        }

        Add-Type -TypeDefinition '
            using System;
            using System.ComponentModel;
            using System.Linq.Expressions;
            using System.Management.Automation;
            using System.Management.Automation.Internal;
            using System.Reflection;

            namespace UtilityProfile
            {
                [EditorBrowsable(EditorBrowsableState.Never)]
                [Cmdlet(VerbsLifecycle.Stop, "UpstreamCommand")]
                public class CommandStopper : PSCmdlet
                {
                    private static readonly Func<PSCmdlet, Exception> s_creator;

                    static CommandStopper()
                    {
                        ParameterExpression cmdlet = Expression.Parameter(typeof(PSCmdlet), "cmdlet");
                        s_creator = Expression.Lambda<Func<PSCmdlet, Exception>>(
                            Expression.New(
                                typeof(PSObject).Assembly
                                    .GetType("System.Management.Automation.StopUpstreamCommandsException")
                                    .GetConstructor(
                                        BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Instance,
                                        null,
                                        new Type[] { typeof(InternalCommand) },
                                        null),
                                cmdlet),
                            "NewStopUpstreamCommandsException",
                            new ParameterExpression[] { cmdlet })
                            .Compile();
                    }

                    [Parameter(Position = 0, Mandatory = true)]
                    [ValidateNotNull]
                    public Exception Exception { get; set; }

                    [Hidden, EditorBrowsable(EditorBrowsableState.Never)]
                    public static void Stop(PSCmdlet cmdlet)
                    {
                        var exception = s_creator(cmdlet);
                        cmdlet.SessionState.PSVariable.Set("__exceptionToThrow", exception);
                        var variable = GetOrCreateVariable(cmdlet, "__exceptionToThrow");
                        object oldValue = variable.Value;
                        try
                        {
                            variable.Value = exception;
                            ScriptBlock.Create("& $ExecutionContext.InvokeCommand.GetCmdletByTypeName([UtilityProfile.CommandStopper]) $__exceptionToThrow")
                                .GetSteppablePipeline(CommandOrigin.Internal)
                                .Begin(false);
                        }
                        finally
                        {
                            variable.Value = oldValue;
                        }
                    }

                    private static PSVariable GetOrCreateVariable(PSCmdlet cmdlet, string name)
                    {
                        PSVariable result = cmdlet.SessionState.PSVariable.Get(name);
                        if (result != null)
                        {
                            return result;
                        }

                        result = new PSVariable(name, null);
                        cmdlet.SessionState.PSVariable.Set(result);
                        return result;
                    }

                    protected override void BeginProcessing()
                    {
                        throw Exception;
                    }
                }
            }'
    }
}

function Invoke-VSCode {
    [Alias('vsc')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ValueFromRemainingArguments)]
        [string]
        $Path
    )
    begin {
        $code = $global:PathToVSCodeOverride | ?? { 'C:\Program Files\Microsoft VS Code\bin\code.cmd' }
        $pathList = new System.Collections.Generic.List[string]
    }
    process {
        if (-not $Path) { return }
        $pathList.Add($Path)
    }
    end {
        if (-not $pathList) {
            & $code
            return
        }
        $Path = $pathList

        foreach ($item in $pathList) {
            $extraArgs = ($item = Get-Item $Path -ea 0) -and $item.PSIsContainer | ?? { '' } : { '-r' }
            & $code $pathList $extraArgs
        }
    }
}

function Get-Gac {
    [CmdletBinding()]
    param()
    begin {
        $pattern =
            '\s+(?<FQN>(?<Name>[^,]+), ' +
            'Version=(?<Version>[^,]+), ' +
            'Culture=(?<Culture>[^,]+), ' +
            'PublicKeyToken=(?<Token>[^,]+))' +
            '(?:, processorArchitecture=(?<Arch>\w+))?'

        $regex = [regex]::new(
            $pattern,
            [System.Text.RegularExpressions.RegexOptions]'Compiled, IgnoreCase')
    }
    end {
        $gacUtil = Get-Command gacutil.exe -CommandType Application -ErrorAction Ignore
        if (-not $gacUtil) {
            if (-not [string]::IsNullOrEmpty($global:GacUtilOverridePath)) {
                $gacUtil = Get-Command $global:GacUtilOverridePath -ErrorAction Ignore
            }

            if (-not $gacUtil) {
                $defaultPath = "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.7.2 Tools\x64\gacutil.exe"
                $gacUtil = Get-Command $defaultPath -ErrorAction Ignore
            }
        }

        if (-not $gacUtil) {
            $exception = [CommandNotFoundException]::new(
                'Unable to find gacutil.exe. Add the parent directory to $env:PATH or user ' +
                'the $GacUtilOverridePath to specify it''s location and then try the command again.')

            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    <# exception:     #> $exception,
                    <# errorId:       #> 'GacUtilNotFound',
                    <# errorCategory: #> [ErrorCategory]::ObjectNotFound,
                    <# targetObject:  #> $null))

            return
        }

        $assemblies = & $gacUtil -l -nologo
        $assemblies = $assemblies[1..($assemblies.Count - 3)]

        foreach ($assembly in $assemblies) {
            $result = $regex.Match($assembly)
            $culture = $result.Groups['Culture'].Value
            if ($culture -eq 'neutral') {
                $culture = [string]::Empty
            }

            $assemblyName = [AssemblyName]::new($result.Groups['Name'].Value)
            $assemblyName.CultureName = $culture
            $assemblyName.Version = $result.Groups['Version'].Value

            if ($result.Groups['Arch'].Success) {
                $assemblyName.ProcessorArchitecture = $result.Groups['Arch'].Value
            }

            if ($result.Groups['Token'].Success) {
                $publicKeyToken = $result.Groups['Token'].Value
                $token = [byte[]]::new(8)
                for ($i = $publicKeyToken.Length - 2; $i -ge 0; $i -= 2) {
                    $asHexString = '0x{0}{1}' -f $publicKeyToken[$i], $publicKeyToken[$i + 1]
                    $token[$i / 2] = $asHexString
                }

                $assemblyName.SetPublicKeyToken($token)
            }

            # yield
            $assemblyName
        }
    }
}

function Get-NamedPipe {
    [CmdletBinding()]
    param()
    end {
        $utils = [ref].Assembly.GetType('System.Management.Automation.Utils')
        $utils | Add-PrivateMember
        $pipes = $null
        $utils::NativeEnumerateDirectory('\\.\pipe', [ref]$null, [ref]$pipes)
        return $pipes
    }
}

function Get-InstalledSoftware {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]
        $Name
    )
    begin {
        $allNames = $null
    }
    process {
        if (-not $PSBoundParameters.ContainsKey((nameof{$Name})) -or [string]::IsNullOrEmpty($Name)) {
            return
        }

        if ($null -eq $allNames) {
            $startingCapacity = 1
            if ($MyInvocation.ExpectingInput) {
                $startingCapacity = 4
            }

            $allNames = [List[string]]::new($startingCapacity)
        }

        $allNames.Add($Name)
    }
    end {
        if ($null -ne $allNames) {
            $wildcards = [WildcardPattern[]]::new($allNames.Count)
            for ($i = 0; $i -lt $allNames.Count; $i++) {
                $wildcards[$i] = [WildcardPattern]::new(
                    $allNames[$i],
                    [WildcardOptions]::IgnoreCase)
            }
        }

        # Don't use the registry provider for performance and to allow us to open the
        # 64 bit registry view from a 32 bit process.
        $hklm = $null
        $ownsKey = $false
        try {
            $registryPaths = (
                @{
                    Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
                    Is64Bit = $true
                },
                @{
                    Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
                    Is64Bit = $false
                })

            $hklm = [Registry]::LocalMachine
            if (-not [Environment]::Is64BitProcess) {
                if ([Environment]::Is64BitOperatingSystem) {
                    $ownsKey = $true
                    $hklm = [RegistryKey]::OpenBaseKey(
                        [RegistryHive]::LocalMachine,
                        [RegistryView]::Registry64)
                } else {
                    $registryPaths = @($registryPaths[0])
                    $registryPaths[0].Is64Bit = $false
                }
            }

            foreach ($registryPath in $registryPaths) {
                $software = $null
                try {
                    $software = $hklm.OpenSubKey($registryPath.Path)
                    foreach ($subKeyName in $software.GetSubKeyNames()) {
                        $subKey = $null
                        try {
                            $subKey = $software.OpenSubKey(
                                $subKeyName,
                                [RegistryRights]::QueryValues)

                            $displayName = $subKey.GetValue('DisplayName')
                            if ([string]::IsNullOrEmpty($displayName)) {
                                continue
                            }

                            if ($wildcards.Length -gt 0) {
                                $wasMatchFound = $false
                                foreach ($wildcard in $wildcards) {
                                    if ($wildcard.IsMatch($displayName)) {
                                        $wasMatchFound = $true
                                        break
                                    }
                                }

                                if (-not $wasMatchFound) {
                                    continue
                                }
                            }

                            $installedOn = $subKey.GetValue('InstallDate')
                            if (-not [string]::IsNullOrWhiteSpace($installedOn)) {
                                $installedOn = [datetime]::ParseExact($installedOn, 'yyyyMMdd', $null)
                            }

                            # yield
                            [PSCustomObject]@{
                                PSTypeName = 'Utility.InstalledSoftware'
                                Name = $displayName
                                Publisher = $subKey.GetValue('Publisher')
                                DisplayVersion = $subKey.GetValue('DisplayVersion')
                                Uninstall = $subKey.GetValue('UninstallString')
                                Guid = $subKeyName
                                InstallDate = $installedOn
                                Is64Bit = $registryPath.Is64Bit
                                PSPath = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\{0}\{1}' -f (
                                    $registryPath.Path,
                                    $subKeyName)
                            }
                        } catch {
                            $PSCmdlet.WriteError($PSItem)
                        } finally {
                            if ($null -ne $subKey) {
                                $subKey.Dispose()
                            }
                        }
                    }
                } finally {
                    if ($null -ne $software) {
                        $software.Dispose()
                    }
                }
            }
        } finally {
            if ($ownsKey -and $null -ne $hklm) {
                $hklm.Dispose()
            }
        }
    }
}

function Install-Shim {
    [Alias('ishim')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string[]] $FilePath,

        [ValidateNotNullOrEmpty()]
        [string] $Destination,

        [switch] $Gui
    )
    begin {
        function ValidatePath {
            param([string] $PathToValidate)
            end {

                if (-not (Test-Path $PathToValidate)) {
                    $PSCmdlet.ThrowTerminatingError(
                        [ErrorRecord]::new(
                            [PSArgumentException]::new(
                                [UtilityResources]::PathDoesNotExist -f $PathToValidate),
                            'PathDoesNotExist',
                            [ErrorCategory]::InvalidArgument,
                            $PathToValidate))
                    return
                }

                if ((Get-Item $PathToValidate).PSIsContainer) {
                    $PSCmdlet.ThrowTerminatingError(
                        [ErrorRecord]::new(
                            [PSArgumentException]::new(
                                'Cannot generate a shim for a directory. Please specify a ' +
                                'file and try the command again.'),
                            'CannotShimDirectory',
                            [ErrorCategory]::InvalidArgument,
                            $PathToValidate))
                    return
                }
            }
        }

        function GetShimGen {
            param()
            end {
                try {
                    $choco = Get-Command choco -ErrorAction Stop
                } catch {
                    $PSCmdlet.ThrowTerminatingError(
                        $PSItem.Exception,
                        'CannotFindChocolatey',
                        [ErrorCategory]::InvalidOperation,
                        $null)
                    return
                }


                $result = $choco.Source |
                    Split-Path |
                    Split-Path |
                    Join-Path -ChildPath 'tools\shimgen.exe' |
                    Get-Command -CommandType Application

                if ($result) {
                    return $result
                }

                $PSCmdlet.ThrowTerminatingError(
                    [ErrorRecord]::new(
                        [PSInvalidOperationException]::new(
                            'Unable to find the shimgen executable within chocolatey. ' +
                            'This may indicate an unexpected version of chocolatey or corruption.'),
                        'CannotFindShimGen',
                        [ErrorCategory]::InvalidOperation,
                        $shimGen))
            }
        }

        $shimGen = GetShimGen
        $shimGenPath = $shimGen.Source | Split-Path
        if ([string]::IsNullOrWhiteSpace($Destination)) {
            $Destination = $PSCmdlet.SessionState.Path.CurrentFileSystemLocation.Path
        }

        try {
            $destItem = Get-Item $Destination
        } catch {
            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    $PSItem,
                    'PathDoesNotExist',
                    [ErrorCategory]::InvalidArgument,
                    $destItem))
        }
    }
    process {
        foreach ($path in $FilePath) {
            ValidatePath -PathToValidate $path
            [string] $path = Resolve-Path $path -ErrorAction Stop

            $fileName = Split-Path $path -Leaf
            $outputPath = Join-Path $destItem.FullName -ChildPath $fileName
            $escapedOutputPath = $outputPath -replace ' ', '\ '
            $escapedShimTarget = $path -replace ' ', '\ '
            if ($Gui.IsPresent) {
                & $shimGen -output="$escapedOutputPath" --path="$escapedShimTarget" --gui
                continue
            }

            & $shimGen -output="$escapedOutputPath" --path="$escapedShimTarget"
        }
    }
}


function Set-AndPass {
    [Alias('sap')]
    [OutputType([psobject])]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $VariableName = 'p',

        [Parameter()]
        [Alias('s')]
        [switch] $SingleItem
    )
    begin {
        $isAppend = $false
        if ($VariableName[0] -eq '+' -and $VariableName.Length -gt 1) {
            $VariableName = $VariableName.Substring(1)
            $isAppend = $true
        }

        # If we had to account for the caller possibily being from this module, we'd need to check
        # for that and use Set-Variable with scope parameters. Fortunately this will never be
        # called in any situation other than interactively.
        $state = $PSCmdlet.SessionState
        $var = $state.PSVariable.Get($VariableName)
        if ($null -eq $var) {
            $var = [psvariable]::new($VariableName, $null)
            $state.PSVariable.Set($var)
        }

        if ($SingleItem.IsPresent) {
            return
        }

        $outputList = $var.Value
        if ($outputList -is [IList]) {
            try {
                # Use hidden methods to force out exceptions that PS ignores.
                $isReadOnly = $outputList.get_IsReadOnly()
                $isFixedSize = $outputList.get_IsFixedSize()
                $didFailChecks = $false
            } catch {
                $didFailChecks = $true
            }

            if ($isReadOnly -or $isFixedSize -or $didFailChecks) {
                $outputList = [List[object]]::new()
                $var.Value = $outputList
            } elseif (-not $isAppend) {
                try {
                    $outputList.Clear()
                } catch {
                    $PSCmdlet.WriteError($PSItem)
                }
            }
        } else {
            $outputList = [List[object]]::new()
            $var.Value = $outputList
        }
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($SingleItem.IsPresent) {
            $var.Value = $InputObject
            # Don't double enumerate. If we get an array upstream, send it down.
            $PSCmdlet.WriteObject($InputObject, <# enumerateCollection: #> $false)
            return
        }

        try {
            $null = $outputList.Add($InputObject)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }

        $PSCmdlet.WriteObject($InputObject, <# enumerateCollection: #> $false)
    }
}

$_globalSessionState = $null

function Get-GlobalSessionState {
    [CmdletBinding()]
    param()
    end {
        $existing = $script:_globalSessionState
        if ($null -ne $existing) {
            return $existing
        }

        $npi = [BindingFlags]::NonPublic -bor 'Instance'
        $context = [EngineIntrinsics].GetField('_context', $npi).GetValue($ExecutionContext)
        $ssi = $context.GetType().GetProperty('TopLevelSessionState', $npi).GetValue($context)
        $publicSessionState = $ssi.GetType().GetProperty('PublicSessionState', $npi).GetValue($ssi)
        $stateHolder = [psmoduleinfo]::new($false)
        $stateHolder.SessionState = $publicSessionState
        return $script:_globalSessionState = $stateHolder
    }
}

function Enter-LocalRunspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [runspace] $Runspace
    )
    end {
        try {
            if ($Host.Name -ne 'ConsoleHost') {
                throw [PSNotSupportedException]::new(
                    'Host interface is not supported. This function can only be used with ConsoleHost')
            }

            if ($Runspace.RunspaceAvailability -ne [RunspaceAvailability]::Available) {
                throw [PSInvalidOperationException]::new(
                    'Target runspace must be available for commands.')
            }

            if (-not ($runspaceStack = $script:PushedLocalRunspaces)) {
                $script:PushedLocalRunspaces = $runspaceStack = [Stack[runspace]]::new()

                $runspaceStack.Push($Host.Runspace)
            }

            $ps = [powershell]::Create()
            try {
                $ps.Runspace = $Runspace
                $null =
                    $ps.AddCommand('Microsoft.PowerShell.Core\Import-Module').
                        AddParameter('Name', 'PSReadLine').
                        AddParameter('ErrorAction', 'Ignore').
                        AddStatement().
                        AddCommand('Microsoft.PowerShell.Core\Import-Module').
                        AddParameter('Name', $PSCommandPath).
                        AddParameter('ErrorAction', 'Ignore').
                        AddStatement().
                        AddScript( {
                                param([System.Collections.Generic.Stack[runspace]] $Stack)
                                & (Get-Module Utility) { $script:PushedLocalRunspaces = $Stack }
                            }).
                        AddArgument($runspaceStack).
                        Invoke()
            } finally {
                $ps.Dispose()
            }

            $npi = [BindingFlags]'Instance, NonPublic'
            $externalHostRef = $Host.GetType().
                GetField('externalHostRef', $npi).
                GetValue($Host)

            $hostValue = $externalHostRef.GetType().
                GetProperty('Value', $npi).
                GetValue($externalHostRef)

            $runspaceRef = $hostValue.GetType().
                GetProperty('RunspaceRef', $npi).
                GetValue($hostValue)

            $implRunspaceRef = $runspaceRef.GetType().
                GetField('_runspaceRef', $npi).
                GetValue($runspaceRef)

            $null = $implRunspaceRef.GetType().
                GetMethod('Override', $npi).
                Invoke($implRunspaceRef, @($Runspace))
        } catch {
            $exception = $PSItem
            if ($PSItem -isnot [Exception]) {
                $exception = $exception.Exception
            }

            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    $exception,
                    'EnterRunspaceFailed',
                    [ErrorCategory]::OpenError,
                    $Runspace))
        }

        $runspaceStack.Push($Runspace)
    }
}

function Exit-LocalRunspace {
    [CmdletBinding()]
    param()
    end {
        if (-not ($runspaceStack = $script:PushedLocalRunspaces)) {
            $PSCmdlet.WriteVerbose('Ignore exit request, runspace is not pushed.')
            return
        }

        if ($Host.Name -ne 'ConsoleHost') {
            throw [System.Management.Automation.PSNotSupportedException]::new(
                'Host interface is not supported. This function can only be used with ConsoleHost')
        }

        try {
            $npi = [BindingFlags]'Instance, NonPublic'
            $externalHostRef = $Host.GetType().
                GetField('externalHostRef', $npi).
                GetValue($Host)

            $hostValue = $externalHostRef.GetType().
                GetProperty('Value', $npi).
                GetValue($externalHostRef)

            $runspaceRef = $hostValue.GetType().
                GetProperty('RunspaceRef', $npi).
                GetValue($hostValue)

            $implRunspaceRef = $runspaceRef.GetType().
                GetField('_runspaceRef', $npi).
                GetValue($runspaceRef)

            $null = $implRunspaceRef.GetType().
                GetMethod('Revert', $npi).
                Invoke($implRunspaceRef, @())
        } catch {
            $exception = $PSItem
            if ($PSItem -isnot [Exception]) {
                $exception = $exception.Exception
            }

            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    $exception,
                    'ExitRunspaceFailed',
                    [ErrorCategory]::OpenError,
                    $Host))
        }

        $null = $runspaceStack.Pop()
    }
}

function Start-ElevatedSession {
    [Alias('up')]
    [CmdletBinding()]
    param(
        [switch] $NoExit
    )
    end {
        $currentPath = $PSCmdlet.SessionState.Path.CurrentFileSystemLocation

        if ($__IsTerminal) {
            wt new-tab -p 'PowerShell Preview (Elevated)' -d $currentPath
        } else {
            $encodedCommand = "Set-Location '$currentPath'" | ConvertTo-Base64String
            $pwsh = [Environment]::GetCommandLineArgs()[0] -replace "($([regex]::Escape("$env:windir\")))Sysnative", '$1system32' -replace 'pwsh\.dll', 'pwsh.exe'
            $process = Start-Process -PassThru -Verb RunAs $pwsh('-NoExit', "-EncodedCommand $encodedCommand")
            if ($process.HasExited) {
                throw "$pwsh exited with code $process.ExitCode"
            }
        }

        if (-not $NoExit.IsPresent) {
            [Environment]::Exit(0)
        }
    }
}

function ConvertTo-ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [System.Management.Automation.Language.Ast] $Ast
    )
    begin {
        function EmptyArray {
            [CmdletBinding()]
            param([ArgumentCompleter([ClassExplorer.TypeArgumentCompleter])][type] $Type)
            end {
                $PSCmdlet.WriteObject(
                    $Type.MakeArrayType()::new(0),
                    <# enumerateCollection: #> $false)
            }
        }

        $ep = [ScriptPosition]::new('', 0, 0, '', '')
        $ee = [ScriptExtent]::new($ep, $ep)
    }
    process {
        if ($Ast -is [ExpressionAst]) {
            $Ast = [CommandExpressionAst]::new(
                <# extent:       #> $ee,
                <# expression:   #> $Ast.Copy(),
                <# redirections: #> (EmptyArray System.Management.Automation.Language.RedirectionAst))
        }

        if ($Ast -is [StatementAst]) {
            $Ast = [StatementBlockAst]::new(
                <# extent:     #> $ee,
                <# statements: #> $Ast.Copy() -as [StatementAst[]],
                <# traps:      #> (EmptyArray System.Management.Automation.Language.TrapStatementAst))
        }

        if ($Ast -is [StatementBlockAst]) {
            $Ast = [ScriptBlockAst]::new(
                <# extent:     #> $ee,
                <# paramBlock:     #> [ParamBlockAst]::new(
                    <# extent:     #> $ee,
                    <# attributes: #> (EmptyArray System.Management.Automation.Language.AttributeAst),
                    <# parameters: #> (EmptyArray System.Management.Automation.Language.ParameterAst)),
                <# statements: #> $Ast.Copy(),
                <# isFilter:   #> $false)
        }

        if ($Ast -isnot [ScriptBlockAst]) {
            throw 'Did not account for type "{0}"' -f $Ast.GetType()
        }

        return $Ast.GetScriptBlock()
    }
}

function Get-LoaderException {
    [CmdletBinding(DefaultParameterSetName='__AllParameterSets')]
    param(
        [Parameter(ValueFromPipeline, Mandatory, ParameterSetName='Exception')]
        [ValidateNotNull()]
        [Exception] $Exception,

        [Parameter(ValueFromPipeline, Mandatory, ParameterSetName='ErrorRecord')]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )
    process {
        switch ($PSCmdlet.ParameterSetName) {
            __AllParameterSets {
                if ($PSCmdlet.MyInvocation.ExpectingInput) {
                    throw 'Piped input needs to be either an exception or an error record.'
                }

                $Exception = $global:Error[0].Exception
            }
            ErrorRecord {
                $Exception = $ErrorRecord.Exception
            }
        }

        if (-not $Exception) {
            throw 'Could not determine target exception.'
        }

        $Exception.GetBaseException().LoaderExceptions | Group-Object { $PSItem.GetType() } | ForEach-Object {
            $exceptionGroup = $PSItem
            switch ($exceptionGroup.Name) {
                System.IO.FileNotFoundException {
                    $exceptionGroup.Group | Group-Object FileName | ForEach-Object {
                        [PSCustomObject]@{
                            Type = 'FileNotFound'
                            Subject = $PSItem.Name
                            Exceptions = $PSItem.Group
                        }
                    }
                }
                default {
                    [PSCustomObject]@{
                        Type = ($exceptionGroup.Name -split '\.').Where($null, 'Last')[0]
                        Subject = $exceptionGroup.Group.Where($null, 'First')[0] -as [string]
                        Exceptions = $exceptionGroup.Group
                    }
                }
            }
        }
    }
}

function Get-SpecialFolder {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Name
    )
    begin {
        $specialFolders = [enum]::GetNames([Environment+SpecialFolder]) | ForEach-Object {
            $value = [Environment]::GetFolderPath(
                $PSItem,
                [Environment+SpecialFolderOption]::DoNotVerify)

            return [PSCustomObject]@{
                PSTypeName = 'UtilityProfile.SpecialFolderInfo'
                DoesExist  = -not [string]::IsNullOrEmpty($value) -and (Test-Path -LiteralPath $value)
                Name       = $PSItem
                Value      = $value
            }
        }

        $alreadyProcessed = [HashSet[psobject]]::new()
    }
    process {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return
        }

        return $specialFolders |
            Where-Object { $PSItem.Name -like $Name -and $alreadyProcessed.Add($PSItem) }
    }
    end {
        if ($PSCmdlet.MyInvocation.ExpectingInput -or -not [string]::IsNullOrWhiteSpace($Name)) {
            return
        }

        return $specialFolders
    }
}

function Get-AppVeyorArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Account,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Project
    )
    begin {
        $apiUrl = 'https://ci.appveyor.com/api'
    }
    end {
        $projectObject = Invoke-RestMethod "$apiUrl/projects/$account/$project"
        $build = $projectObject.build
        $jobId = $projectObject.build.jobs[0].jobId

        Invoke-RestMethod "$apiUrl/buildjobs/$jobId/artifacts" | ForEach-Object { $PSItem } | ForEach-Object {
            return [PSCustomObject]@{
                Name = $PSItem.fileName
                Status = $build.status
                Version = $build.version
                Type = $PSItem.type
                Uri = '{0}/buildjobs/{1}/artifacts/{2}' -f $apiUrl, $jobId, $PSItem.fileName
            }
        }
    }
}

function Show-MemberSource {
    [Alias('sms')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [Alias('Member')]
        [psobject] $InputObject,

        [Parameter()]
        [ValidateSet('IL', 'CSharp', 'VisualBasic')]
        [string] $Language = 'CSharp',

        [switch] $NoAnonymousMethods,
        [switch] $NoExpressionTrees,
        [switch] $NoYield,
        [switch] $NoAsync,
        [switch] $NoAutomaticProperties,
        [switch] $NoAutomaticEvents,
        [switch] $NoUsingStatements,
        [switch] $NoForEachStatements,
        [switch] $NoLockStatements,
        [switch] $NoSwitchOnString,
        [switch] $NoUsingDeclarations,
        [switch] $NoQueryExpressions,
        [switch] $DontClarifySameNameTypes,
        [switch] $UseFullnamespace,
        [switch] $DontUseVariableNamesFromSymbols,
        [switch] $NoObjectOrCollectionInitializers,
        [switch] $NoInlineXmlDocumentation,
        [switch] $DontRemoveEmptyDefaultConstructors,
        [switch] $DontUseIncrementOperators,
        [switch] $DontUseAssignmentExpressions,
        [switch] $AlwaysCreateExceptionVariables,
        [switch] $SortMembers,
        [switch] $ShowTokens,
        [switch] $ShowBytes,
        [switch] $ShowPdbInfo
    )
    begin {
        $expandMemberInfo = $ExecutionContext.InvokeCommand.GetCommand(
            (nameof{Expand-MemberInfo}),
            [CommandTypes]::Function)

        $outString = $ExecutionContext.InvokeCommand.GetCmdletByTypeName([OutStringCommand])

        # Include ExternalScript because that's how scoop "shims" for some reason.
        $bat = $ExecutionContext.InvokeCommand.GetCommand(
            'bat',
            [CommandTypes]'Application, ExternalScript')

        if ($null -eq $bat) {
            $exception = [PSInvalidOperationException]::new('Pager "bat" is not installed.')
            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    <# exception:     #> $exception,
                    <# errorId:       #> 'BatNotFound',
                    <# errorCategory: #> [ErrorCategory]::ObjectNotFound,
                    <# targetObject:  #> $null))

            return
        }

        $wrappedCommand = {
            & $expandMemberInfo @PSBoundParameters |
                & $outString |
                & $bat --language cs |
                Microsoft.PowerShell.Core\Out-Default
        }

        $pipe = $wrappedCommand.GetSteppablePipeline([CommandOrigin]::Internal)
        try {
            $pipe.Begin($MyInvocation.ExpectingInput)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    process {
        try {
            $pipe.Process($PSItem)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    end {
        try {
            $pipe.End()
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
}

function Expand-MemberInfo {
    [Alias('emi')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [Alias('Member')]
        [psobject] $InputObject,

        [Parameter()]
        [ValidateSet('IL', 'CSharp', 'VisualBasic')]
        [string] $Language = 'CSharp',

        [switch] $NoAnonymousMethods,
        [switch] $NoExpressionTrees,
        [switch] $NoYield,
        [switch] $NoAsync,
        [switch] $NoAutomaticProperties,
        [switch] $NoAutomaticEvents,
        [switch] $NoUsingStatements,
        [switch] $NoForEachStatements,
        [switch] $NoLockStatements,
        [switch] $NoSwitchOnString,
        [switch] $NoUsingDeclarations,
        [switch] $NoQueryExpressions,
        [switch] $DontClarifySameNameTypes,
        [switch] $UseFullnamespace,
        [switch] $DontUseVariableNamesFromSymbols,
        [switch] $NoObjectOrCollectionInitializers,
        [switch] $NoInlineXmlDocumentation,
        [switch] $DontRemoveEmptyDefaultConstructors,
        [switch] $DontUseIncrementOperators,
        [switch] $DontUseAssignmentExpressions,
        [switch] $AlwaysCreateExceptionVariables,
        [switch] $SortMembers,
        [switch] $ShowTokens,
        [switch] $ShowBytes,
        [switch] $ShowPdbInfo
    )
    begin {
        $dnSpy = Get-Command -CommandType Application -Name dnSpy.Console.exe -ErrorAction Stop

        $argumentList = & {
            if ($NoAnonymousMethods.IsPresent) {
                '--no-anon-methods'
            }

            if ($NoExpressionTrees.IsPresent) {
                '--no-expr-trees'
            }

            if ($NoYield.IsPresent) {
                '--no-yield'
            }

            if ($NoAsync.IsPresent) {
                '--no-async'
            }

            if ($NoAutomaticProperties.IsPresent) {
                '--no-auto-props'
            }

            if ($NoAutomaticEvents.IsPresent) {
                '--no-auto-events'
            }

            if ($NoUsingStatements.IsPresent) {
                '--no-using-stmt'
            }

            if ($NoForEachStatements.IsPresent) {
                '--no-foreach-stmt'
            }

            if ($NoLockStatements.IsPresent) {
                '--no-lock-stmt'
            }

            if ($NoSwitchOnString.IsPresent) {
                '--no-switch-string'
            }

            if ($NoUsingDeclarations.IsPresent) {
                '--no-using-decl'
            }

            if ($NoQueryExpressions.IsPresent) {
                '--no-query-expr'
            }

            if ($DontClarifySameNameTypes.IsPresent) {
                '--no-ambig-full-names'
            }

            if ($UseFullnamespace.IsPresent) {
                '--full-names'
            }

            if ($DontUseVariableNamesFromSymbols.IsPresent) {
                '--use-debug-syms'
            }

            if ($NoObjectOrCollectionInitializers.IsPresent) {
                '--no-obj-inits'
            }

            if ($NoInlineXmlDocumentation.IsPresent) {
                '--no-xml-doc'
            }

            if ($DontRemoveEmptyDefaultConstructors.IsPresent) {
                '--dont-remove-empty-ctors'
            }

            if ($DontUseIncrementOperators.IsPresent) {
                '--no-inc-dec'
            }

            if ($DontUseAssignmentExpressions.IsPresent) {
                '--dont-make-assign-expr'
            }

            if ($AlwaysCreateExceptionVariables.IsPresent) {
                '--always-create-ex-var'
            }

            if ($SortMembers.IsPresent) {
                '--sort-members'
            }

            if ($ShowBytes.IsPresent) {
                '--bytes'
            }

            if ($ShowPdbInfo.IsPresent) {
                '--pdb-info'
            }

            if ($Language -ne 'CSharp') {
                $languageGuid = switch ($Language) {
                    IL { '{a4f35508-691f-4bd0-b74d-d5d5d1d0e8e6}' }
                    CSharp { '{bba40092-76b2-4184-8e81-0f1e3ed14e72}' }
                    VisualBasic { '{a4f35508-691f-4bd0-b74d-d5d5d1d0e8e6}' }
                }

                "-l ""$languageGuid"""
            }

            '--spaces 4'
        }

        if ($argumentList.Count -gt 1) {
            $arguments = $argumentList -join ' '
            return
        }

        $arguments = [string]$argumentList
    }
    process {
        if ($InputObject -is [PSMethod]) {
            $null = $PSBoundParameters.Remove('InputObject')
            return $InputObject.ReflectionInfo | & $MyInvocation.MyCommand @PSBoundParameters
        }

        if ($InputObject -is [type]) {
            $assembly = $InputObject.Assembly
        } else {
            $assembly = $InputObject.DeclaringType.Assembly
        }

        $sb = [StringBuilder]::new([string]$arguments)
        if ($sb.Length -gt 0) {
            $null = $sb.Append(' ')
        }

        if (-not $ShowTokens.IsPresent) {
            $null = $sb.Append('--no-tokens ')
        }

        try {
            # Use the special name accessor as PowerShell ignores property exceptions.
            $metadataToken = $InputObject.get_MetadataToken()
        } catch [InvalidOperationException] {
            $exception = [PSArgumentException]::new(
                ('Unable to get the metadata token of member "{0}". Ensure ' -f $InputObject) +
                'the target is not dynamically generated and then try the command again.',
                $PSItem)

            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    <# exception:     #> $exception,
                    <# errorId:       #> 'CannotGetMetadataToken',
                    <# errorCategory: #> [ErrorCategory]::InvalidArgument,
                    <# targetObject:  #> $InputObject))

            return
        }


        $null = $sb.
            AppendFormat('--md {0} ', $metadataToken).
            AppendFormat('"{0}"', $assembly.Location)

        & ([scriptblock]::Create(('& "{0}" {1}' -f $dnSpy.Source, $sb.ToString())))
    }
}

function Get-CimInstanceFromWmiPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('__PATH', 'TargetInstancePath')]
        [string[]] $Path
    )
    begin {
        $pathRegex = '
            ^\\\\
                (?<ComputerName>[^\\]*)
            \\
                (?<Namespace>[^:]*)
            :
                (?<ClassName>[^=\.]*)
                (?<Separator>\.|(=@))
                (?<KeyValuePairs>.*)?$'
    }
    process {
        foreach ($singlePath in $Path) {
            $match = [regex]::Match(
                $singlePath,
                $pathRegex,
                [RegexOptions]::IgnoreCase -bor
                    [RegexOptions]::IgnorePatternWhitespace -bor
                    [RegexOptions]::CultureInvariant)

            $session = [CimSession]::Create('.')
            $class = $session.GetClass(
                $match.Groups['Namespace'].Value,
                $match.Groups['ClassName'].Value)

            $instance = [ciminstance]::new($class)
            foreach ($pairString in $match.Groups['KeyValuePairs'].Value -split ',') {
                $key, $value = $pairString -split '='
                $prop = $class.CimClassProperties[$key]

                if ($prop.Flags -band 'NullValue') {
                    $flags = $prop.Flags -bxor 'NullValue'
                } else {
                    $flags = $prop.Flags
                }

                $convertedValue = $value -replace '^"|"$'
                if ($prop.CimType -eq 'Boolean') {
                    $successfulParse = $false
                    if ([bool]::TryParse($convertedValue, [ref] $successfulParse)) {
                        $convertedValue = $successfulParse
                    } else {
                        $convertedValue = $convertedValue.ToInt32($null) -as [bool]
                    }
                } else {
                    $convertedValue = $convertedValue -as ([cimconverter]::GetDotNetType($prop.CimType))
                }

                $instance.CimInstanceProperties[$key].Value = $convertedValue
            }

            # yield
            $session.GetInstance(
                $match.Groups['Namespace'].Value,
                $instance)
        }
    }
}

function Get-TypeDefaultValue {
    [Alias('default')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ArgumentCompleter([ClassExplorer.TypeArgumentCompleter])]
        [type] $Type
    )
    end {
        if (-not $Type.IsValueType) {
            return $null
        }

        $PSCmdlet.WriteObject(
            [Activator]::CreateInstance($Type),
            <# enumerateCollection: #> $false)
    }
}

function Watch-EventSubscriber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $SubscriptionCreator
    )
    end {
        $__eventSubscriberId = New-Guid
        $action = {
            $ExecutionContext.Events.GenerateEvent(
                <# sourceIdentifier: #> $__eventSubscriberId,
                <# sender:           #> $Sender,
                <# args:             #> $EventArgs,
                <# extraData:        #> $Event.MessageData)
        }

        $variables = [List[psvariable]]([psvariable]::new('_', $action))
        $subscription = $SubscriptionCreator.InvokeWithContext(@{}, $variables, $action)[0]
        try {
            $subscription.Module.SessionState.PSVariable.Set('__eventSubscriberId', $__eventSubscriberId)
            while ($recieved = Wait-Event -SourceIdentifier $__eventSubscriberId) {
                Remove-Event -SourceIdentifier $recieved.SourceIdentifier
                $PSCmdlet.WriteObject($recieved)
            }
        } finally {
            if ($subscription) {
                Unregister-Event -SourceIdentifier $subscription.Name
            }
        }
    }
}

function Get-OpCode {
    [CmdletBinding()]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete)
            $completer = {
                param($wordToComplete)
                if (-not $script:OpCodes) {
                    $script:OpCodes = & "$PSScriptRoot\OpCodeDescriptions.ps1"
                }

                ,$script:OpCodes.GetEnumerator().
                    Where{ $_.Key -like "$wordToComplete*" }.
                    Key.
                    ForEach([System.Management.Automation.CompletionResult])
            }

            ,(& (Get-Module Utility) $completer $wordToComplete)
        })]
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name
    )
    begin {
        if (-not $script:OpCodes) {
            $script:OpCodes = & "$PSScriptRoot\OpCodeDescriptions.ps1"
        }

        function GetOpCodeForName {
            param([string] $opCodeName)
            end {
                $opCodeName = $opCodeName.Replace('.', '_')
                if ([WildcardPattern]::ContainsWildcardCharacters($opCodeName)) {
                    return $script:OpCodes.GetEnumerator() | Where-Object Key -Like $opCodeName | ForEach-Object {
                        [PSCustomObject]@{
                            Name = $PSItem.Key
                            Description = $PSItem.Value
                            OpCode = [OpCodes]::($PSItem.Key)
                        }
                    }
                }

                return [PSCustomObject]@{
                    Name = $opCodeName
                    Description = $script:OpCodes[$opCodeName]
                    OpCode = [OpCodes]::($opCodeName)
                }
            }
        }
    }
    process {
        if (-not $PSBoundParameters.ContainsKey((nameof{$Name}))) {
            return
        }

        foreach ($aName in $Name) {
            GetOpCodeForName $aName
        }
    }
    end {
        if ($MyInvocation.ExpectingInput -or $PSBoundParameters.ContainsKey((nameof{$Name}))) {
            return
        }

        $script:OpCodes.GetEnumerator().ForEach{
            [PSCustomObject]@{
                Name = $PSItem.Key
                Description = $PSItem.Value
                OpCode = [OpCodes]::($PSItem.Key)
            }
        }
    }
}

function Invoke-PSLambda {
    [Alias('PSLambda')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock] $Body,

        [switch] $EnablePrivateBinding,

        [type[]] $ResolvablePrivateTypes
    )
    end {
        if (-not $EnablePrivateBinding.IsPresent) {
            $toInvoke = { ([psdelegate]$args[0]).Invoke() }
            $internalState = $PSCmdlet.SessionState.GetType().
                GetProperty('Internal', [BindingFlags]'NonPublic, Instance').
                GetValue($PSCmdlet.SessionState)

            $toInvoke.GetType().
                GetProperty('SessionStateInternal', [BindingFlags]'NonPublic, Instance').
                SetValue($toInvoke, $internalState)

            return . $toInvoke $Body
        }

        $binder = Find-Type -FullName PSLambda.MemberBinder -Force |
            Find-Member -MemberType Constructor -ParameterType System.Reflection.BindingFlags |
            ForEach-Object Invoke([BindingFlags]'Public, NonPublic', [string[]]('System.Linq'))

        $visitor = Find-Type -FullName PSLambda.CompileVisitor -Force |
            Find-Member -MemberType Constructor -ParameterType System.Management.Automation.EngineIntrinsics -Force |
            ForEach-Object Invoke($ExecutionContext)

        $null = $visitor | Find-Member _binder -Force | ForEach-Object SetValue $visitor $binder
        $typeAccel = Find-Type -FullName System.Management.Automation.TypeAccelerators -Force
        $existing = $typeAccel::Get
        foreach ($type in $ResolvablePrivateTypes) {
            if ($existing.ContainsKey($type.Name)) {
                continue
            }

            $typeAccel::Add($type.Name, $type)
        }

        $previousFrame = (Get-PSCallStack)[1]
        $localVariables = $null
        if ($previousFrame) {
            $localVariables =
                $previousFrame.GetFrameVariables().Values |
                    Join-After { Get-Variable -Scope Global } |
                    Group-Object Name |
                    ForEach-Object { $PSItem.Group[0].psobject.BaseObject } |
                    ConvertTo-Array -ElementType psvariable

            if ($localVariables -is [psobject]) {
                $localVariables = $localVariables.psobject.BaseObject
            }
        } else {
            # if ($null -eq $PSCmdlet.SessionState.Module) {
            #     $localVariables = (Get-Variable -Scope Global) -as [psvariable[]]
            # } else {
                $flags = [BindingFlags]'Instance, NonPublic'
                $context = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
                $topLevelSessionState = $context.GetType().GetProperty('TopLevelSessionState', $flags).GetValue($context)
                $globalScope = $topLevelSessionState.GetType().GetProperty('GlobalScope', $flags).GetValue($topLevelSessionState)
                $variableTable = $globalScope.GetType().GetProperty('Variables', $flags).GetValue($globalScope)
                $localVariables = [psvariable[]]$variableTable.Values
            # }
        }

        $lambda = $visitor |
            Find-Member CompileAstImpl -Force -Instance -FilterScript { $PSItem.GetParameters().Count -eq 2 } |
            ForEach-Object Invoke $visitor([scriptblock]::Create($Body).Ast, $localVariables)

        $lambda.Compile().Invoke()
    }
}

function Test-NetConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]] $ComputerName,

        [Parameter(Mandatory, ParameterSetName = 'CommonTcpPort', Position = 1)]
        [ValidateSet('HTTP', 'HTTPS', 'RDP', 'SMB', 'WinRM')]
        [string[]] $CommonTcpPort,

        [Parameter(Mandatory, ParameterSetName = 'Port', Position = 1)]
        [int[]] $Port,

        [Parameter(Position = 2)]
        [ValidateSet('IPv4', 'IPv6')]
        [string] $AddressFamily = 'IPv4'
    )
    begin {
        $allTasks = [Dictionary[string, [Tuple[Task, [Dictionary[int, Task]]]]]]::new()
        $family = [AddressFamily]::InterNetwork
        if ($AddressFamily -eq 'IPv6') {
            $family = [AddressFamily]::InterNetworkV6
        }

        $tcpClient = [TcpClient]::new($family)
    }
    process {
        try {
            foreach ($computer in $ComputerName) {
                $infoTask = [Dns]::GetHostEntryAsync($computer)
                while (-not $infoTask.AsyncWaitHandle.WaitOne(200)) { }
                try {
                    $info = $infoTask.GetAwaiter().GetResult()
                } catch {
                    $PSCmdlet.WriteError($PSItem)
                    continue
                }

                $ipAddress = $info.AddressList | Where-Object AddressFamily -eq $family
                if (-not $ipAddress) {
                    $exception = [ItemNotFoundException]::new(
                        'Unable to resolve IP Address for computer "{0}".' -f $computer)

                    $PSCmdlet.WriteError(
                        [ErrorRecord]::new(
                            <# exception:     #> $exception,
                            <# errorId:       #> 'CannotFindIP',
                            <# errorCategory: #> [ErrorCategory]::ObjectNotFound,
                            <# targetObject:  #> $info))
                    continue
                }

                $ping = [Ping]::new()
                $pingTask = $ping.SendPingAsync($ipAddress)
                $portToTask = [Dictionary[int, Task]]::new()
                $allTasks.Add($computer, [Tuple[Task, Dictionary[int, Task]]]::new($pingTask, $portToTask))

                if ($PSCmdlet.ParameterSetName -eq 'CommonTcpPort') {
                    $Port = switch ($CommonTcpPort) {
                        WinRM { 5985 }
                        HTTP { 80 }
                        HTTPS { 443 }
                        SMB { 445 }
                        RDP { 3389 }
                    }
                }

                $tcpClient = [TcpClient]::new($family)
                foreach ($singlePort in $Port) {
                    $portToTask.Add($singlePort, $tcpClient.ConnectAsync($ipAddress, $singlePort))
                }
            }
        } finally {
            if ($PSCmdlet.IsStopping) {
                $tcpClient.Dispose()
            }
        }
    }
    end {
        try {
            foreach ($task in $allTasks.GetEnumerator()) {
                $computer = $task.Key
                $resultInfo = $task.Value
                while (-not $resultInfo.Item1.AsyncWaitHandle.WaitOne(200)) { }
                $result = [PSCustomObject]@{ Icmp = $null }

                try {
                    $pingResult = $resultInfo.Item1.GetAwaiter().GetResult()
                } catch { }

                $result.Icmp = $pingResult

                foreach ($task in $resultInfo.Item2.GetEnumerator()) {
                    $portNumber, $tcpTask = $task.Key, $task.Value
                    while (-not $tcpTask.AsyncWaitHandle.WaitOne(200)) { }

                    try {
                        $tcpResult = $tcpTask.GetAwaiter().GetResult()
                        $tcpStatus = 'Connected'
                    } catch [SocketException] {
                        $tcpStatus = $PSItem.Exception.SocketErrorCode
                    }

                    $result.psobject.Properties.Add(
                        [psnoteproperty]::new(
                            $portNumber,
                            $tcpResult))
                }

                $PSCmdlet.WriteObject($result)
            }
        } finally {
            $tcpClient.Dispose()
        }
    }
}

function Add-NamespaceResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter([ClassExplorer.NamespaceArgumentCompleter])]
        [string[]] $Name
    )
    begin {
        $flags = [BindingFlags]'NonPublic, Instance'
        $context = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
        $globalState = $context.GetType().GetProperty('TopLevelSessionState', $flags).GetValue($context)
        $globalScope = $globalState.GetType().GetProperty('GlobalScope', $flags).GetValue($globalState)
        $resolutionState = $globalScope.GetType().GetProperty('TypeResolutionState', $flags).GetValue($globalScope)
        $currentNamespaces = $resolutionState.GetType().GetField('namespaces', $flags).GetValue($resolutionState)
        $newNamespaces = [List[string]]::new([string[]]$currentNamespaces)
    }
    process {
        if ($null -eq $Name) {
            return
        }

        $newNamespaces.AddRange($Name)
    }
    end {
        $resolutionState.GetType().
            GetField('namespaces', $flags).
            SetValue($resolutionState, $newNamespaces.ToArray())
    }
}

function New-DelegateType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [MethodBase[]] $InputObject
    )
    begin {
        function New-DelegateType {
            param([type[]] $ParameterTypes, [type] $ReturnType = [void], [string[]] $ParameterNames = @())
            end {
                if (-not ($moduleBuilder = $script:DelegateModuleBuilder)) {
                    $assemblyBuilder = [AssemblyBuilder]::DefineDynamicAssembly(
                        [AssemblyName]::new('Dynamic Delegate Assembly'),
                        [AssemblyBuilderAccess]::Run)

                    $moduleBuilder = $assemblyBuilder.DefineDynamicModule('Dynamic Delegate Assembly.dll')
                    $script:DelegateModuleBuilder = $moduleBuilder
                }

                $typeBuilder = $moduleBuilder.DefineType(
                    'GeneratedDelegateTypes.{0}.GeneratedDelegate' -f [guid]::NewGuid().ToString('n'),
                    [TypeAttributes]'NotPublic, Sealed',
                    [MulticastDelegate])

                $methodBuilder = $typeBuilder.DefineMethod(
                    'Invoke',
                    [MethodAttributes]::Public,
                    $ReturnType,
                    $ParameterTypes)

                $methodBuilder.SetImplementationFlags([MethodImplAttributes]::CodeTypeMask)
                for ($i = 0; $i -lt $ParameterNames.Length; $i++) {
                    $null = $methodBuilder.DefineParameter(
                        $i + 1,
                        [ParameterAttributes]::In,
                        $ParameterNames[$i])
                }

                $constructor = $typeBuilder.DefineConstructor(
                    [MethodAttributes]::Public,
                    [CallingConventions]::Any,
                    [type[]]([object], [IntPtr]))

                $constructor.SetImplementationFlags([MethodImplAttributes]::CodeTypeMask)
                $null = $constructor.DefineParameter(1, [ParameterAttributes]::In, 'object')
                $null = $constructor.DefineParameter(2, [ParameterAttributes]::In, 'method')

                return $typeBuilder.CreateType()
            }
        }
    }
    process {
        foreach ($method in $InputObject) {
            $parameters = $method.GetParameters()
            $returnType = $method.ReturnType

            $delegateArguments = new Type[]($parameters.Length + 1)
            for ($i = 0; $i -lt $parameters.Length; $i++) {
                $delegateArguments[$i] = $parameters[$i]
            }

            $delegateArguments[-1] = $returnType
            try {
                $delegateType = [Expression]::GetDelegateType($delegateArguments)
            } catch [ArgumentException] {

            }
        }
    }
}

function ConvertTo-Array {
    [Alias('cast')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [Alias('Type', 'et')]
        [type] $ElementType = [object]
    )
    begin {
        $list = [List`1].MakeGenericType($ElementType)::new(<# capacity: #> 4)
        $enumerableType = [IEnumerable`1].MakeGenericType($ElementType)
    }
    process {
        if ($InputObject -is $ElementType) {
            $list.Add($InputObject)
            return
        }

        if ($InputObject -is $enumerableType) {
            $list.AddRange($InputObject)
            return
        }

        $asSingleItem = $InputObject -as $ElementType
        if ($null -ne $asSingleItem) {
            $list.Add($asSingleItem)
            return
        }

        $enumerator = $null
        try {
            $enumerator = [LanguagePrimitives]::GetEnumerator($InputObject)
            if ($null -ne $enumerator) {
                while ($enumerator.MoveNext()) {
                    $list.Add($enumerator.Current)
                }

                return
            }
        } finally {
            if ($null -ne $enumerator -and $null -ne $enumerator.psobject.Methods['Dispose']) {
                $enumerator.Dispose()
            }
        }

        $list.Add($InputObect)
    }
    end {
        $PSCmdlet.WriteObject(
            $list.ToArray(),
            <# enumerateCollection: #> $false)
    }
}

function Join-After {
    [Alias('append')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $ScriptBlock
    )
    end {
        $input
        & $ScriptBlock
    }
}

function Join-Before {
    [Alias('prepend')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $ScriptBlock
    )
    end {
        & $ScriptBlock
        $input
    }
}

function Get-BaseException {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [int] $Index = 0,

        [Parameter()]
        [switch] $ErrorRecord
    )
    begin {
        function ProcessInputObject([psobject] $obj) {
            $exception = $obj
            if ($exception -is [ErrorRecord]) {
                if ($ErrorRecord.IsPresent) {
                    $exception
                    return
                }

                $exception = $exception.Exception
            }

            if ($exception -isnot [Exception]) {
                Write-Warning ('InputObject "{0}" of type "{1}" was not expected.' -f
                    $exception,
                    $exception.ForEach('GetType')[0])
                return
            }

            $exception.GetBaseException()
        }
    }
    process {
        if ($null -ne $InputObject) {
            ProcessInputObject $InputObject
            return
        }

        if ($MyInvocation.ExpectingInput) {
            return
        }

        $dollarError = Get-Variable -Scope Global Error -ValueOnly
        $targetError = $dollarError[$Index]
        if ($null -eq $targetError) {
            $PSCmdlet.WriteDebug('$Error is not have an error record at index "{0}".' -f $Index)
            return
        }

        ProcessInputObject $targetError
    }
}

function Show-Exception {
    [Alias('se')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [int] $Index = 0,

        [Parameter()]
        [switch] $ErrorRecord
    )
    begin {
        $formatListCommand = $ExecutionContext.InvokeCommand.GetCommand(
            'Microsoft.PowerShell.Utility\Format-List',
            [CommandTypes]::Cmdlet)

        $getExceptionCommand = $ExecutionContext.InvokeCommand.GetCommand(
            'Get-BaseException',
            [CommandTypes]::Function)

        $wrappedCommand = {
            & $getExceptionCommand @PSBoundParameters |
                & $formatListCommand * -Force
        }

        $pipe = $wrappedCommand.GetSteppablePipeline([CommandOrigin]::Internal)
        $pipe.Begin(<# expectingInput: #> $true)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function Show-FullObject {
    [Alias('show')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $formatListCommand = $ExecutionContext.InvokeCommand.GetCmdletByTypeName([FormatListCommand])
        $wrappedCommand = { & $formatListCommand @PSBoundParameters -Property * -Force }
        $pipe = $wrappedCommand.GetSteppablePipeline([CommandOrigin]::Internal)

        try {
            $pipe.Begin($MyInvocation.ExpectingInput)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    process {
        try {
            $pipe.Process($PSItem)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    end {
        try {
            $pipe.End()
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
}

function Test-IcmpConnection {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PSCompterName', 'DnsHostName')]
        [string[]] $ComputerName,

        [ValidateRange(0, [int]::MaxValue)]
        [int] $Timeout = 1000
    )
    begin {
        $taskList = [List[Tuple[string, Task]]]::new()
        $alreadyDone = [HashSet[string]]::new()

        $getSuccess = [psscriptproperty]::new('WasSuccessful', { $this.PingResult.Status -contains 'Success' })
        $getStatus = [psscriptproperty]::new('Status', { $this.PingResult.Status })
        $memberSet = [PSMemberSet]::new(
            'PSStandardMembers',
            [PSMemberInfo[]][PSPropertySet]::new(
                'DefaultDisplayPropertySet',
                [string[]]('ComputerName', 'WasSuccessful')))
    }
    process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) {
                continue
            }

            if (-not $alreadyDone.Add($computer)) {
                continue
            }

            $taskList.Add(
                [Tuple[string, Task]]::new(
                    $computer,
                    [Ping]::new().SendPingAsync(
                        $computer,
                        $Timeout)))
        }
    }
    end {
        $doneCount = 0
        $taskList = $taskList.ToArray()
        while ($doneCount -ne $taskList.Length) {
            for ($i = 0; $i -lt $taskList.Length; $i++) {
                if ($null -eq $taskList[$i] -or -not $taskList[$i].Item2.IsCompleted) {
                    continue
                }

                $pingException = $null
                try {
                    $result = $taskList[$i].Item2.GetAwaiter().GetResult()
                } catch {
                    $result = $null
                    $pingException = $PSItem
                }

                $resultObj = [PSCustomObject]@{
                    ComputerName = $taskList[$i].Item1
                    PingResult = $result
                    Error = $pingException
                }

                $resultObj.psobject.Properties.Add($getSuccess)
                $resultObj.psobject.Properties.Add($getStatus)
                $resultObj.psobject.Members.Add($memberSet)

                # yield
                $resultObj

                $taskList[$i] = $null
                $doneCount++
            }

            Start-Sleep -Milliseconds 200
        }
    }
}

function ConvertTo-String {
    [Alias('ToString')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    process {
        if ($null -eq $InputObject) {
            return
        }

        return [LanguagePrimitives]::ConvertTo(
            $InputObject,
            [string],
            [cultureinfo]::InvariantCulture)
    }
}

function Show-Timer {
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Date')]
    param(
        [Parameter(ParameterSetName = 'Date', Position = 0, Mandatory)]
        [datetime] $Time,

        [Parameter(ParameterSetName = 'Time')]
        [int] $Days,

        [Parameter(ParameterSetName = 'Time')]
        [int] $Hours,

        [Parameter(ParameterSetName = 'Time')]
        [int] $Minutes,

        [Parameter(ParameterSetName = 'Time')]
        [int] $Seconds,

        [Parameter(ParameterSetName = 'Span', ValueFromPipeline, Mandatory)]
        [ValidateNotNull()]
        [timespan] $TimeSpan,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('f')]
        [string] $Format = 'hh\:mm\:ss',

        [Parameter()]
        [ValidateRange(200, [int]::MaxValue)]
        [int] $UpdateIntervalMilliseconds = 1000
    )
    process {
        $TimeSpan = switch ($PSCmdlet.ParameterSetName) {
            Span { $TimeSpan }
            Date { New-TimeSpan -Start (Get-Date) -End $Time }
            Time { New-TimeSpan -Days $Days -Hours $Hours -Minutes $Minutes -Seconds $Seconds }
        }

        $e = [char]27
        $Host.UI.Write("$e[1L")

        $stopwatch = [Stopwatch]::StartNew()
        while ($true) {
            $timeLeft = $TimeSpan - $stopwatch.Elapsed
            if ($timeLeft.TotalMilliseconds -le 0) {
                return
            }

            $Host.UI.Write($timeLeft.ToString($Format))
            Start-Sleep -Milliseconds $UpdateIntervalMilliseconds
            $Host.UI.Write("$e[1G$e[1K")
        }
    }
}

function Wait-AsyncResult {
    [Alias('await')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject[]] $InputObject
    )
    begin {
        if (-not $VoidTaskType) {
            $script:VoidTaskType = $VoidTaskType = [Task`1].MakeGenericType([Task]::Delay(1).Result.GetType())
        }

        $tasksToAwait = $null
        $otherAsyncResults = $null
    }
    process {
        foreach ($awaitable in $InputObject) {
            if ($awaitable -is [Task]) {
                if ($null -eq $tasksToAwait) {
                    $tasksToAwait = [List[Task]]::new()
                }

                $tasksToAwait.Add($awaitable)
                continue
            }

            if ($null -eq $otherAsyncResults) {
                $otherAsyncResults = [List[IAsyncResult]]::new()
            }

            if ($awaitable -isnot [IAsyncResult]) {
                $exception = [PSArgumentException]::new(
                    'The specified value does not implement the interface "IAsyncResult".')

                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        <# exception:     #> $exception,
                        <# errorId:       #> 'InputNotAwaitable',
                        <# errorCategory: #> [ErrorCategory]::InvalidArgument,
                        <# targetObject:  #> $awaitable))
                continue
            }

            $otherAsyncResults.Add($awaitable)
        }
    }
    end {
        if ($null -ne $tasksToAwait) {
            $task = [Task]::WhenAll($tasksToAwait)
            while (-not $task.AsyncWaitHandle.WaitOne(200)) { }
            foreach ($singleTask in $tasksToAwait) {
                if ($singleTask -is $voidTaskType) {
                    $null = $singleTask.GetAwaiter().GetResult()
                    continue
                }

                # yield
                $singleTask.GetAwaiter().GetResult()
            }
        }

        foreach ($singleAwaitable in $otherAsyncResults) {
            while (-not $singleAwaitable.AsyncWaitHandle.WaitOne(200)) { }
        }
    }
}

function Get-ResourceInfo {
    [CmdletBinding(DefaultParameterSetName = 'Assembly')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Assembly')]
        [Assembly[]] $Assembly,

        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'String')]
        [string[]] $AssemblyName
    )
    begin {
        $resultFrame = [PSCustomObject]@{
            Assembly = $null
            Resource = [string]::Empty
            Key = [string]::Empty
            Value = $null
        }

        $resultFrame.psobject.Members.Add(
            [PSMemberSet]::new(
                'PSStandardMembers',
                [PSMemberInfo[]](
                    [PSPropertySet]::new(
                        'DefaultDisplayPropertySet',
                        [string[]]('Key', 'Value')))))

        $loadedAssemblyCache = $null
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'String') {
            if ($null -eq $loadedAssemblyCache) {
                $loadedAssemblyCache = [Dictionary[string, Assembly]]::new([StringComparer]::OrdinalIgnoreCase)
                foreach ($singleAssembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
                    $loadedAssemblyCache.Add($singleAssembly.GetName().Name, $singleAssembly)
                }
            }

            $Assembly = [Assembly[]]::new($AssemblyName.Length)
            for ($i = 0; $i -lt $AssemblyName.Length; $i++) {
                $foundAssembly = $null
                if ($loadedAssemblyCache.TryGetValue($AssemblyName[$i], [ref] $foundAssembly)) {
                    $Assembly[$i] = $foundAssembly
                    continue
                }

                $exception = [PSArgumentException]::new(
                    'The assembly "{0}" could not be found.' -f $AssemblyName[$i])
                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        <# exception:     #> $exception,
                        <# errorId:       #> 'AssemblyNotFound',
                        <# errorCategory: #> [ErrorCategory]::ObjectNotFound,
                        <# targetObject:  #> $AssemblyName[$i]))
            }
        }

        foreach ($singleAssembly in $Assembly) {
            if ($null -eq $singleAssembly) {
                continue
            }

            $manifestNames = $singleAssembly.GetManifestResourceNames()
            foreach ($name in $manifestNames) {
                $manager = [ResourceManager]::new(
                    $name -replace '\.resources$',
                    $singleAssembly)

                $resourceSet = $null
                try {
                    $resourceSet = $manager.GetResourceSet(
                        [cultureinfo]::InvariantCulture,
                        $true,
                        $true)

                    foreach ($keyValue in $resourceSet.GetEnumerator()) {
                        $result = $resultFrame.psobject.Copy()
                        $result.Assembly = $singleAssembly
                        $result.Resource = $name
                        $result.Key = $keyValue.Key
                        $result.Value = $keyValue.Value

                        $PSCmdlet.WriteObject($result, <# enumerateCollection: #> $false)
                    }
                } finally {
                    if ($null -ne $resourceSet) {
                        $resourceSet.Dispose()
                    }
                }
            }
        }
    }
}

function Get-NativeExport {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )
    begin {
        if ($null -eq $PSVersionTable.PSEdition -or $PSVersionTable.PSEdition -eq 'Desktop') {
            $exception = [PSNotSupportedException]::new(
                'This command must be invoked from PowerShell Core currently.')
            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    <# exception:     #> $exception,
                    <# errorId:       #> 'InvalidRuntime',
                    <# errorCategory: #> [ErrorCategory]::InvalidOperation,
                    <# targetObject:  #> $null))
            return
        }

        $LibraryNameRvaOffset = 12
        $NameCountOffset = 24
        $NameTableRvaOffset = 32
    }
    process {
        $provider = $null
        $Path = $PSCmdlet.GetResolvedProviderPathFromPSPath(
            $Path,
            [ref] $provider)

        if ($provider.Name -ne [FileSystemProvider]::ProviderName) {
            throw 'The specified path does not resolve to a file system path.'
        }

        $stream = $null
        $peReader = $null
        try {
            $stream = [FileStream]::new(
                $Path,
                [FileMode]::Open,
                [FileAccess]::Read,
                [FileShare]'ReadWrite, Delete')

            $peReader = [PEReader]::new($stream)
            $exportTable = $peReader.PEHeaders.PEHeader.ExportTableDirectory
            $exportData = $peReader.GetSectionData($exportTable.RelativeVirtualAddress)
            $exportReader = $exportData.GetReader(0, $exportTable.Size)
            $exportReader.Offset = $LibraryNameRvaOffset
            $libNameReader = $peReader.GetSectionData($exportReader.ReadInt32()).GetReader()
            $libNameBytes = $libNameReader.ReadBytes($libNameReader.IndexOf(0) + 1)
            $libName = [Encoding]::ASCII.GetString($libNameBytes)

            $exportReader.Offset = $NameCountOffset
            $nameCount = $exportReader.ReadInt32()
            $exportReader.Offset = $NameTableRvaOffset
            $nameTableData = $peReader.GetSectionData($exportReader.ReadInt32())
            $nameRvaReader = $nameTableData.GetReader(0, $nameCount * 8)

            for ($i = 0; $i -lt $nameCount; $i++ ) {
                $nameReader = $peReader.GetSectionData($nameRvaReader.ReadInt32()).GetReader()
                $offset = $nameReader.IndexOf(0)

                # yield
                [PSCustomObject]@{
                    PSTypeName = 'PEExport'
                    Parent = $libName
                    Name = [Encoding]::ASCII.GetString($nameReader.ReadBytes($offset + 1))
                }
            }
        } finally {
            if ($null -ne $peReader) {
                $peReader.Dispose()
            }

            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
}

function Use-Location {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNull()]
        [scriptblock] $Action
    )
    end {
        $oldStackCount = $PSCmdlet.SessionState.Path.LocationStack([string]::Empty).Count
        try {
            Push-Location $Path -ErrorAction Stop
            . $Action
        } catch {
            $PSCmdlet.WriteError($PSItem)
        } finally {
            # Compare the stack count taken before the try to the one taken after.
            # I do this incase Push-Location fails, or otherwise does not run due to pipeline
            # stop requests.
            $newStackCount = $PSCmdlet.SessionState.Path.LocationStack([string]::Empty).Count
            if ($newStackCount - 1 -eq $oldStackCount) {
                Pop-Location
            }
        }
    }
}

function Invoke-Setup {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Position = 1)]
        [object[]] $ArgumentList,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory
    )
    end {
        $cmdlet = $PSCmdlet
        try {
            if ($Path.Contains([char][Path]::DirectorySeparatorChar) -or $Path.Contains([char][Path]::AltDirectorySeparatorChar)) {
                $setupFile = (Get-Item $Path -ErrorAction Stop).FullName
            } else {
                $setupFile = (Get-Command $Path -CommandType Application -ErrorAction Stop).Source
            }

            if ($PSBoundParameters.ContainsKey((nameof{$WorkingDirectory}))) {
                $WorkingDirectory = (Resolve-Path $WorkingDirectory -ErrorAction Stop).ProviderPath
            } else {
                $WorkingDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
            return
        }

        $body = {
            $proc = Start-Process -FilePath $setupFile -ArgumentList $ArgumentList -PassThru
            while (-not $proc.WaitForExit(200)) { }
            if (0 -eq $proc.ExitCode) {
                return
            }

            $cmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    <# exception:     #> [Win32Exception]::new($proc.ExitCode),
                    <# errorId:       #> 'NonZeroSetupExitCode',
                    <# errorCategory: #> [ErrorCategory]::InvalidOperation,
                    <# targetObject:  #> $proc.ExitCode))
        }

        if ($PSBoundParameters.ContainsKey((nameof{$WorkingDirectory}))) {
            Use-Location $WorkingDirectory $body
            return
        }

        & $body
    }
}

function Format-Column {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 2147483647)]
        [int] $Column = 2,

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        try {
            if ($PSBoundParameters.ContainsKey('OutBuffer')) {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $invokeCommand = $ExecutionContext.InvokeCommand
            $formatDefault = $invokeCommand.GetCmdletByTypeName([FormatDefaultCommand])
            $formatWide = $invokeCommand.GetCmdletByTypeName([FormatWideCommand])
            $selectObject = $invokeCommand.GetCmdletByTypeName([SelectObjectCommand])
            $outString = $invokeCommand.GetCmdletByTypeName([OutStringCommand])
            $removeFormatHeader = {
                [CmdletBinding()]
                param(
                    [Parameter(ValueFromPipeline)]
                    [object] $InputObject
                )
                process {
                    if ($false -eq $InputObject.shapeInfo.hideHeader) {
                        $InputObject.shapeInfo.hideHeader = $true
                    }

                    if ($null -ne $InputObject.groupingEntry) {
                        $InputObject.groupingEntry = $null
                    }

                    return $InputObject
                }
            }

            if ($PSBoundParameters.ContainsKey((nameof{$Column}))) {
                $null = $PSBoundParameters.Remove((nameof{$Column}))
            }

            $scriptCmd = {
                & $formatDefault @PSBoundParameters |
                    & $removeFormatHeader |
                    & $outString -Stream |
                    & $selectObject @{ Name = 'TempProperty'; Expression = { $PSItem }} |
                    & $formatWide -Column $Column
            }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    process {
        try {
            $steppablePipeline.Process($PSItem)
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    end {
        try {
            $steppablePipeline.End()
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

function Format-Default {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        try {
            if ($PSBoundParameters.ContainsKey('OutBuffer')) {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCmdletByTypeName([FormatDefaultCommand])
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($MyInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    process {
        try {
            $steppablePipeline.Process($PSItem)
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    end {
        try {
            $steppablePipeline.End()
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

function Invoke-Conditional {
    [Alias('??')]
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'WithDecoration')]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $Then,

        [Parameter(DontShow, Position = 1, ParameterSetName = 'WithDecoration')]
        [ValidateSet(':', 'else')]
        [string] $Decoration,

        [Parameter(Position = 2, ParameterSetName = 'WithDecoration')]
        [Parameter(Position = 1, ParameterSetName = 'WithoutDecoration')]
        [ValidateNotNull()]
        [scriptblock] $Else,

        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [psobject] $If
    )
    begin {
        $firstObject = $null
        $hasSetFirstObject = $false
        $pipelineInputCount = 0

        $dollarUnder = [psvariable]::new('_')
        $variableList = [List[psvariable]]::new(<# capacity: #> 1)
        $variableList.Add($dollarUnder)

        if ($PSBoundParameters.ContainsKey((nameof{$Then})) -and $PSBoundParameters.ContainsKey((nameof{$Else}))) {
            $onFalse = $Else
            $onTrue = $Then
            return
        }

        if ($PSBoundParameters.ContainsKey((nameof{$Else}))) {
            $onFalse = $Else
            $onTrue = $null
            return
        }

        if ($PSBoundParameters.ContainsKey((nameof{$Then}))) {
            $onFalse = $Then
            $onTrue = $null
            return
        }

        $exception = [PSArgumentException]::new(
            'At least one action must be specified. Please specify a value for the ' +
            'parameter "Then", "Else", or both and then try the command again')

        $PSCmdlet.ThrowTerminatingError(
            [ErrorRecord]::new(
                <# exception:     #> $exception,
                <# errorId:       #> 'NoActionSpecified',
                <# errorCategory: #> [ErrorCategory]::InvalidArgument,
                <# targetObject:  #> $null))
    }
    process {
        if (-not $hasSetFirstObject) {
            $firstObject = $If
            $hasSetFirstObject = $true
        }

        $pipelineInputCount++
    }
    end {
        $isTrue = $pipelineInputCount -gt 1 -or ($pipelineInputCount -eq 1 -and $firstObject)

        if ($isTrue) {
            if ($null -ne $onTrue) {
                & $onTrue
            }

            return
        }

        return & $onFalse
    }
}

$script:WellKnownNumericTypes = [type[]](
    [byte],
    [sbyte],
    [int16],
    [uint16],
    [int],
    [uint32],
    [int64],
    [uint64],
    [single],
    [double],
    [decimal],
    [bigint])

function ConvertTo-Number {
    [Alias('number')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline, Position = 0)]
        [psobject] $InputObject
    )
    process {
        foreach ($currentItem in $InputObject) {
            if ($null -eq $currentItem) {
                <# yield #> 0
                continue
            }

            if ($currentItem -is [Enum]) {
                <# yield #> $currentItem.value__
                continue
            }

            if ([array]::IndexOf($script:WellKnownNumericTypes, $currentItem.GetType()) -eq -1) {
                $result = $null
                if ([LanguagePrimitives]::TryConvertTo($currentItem, [int], [ref] $result)) {
                    <# yield #> $result
                    continue
                }

                if ([LanguagePrimitives]::TryConvertTo($currentItem, [long], [ref] $result)) {
                    <# yield #> $result
                    continue
                }

                if ([LanguagePrimitives]::TryConvertTo($currentItem, [System.Numerics.BigInteger], [ref] $result)) {
                    <# yield #> $result
                    continue
                }

                $currentItem -as [int]
                continue
            }

            <# yield #> $currentItem
        }
    }
}

function ConvertTo-HexString {
    [Alias('hex')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject[]] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Padding
    )
    process {
        foreach ($currentItem in $InputObject) {
            $numeric = number $currentItem

            if ($PSBoundParameters.ContainsKey((nameof{$Padding}))) {
                "0x{0:X$Padding}" -f $numeric
                continue
            }

            '0x{0:X}' -f $numeric
        }
    }
}

function ConvertTo-Decimal {
    [CmdletBinding()]
    [OutputType([decimal])]
    [Alias('decimal')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([decimal])
        }
    }
}

function ConvertTo-Double {
    [CmdletBinding()]
    [OutputType([double])]
    [Alias('double')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([double])
        }
    }
}

function ConvertTo-Single {
    [CmdletBinding()]
    [OutputType([single])]
    [Alias('single')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([single])
        }
    }
}

function ConvertTo-UInt64 {
    [CmdletBinding()]
    [OutputType([ulong])]
    [Alias('ulong')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([ulong])
        }
    }
}

function ConvertTo-Int64 {
    [CmdletBinding()]
    [OutputType([long])]
    [Alias('long')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([long])
        }
    }
}

function ConvertTo-UInt32 {
    [CmdletBinding()]
    [OutputType([uint])]
    [Alias('uint')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([uint])
        }
    }
}

function ConvertTo-Int32 {
    [CmdletBinding()]
    [OutputType([int])]
    [Alias('int')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([int])
        }
    }
}

function ConvertTo-UInt16 {
    [CmdletBinding()]
    [OutputType([ushort])]
    [Alias('ushort')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([ushort])
        }
    }
}

function ConvertTo-Int16 {
    [CmdletBinding()]
    [OutputType([short])]
    [Alias('short')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([short])
        }
    }
}

function ConvertTo-Byte {
    [CmdletBinding()]
    [OutputType([byte])]
    [Alias('byte')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([byte])
        }
    }
}

function ConvertTo-SByte {
    [CmdletBinding()]
    [OutputType([sbyte])]
    [Alias('sbyte')]
    param([Parameter(ValueFromPipeline)][psobject] $InputObject)
    process {
        foreach ($currentItem in $InputObject) {
            Convert-Object -InputObject $currentItem -Type ([sbyte])
        }
    }
}


function ConvertTo-Char {
    [Alias('char')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    process {
        foreach ($currentItem in $InputObject) {
            if ($currentItem -is [string]) {
                # yield
                $currentItem.ToCharArray()
                continue
            }

            # yield
            Convert-Object -InputObject $currentItem -Type ([char])
        }
    }
}

function Convert-Object {
    [Alias('convert', 'cast')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [ArgumentCompleter([ClassExplorer.TypeArgumentCompleter])]
        [type] $Type
    )
    process {
        if ($null -eq $InputObject) {
            return
        }

        $convertedValue = default($Type)
        if ([LanguagePrimitives]::TryConvertTo($InputObject, $Type, [ref] $convertedValue)) {
            return $convertedValue
        }
    }
}

function ConvertTo-BitString {
    [Alias('bits')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject[]] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Padding,

        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [string] $ByteSeparator = ' ',

        [Parameter(Position = 2)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [string] $HalfByteSeparator = '.'
    )
    begin {
        $toBytes = [psdelegate]{
            ($a) => { [MemoryMarshal]::AsBytes([MemoryExtensions]::AsSpan($a)).ToArray() }
        }

        function GetBinaryString([psobject] $item) {
            $numeric = number $item
            if ($null -eq $numeric) {
                return
            }

            $ep = [ScriptPosition]::new('', 0, 0, '', '')
            $ee = [ScriptExtent]::new($ep, $ep)

            $delegateType = [Func`2].MakeGenericType(
                $numeric.GetType().MakeArrayType(),
                [byte[]])

            $toBytesCompiled = $toBytes -as $delegateType
            $bytes = $toBytesCompiled.Invoke($numeric)
            [array]::Reverse($bytes)

            $bits = [convert]::ToString($numeric, <# toBase: #> 2)
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey((nameof{$Padding}))) {
                $padAmount = $Padding * 8
                if ($padAmount -ge $bits.Length) {
                    return $bits.PadLeft($Padding * 8, [char]'0')
                }
            }

            $padAmount = 8 - ($bits.Length % 8)
            if ($padAmount -eq 8) {
                return $bits
            }

            return $bits.PadLeft($padAmount + $bits.Length, [char]'0')
        }
    }
    process {
        foreach ($currentItem in $InputObject) {
            $binaryString = GetBinaryString $currentItem

            # yield
            $binaryString -replace
                '[01]{8}(?=.)', "`$0$ByteSeparator" -replace
                '[01]{4}(?=[01])', "`$0$HalfByteSeparator"
        }
    }
}

function Select-FirstObject {
    [Alias('first', 'top')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Count = 1
    )
    begin {
        $amountProcessed = 0
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        # yield
        $InputObject

        $amountProcessed++
        if ($amountProcessed -ge $Count) {
            EnsureCommandStopperInitialized
            [UtilityProfile.CommandStopper]::Stop($PSCmdlet)
        }
    }
}

function Select-LastObject {
    [Alias('last')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Count = 1
    )
    begin {
        if ($Count -eq 1) {
            $objStore = $null
            return
        }

        $objStore = [psobject[]]::new($Count)
        $currentIndex = 0
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($Count -eq 1) {
            $objStore = $InputObject
            return
        }

        $objStore[$currentIndex] = $InputObject
        $currentIndex++
        if ($currentIndex -eq $objStore.Length) {
            $currentIndex = 0
        }
    }
    end {
        if ($Count -eq 1) {
            return $objStore
        }

        for ($i = $currentIndex; $i -lt $objStore.Length; $i++) {
            # yield
            $objStore[$i]
        }

        for ($i = 0; $i -lt $currentIndex; $i++) {
            # yield
            $objStore[$i]
        }
    }
}

function Select-ObjectIndex {
    [Alias('at')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0, Mandatory)]
        [int] $Index
    )
    begin {
        $currentIndex = 0
        $lastPipe = $null
        $isIndexNegative = $Index -lt 0

        if ($isIndexNegative) {
            $lastParams = @{
                Count = $Index * -1
            }

            $lastPipe = { Select-LastObject @lastParams }.GetSteppablePipeline([CommandOrigin]::Internal)
            $lastPipe.Begin($MyInvocation.ExpectingInput)
        }
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        if (-not $isIndexNegative) {
            if ($currentIndex -eq $Index) {
                # yield
                $InputObject
                EnsureCommandStopperInitialized
                [UtilityProfile.CommandStopper]::Stop($PSCmdlet)
            }

            $currentIndex++
            return
        }

        $lastPipe.Process($PSItem)
    }
    end {
        if ($null -ne $lastPipe) {
            # yield
            $lastPipe.End() | Select-Object -First 1
        }
    }
}

function Skip-Object {
    [Alias('skip')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Count = 1,

        [switch] $Last
    )
    begin {
        $currentIndex = 0
        if ($Last) {
            $buffer = [List[psobject]]::new()
        }
    }
    process {
        if ($Last) {
            $buffer.Add($InputObject)
            return
        }

        if ($currentIndex -ge $Count) {
            # yield
            $InputObject
        }

        $currentIndex++
    }
    end {
        if (-not $Last) {
            return
        }

        return $buffer[0..($buffer.Count - $Count - 1)]
    }
}

function Skip-LastObject {
    [Alias('skiplast')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Count = 1
    )
    begin {
        $pipe = { Skip-Object -Last @PSBoundParameters }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($MyInvocation.ExpectingInput)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function ConvertTo-Base64String {
    [Alias('base', 'base64')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $InputObject,

        [Parameter()]
        [ArgumentCompleter([EncodingArgumentCompleter])]
        [EncodingArgumentConverter()]
        [Encoding] $Encoding
    )
    begin {
        if ($PSBoundParameters.ContainsKey((nameof{$Encoding}))) {
            $userEncoding = $Encoding
            return
        }

        $userEncoding = [Encoding]::Unicode
    }
    process {
        if ([string]::IsNullOrEmpty($InputObject)) {
            return
        }

        return [convert]::ToBase64String($userEncoding.GetBytes($InputObject))
    }
}

function Get-ElementName {
    [Alias('nameof')]
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidateNotNull()]
        [ScriptBlock] $Expression
    )
    end {
        if ($Expression.Ast.EndBlock.Statements.Count -eq 0) {
            return
        }

        $firstElement = $Expression.Ast.EndBlock.Statements[0].PipelineElements[0]
        if ($firstElement.Expression.VariablePath.UserPath) {
            return $firstElement.Expression.VariablePath.UserPath
        }

        if ($firstElement.Expression.Member) {
            return $firstElement.Expression.Member.SafeGetValue()
        }

        if ($firstElement.GetCommandName) {
            return $firstElement.GetCommandName()
        }

        if ($firstElement.Expression.TypeName.FullName) {
            return $firstElement.Expression.TypeName.FullName
        }
    }
}

function Get-EnumInfo {
    [Alias('enum')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $alreadyProcessed = $null
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($null -eq $alreadyProcessed -and $MyInvocation.ExpectingInput) {
            $alreadyProcessed = [HashSet[type]]::new()
        }

        $enumType = $InputObject.psobject.BaseObject
        if (-not ($enumType -is [Type] -and $enumType.IsEnum)) {
            $enumType = $enumType.GetType()
        }

        if (-not ($enumType -is [Type] -and $enumType.IsEnum)) {
            return
        }

        if ($MyInvocation.ExpectingInput -and -not $alreadyProcessed.Add($enumType)) {
            return
        }

        $names = [enum]::GetNames($enumType)
        $values = [enum]::GetValues($enumType)

        $lastBits = bits -InputObject $values[-1]
        $bitsPadding = ($lastBits -replace '[\. ]').Length / 8
        $hexPadding = (hex -InputObject $values[-1]).Length - 2
        for ($i = 0; $i -lt $names.Length; $i++) {
            $value = $values[$i].value__
            $info = [PSCustomObject]@{
                PSTypeName = 'UtilityProfile.EnumValueInfo'
                EnumType = $enumType
                Name = $names[$i]
                Value = $value
                Hex = hex -InputObject $value -Padding $hexPadding
                Bits = bits -InputObject $value -Padding $bitsPadding
            }

            $info.psobject.Members.Add(
                [PSMemberSet]::new(
                    'PSStandardMembers',
                    [PSMemberInfo[]](
                        [PSPropertySet]::new(
                            'DefaultDisplayPropertySet',
                            [string[]]('Name', 'Value', 'Hex', 'Bits')))))

            # yield
            $info
        }
    }
}

function Edit-String {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $InputObject
    )
    begin {
        $outString = $ExecutionContext.InvokeCommand.GetCmdletByTypeName([OutStringCommand])
        $pipe = { & $outString @PSBoundParameters -Width 9999 }.GetSteppablePipeline([CommandOrigin]::Internal)
        try {
            $pipe.Begin($MyInvocation.ExpectingInput)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    process {
        try {
            $pipe.Process($PSItem)
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    end {
        $result = $null
        try {
            $result = $pipe.End().Where($null, 'First')[0]
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }

        if ([string]::IsNullOrEmpty($result)) {
            return
        }

        $utf8NoBOM = [UTF8Encoding]::new(<# encoderShouldEmitUTF8Identifier: #> $false)
        $tempFile = $null
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $stream = $writer = $null
            try {
                $stream = [FileStream]::new(
                    $tempFile,
                    [FileMode]::Open,
                    [FileAccess]::Write,
                    [FileShare]::None)

                $writer = [StreamWriter]::new($stream, $utf8NoBOM)
                $writer.Write($result)
                $writer.Flush()
                $stream.Flush()
            } finally {
                if ($null -ne $writer) {
                    $writer.Dispose()
                }

                if ($null -ne $stream) {
                    $stream.Dispose()
                }
            }

            $ps = $null
            try {
                # Using AddCommand instead of AddScript here messes with the display
                # for some reason. Trying to get interactive commands to work mid
                # script is a challenge.
                $ps = [PowerShell]::
                    Create([RunspaceMode]::CurrentRunspace).
                    AddScript('& $env:EDITOR $args[0]').
                    AddArgument($tempFile).
                    AddCommand('Microsoft.PowerShell.Core\Out-Default')

                # Another interactive-command-mid-script oddity. Not needed if you
                # just invoke vim from the prompt, but mid script unicode characters
                # get destroyed without this.
                $oldPSOutput = $OutputEncoding
                $oldOutput = [Console]::OutputEncoding
                $oldInput = [Console]::InputEncoding
                try {
                    $OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = $utf8NoBOM
                    $null = $ps.Invoke()
                } finally {
                    $OutputEncoding = $oldPSOutput
                    [Console]::OutputEncoding = $oldOutput
                    [Console]::InputEncoding = $oldInput
                }
            } finally {
                if ($null -ne $ps) {
                    $ps.Dispose()
                }
            }

            return [File]::ReadAllText($tempFile)
        } finally {
            if (-not [string]::IsNullOrEmpty($tempFile) -and [File]::Exists($tempFile)) {
                [File]::Delete($tempFile)
            }
        }
    }
}

function Get-EnvironmentVariable {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [SupportsWildcards()]
        [string] $Name,

        [Parameter()]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )
    begin {
        $alreadyProcessed = $null

        $caseSensitive = [Environment]::GetEnvironmentVariables($Scope)
        $variables = [Dictionary[string, ValueTuple[string, string]]]::new(
            $caseSensitive.Count,
            [StringComparer]::OrdinalIgnoreCase)

        foreach ($kvp in $caseSensitive.GetEnumerator()) {
            $variables.Add(
                $kvp.Key,
                [ValueTuple]::Create($kvp.Key, $kvp.Value))
        }
    }
    process {
        if (-not $PSBoundParameters.ContainsKey((nameof{$Name})) -or [string]::IsNullOrEmpty($Name)) {
            return
        }

        if ($null -eq $alreadyProcessed) {
            $alreadyProcessed = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        }

        if (-not [WildcardPattern]::ContainsWildcardCharacters($Name)) {
            $value = default([ValueTuple[string, string]])
            if ($variables.TryGetValue($Name, [ref] $value)) {
                return [PSCustomObject]@{
                    PSTypeName = 'UtilityProfile.EnvironmentVariable'
                    Name = $value.Item1
                    Value = $value.Item2
                    Scope = $Scope
                }
            }

            $exception = [PSArgumentException]::new(
                "Cannot find environment variable '{0}' because it does not exist." -f $Name,
                (nameof{$Name}))

            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    <# exception:     #> $exception,
                    <# errorId:       #> 'EnvVarNotFound',
                    <# errorCategory: #> [ErrorCategory]::ObjectNotFound,
                    <# targetObject:  #> $Name))

            return
        }

        foreach ($kvp in $variables.GetEnumerator()) {
            if ($kvp.Key -like $Name -and $alreadyProcessed.Add($kvp.Name)) {
                return [PSCustomObject]@{
                    PSTypeName = 'UtilityProfile.EnvironmentVariable'
                    Name = $kvp.Value.Item1
                    Value = $kvp.Value.Item2
                    Scope = $Scope
                }
            }
        }
    }
    end {
        if ($MyInvocation.ExpectingInput -or $PSBoundParameters.ContainsKey((nameof{$Name}))) {
            return
        }

        foreach ($kvp in $variables.GetEnumerator()) {
            return [PSCustomObject]@{
                PSTypeName = 'UtilityProfile.EnvironmentVariable'
                Name = $kvp.Value.Item1
                Value = $kvp.Value.Item2
                Scope = $Scope
            }
        }
    }
}

function Set-EnvironmentVariable {
    [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [Alias('Name', 'Variable')]
        [AllowNull()]
        [SupportsWildcards()]
        [psobject] $InputObject,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Value,

        [Parameter()]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )
    begin {
        $isScopeSet = $PSBoundParameters.ContainsKey((nameof{$Scope}))
        $shouldProcess = {
            param([string] $name) end {
                return $PSCmdlet.ShouldProcess("$name=$Value", 'Set Environment Variable')
            }
        }
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        foreach ($obj in $InputObject) {
            if ($obj.PSTypeNames.Contains('UtilityProfile.EnvironmentVariable')) {
                if (& $shouldProcess $obj.Name) {
                    $scopeToUse = $obj.Scope
                    if ($isScopeSet) {
                        $scopeToUse = $Scope
                    }

                    [Environment]::SetEnvironmentVariable(
                        $obj.Name,
                        $Value,
                        $scopeToUse)
                }

                continue
            }

            if ($obj -is [string]) {
                if (& $shouldProcess $obj) {
                    [Environment]::SetEnvironmentVariable(
                        $obj,
                        $Value,
                        $Scope)
                }

                continue
            }

            $name = [string]$obj
            if (-not (& $shouldProcess $name)) {
                continue
            }

            [Environment]::SetEnvironmentVariable(
                $name,
                $Value,
                $obj.Scope)
        }
    }
}

function Get-PathEntry {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [SupportsWildcards()]
        [string] $Name,

        [Parameter()]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )
    begin {
        $entries = [Environment]::GetEnvironmentVariable('PATH', $Scope) -split [Path]::PathSeparator
        $alreadyProcessed = $null
    }
    process {
        if (-not $PSBoundParameters.ContainsKey((nameof{$Name})) -or [string]::IsNullOrEmpty($Name)) {
            return
        }

        if ($null -eq $alreadyProcessed) {
            $alreadyProcessed = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        }


    }
}

class IsSafeDisposableFactoryVisitor : ICustomAstVisitor2 {
    hidden [bool] $_hasSeenInitialScriptBlockAst;

    [object] VisitTypeDefinition([TypeDefinitionAst] $typeDefinitionAst) { return $false }

    [object] VisitPropertyMember([PropertyMemberAst] $propertyMemberAst) { return $false }

    [object] VisitFunctionMember([FunctionMemberAst] $functionMemberAst) { return $false }

    [object] VisitBaseCtorInvokeMemberExpression([BaseCtorInvokeMemberExpressionAst] $baseCtorInvokeMemberExpressionAst) { return $false }

    [object] VisitUsingStatement([UsingStatementAst] $usingStatement) { return $false }

    [object] VisitConfigurationDefinition([ConfigurationDefinitionAst] $configurationDefinitionAst) { return $false }

    [object] VisitDynamicKeywordStatement([DynamicKeywordStatementAst] $dynamicKeywordAst) { return $false }

    [object] VisitErrorStatement([ErrorStatementAst] $errorStatementAst) { return $false }

    [object] VisitErrorExpression([ErrorExpressionAst] $errorExpressionAst) { return $false }

    [object] VisitScriptBlock([ScriptBlockAst] $scriptBlockAst) {
        if ($this._hasSeenInitialScriptBlockAst) {
            return $false
        }

        $this._hasSeenInitialScriptBlockAst = $true
        if ($scriptBlockAst.BeginBlock) {
            return $false
        }

        if ($scriptBlockAst.ProcessBlock) {
            return $false
        }

        if ($scriptBlockAst.DynamicParamBlock) {
            return $false
        }

        if ($scriptBlockAst.ParamBlock.Parameters) {
            return $false
        }

        return $scriptBlockAst.EndBlock.Visit($this)
    }

    [object] VisitParamBlock([ParamBlockAst] $paramBlockAst) { return $false }

    [object] VisitNamedBlock([NamedBlockAst] $namedBlockAst) {
        if ($namedBlockAst.Statements.Count -eq 0) {
            return $true
        }

        if ($namedBlockAst.Statements.Count -gt 1) {
            return $false
        }

        return $namedBlockAst.Statements[0].Visit($this)
    }

    [object] VisitTypeConstraint([TypeConstraintAst] $typeConstraintAst) { return $true }

    [object] VisitAttribute([AttributeAst] $attributeAst) { return $false }

    [object] VisitNamedAttributeArgument([NamedAttributeArgumentAst] $namedAttributeArgumentAst) { return $false }

    [object] VisitParameter([ParameterAst] $parameterAst) { return $false }

    [object] VisitFunctionDefinition([FunctionDefinitionAst] $functionDefinitionAst) { return $false }

    [object] VisitStatementBlock([StatementBlockAst] $statementBlockAst) { return $false }

    [object] VisitIfStatement([IfStatementAst] $ifStmtAst) { return $false }

    [object] VisitTrap([TrapStatementAst] $trapStatementAst) { return $false }

    [object] VisitSwitchStatement([SwitchStatementAst] $switchStatementAst) { return $false }

    [object] VisitDataStatement([DataStatementAst] $dataStatementAst) { return $false }

    [object] VisitForEachStatement([ForEachStatementAst] $forEachStatementAst) { return $false }

    [object] VisitDoWhileStatement([DoWhileStatementAst] $doWhileStatementAst) { return $false }

    [object] VisitForStatement([ForStatementAst] $forStatementAst) { return $false }

    [object] VisitWhileStatement([WhileStatementAst] $whileStatementAst) { return $false }

    [object] VisitCatchClause([CatchClauseAst] $catchClauseAst) { return $false }

    [object] VisitTryStatement([TryStatementAst] $tryStatementAst) { return $false }

    [object] VisitBreakStatement([BreakStatementAst] $breakStatementAst) { return $false }

    [object] VisitContinueStatement([ContinueStatementAst] $continueStatementAst) { return $false }

    [object] VisitReturnStatement([ReturnStatementAst] $returnStatementAst) {
        return $returnStatementAst.Pipeline.Visit($this)
    }

    [object] VisitExitStatement([ExitStatementAst] $exitStatementAst) { return $false }

    [object] VisitThrowStatement([ThrowStatementAst] $throwStatementAst) { return $false }

    [object] VisitDoUntilStatement([DoUntilStatementAst] $doUntilStatementAst) { return $false }

    [object] VisitAssignmentStatement([AssignmentStatementAst] $assignmentStatementAst) {
        $targets = [ExpressionAst[]]$assignmentStatementAst.GetAssignmentTargets()
        if ($targets.Length -gt 1) {
            return $false
        }

        return $assignmentStatementAst.Right.Visit($this)
    }

    [object] VisitPipeline([PipelineAst] $pipelineAst) {
        if ($pipelineAst.Background) {
            return $false
        }

        if ($pipelineAst.PipelineElements.Count -eq 0) {
            return $true
        }

        if ($pipelineAst.PipelineElements.Count -gt 1) {
            return $false
        }

        return $pipelineAst.PipelineElements[0].Visit($this)
    }

    [object] VisitCommand([CommandAst] $commandAst) { return $false }

    [object] VisitCommandExpression([CommandExpressionAst] $commandExpressionAst) {
        if ($commandExpressionAst.Redirections) {
            return $false
        }

        return $commandExpressionAst.Expression.Visit($this)
    }

    [object] VisitCommandParameter([CommandParameterAst] $commandParameterAst) { return $false }

    [object] VisitFileRedirection([FileRedirectionAst] $fileRedirectionAst) { return $false }

    [object] VisitMergingRedirection([MergingRedirectionAst] $mergingRedirectionAst) { return $false }

    [object] VisitBinaryExpression([BinaryExpressionAst] $binaryExpressionAst) { return $false }

    [object] VisitUnaryExpression([UnaryExpressionAst] $unaryExpressionAst) { return $false }

    [object] VisitConvertExpression([ConvertExpressionAst] $convertExpressionAst) { return $false }

    [object] VisitConstantExpression([ConstantExpressionAst] $constantExpressionAst) { return $true }

    [object] VisitStringConstantExpression([StringConstantExpressionAst] $stringConstantExpressionAst) { return $true }

    [object] VisitSubExpression([SubExpressionAst] $subExpressionAst) { return $false }

    [object] VisitUsingExpression([UsingExpressionAst] $usingExpressionAst) { return $false }

    [object] VisitVariableExpression([VariableExpressionAst] $variableExpressionAst) { return $false }

    [object] VisitTypeExpression([TypeExpressionAst] $typeExpressionAst) { return $false }

    [object] VisitMemberExpression([MemberExpressionAst] $memberExpressionAst) { return $true }

    [object] VisitInvokeMemberExpression([InvokeMemberExpressionAst] $invokeMemberExpressionAst) { return $true }

    [object] VisitArrayExpression([ArrayExpressionAst] $arrayExpressionAst) { return $false }

    [object] VisitArrayLiteral([ArrayLiteralAst] $arrayLiteralAst) { return $false }

    [object] VisitHashtable([HashtableAst] $hashtableAst) { return $false }

    [object] VisitScriptBlockExpression([ScriptBlockExpressionAst] $scriptBlockExpressionAst) { return $false }

    [object] VisitParenExpression([ParenExpressionAst] $parenExpressionAst) {
        return $parenExpressionAst.Pipeline.Visit($this)
    }

    [object] VisitExpandableStringExpression([ExpandableStringExpressionAst] $expandableStringExpressionAst) { return $false }

    [object] VisitIndexExpression([IndexExpressionAst] $indexExpressionAst) { return $false }

    [object] VisitAttributedExpression([AttributedExpressionAst] $attributedExpressionAst) { return $false }

    [object] VisitBlockStatement([BlockStatementAst] $blockStatementAst) { return $false }
}

function Use-Object {
    [Alias('use')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $Factory,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNull()]
        [scriptblock] $Action
    )
    begin {
        $scriptAst = [ScriptBlockAst]$Factory.Ast
        $statement = [StatementAst]$scriptAst.EndBlock.Statements[0].Copy()
        if (-not $statement.Visit([IsSafeDisposableFactoryVisitor]::new())) {
            $exception = [PSArgumentException]::new(
                'Unable to verify that the disposable factory script can reliably return an ' +
                'object once it''s created. Please ensure that the factory script is as simple ' +
                'as possible and then try the command again.',
                (nameof{$Factory}))

            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    <# exception:     #> $exception,
                    <# errorId:       #> 'FactoryTooComplex',
                    <# errorCategory: #> [ErrorCategory]::InvalidArgument,
                    <# targetObject:  #> $Factory))
            return
        }

        $emptyTraps = [TrapStatementAst[]]::new(0)
        $ep = [ScriptPosition]::new('', 0, 0, '', '')
        $ee = [ScriptExtent]::new($ep, $ep)

        $assignment = [AssignmentStatementAst]::new(
            $statement.Extent,
            [MemberExpressionAst]::new(
                $ee,
                [IndexExpressionAst]::new(
                    $ee,
                    [VariableExpressionAst]::new($ee, 'args', $false),
                    [ConstantExpressionAst]::new($ee, 0)),
                [StringConstantExpressionAst]::new($ee, 'Value', [StringConstantType]::BareWord),
                $false),
            [TokenKind]::Equals,
            $statement,
            $ee)

        $newSbAst = [ScriptBlockAst]::new(
            $scriptAst.Extent,
            $null,
            [StatementBlockAst]::new($scriptAst.Extent, [StatementAst[]]$assignment, $emptyTraps),
            <# isFilter: #> $false)

        $sb = $newSbAst.GetScriptBlock()
        $ssiProp = [scriptblock].GetProperty('SessionStateInternal', 36)
        $lmProp = [scriptblock].GetProperty('LanguageMode', 36)

        $null = $ssiProp.SetValue($sb, $ssiProp.GetValue($Factory))
        $null = $lmProp.SetValue($sb, $lmProp.GetValue($Factory))

        $pipeline = $Host.Runspace.GetType().GetMethod('GetCurrentlyRunningPipeline', 36).Invoke($Host.Runspace, @())
        $stopper = $pipeline.GetType().GetProperty('Stopper', 36).GetValue($pipeline)
        $syncRoot = $stopper.GetType().GetField('_syncRoot', 36).GetValue($stopper)

        if ($null -eq $syncRoot) {
            $PSCmdlet.WriteWarning(
                'Do not press Ctrl + C, pipeline stops cannot be prevented in this version of PowerShell.')

            $syncRoot = [object]::new()
        }

        $ref = [ref]$null
        try {
            $null = . $sb $ref
            $isMissingDispose = $false
            if ($null -eq $ref.Value -or -not $ref.Value.psobject.Methods['Dispose']) {
                $isMissingDispose = $true
                $exception = [PSInvalidOperationException]::new(
                    'The factory script did not return an object with a public Dispose method.')

                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        <# exception:     #> $exception,
                        <# errorId:       #> 'ObjectNotDisposable',
                        <# errorCategory: #> [ErrorCategory]::InvalidOperation,
                        <# targetObject:  #> $ref.Value))
            }

            $variables = [psvariable[]][psvariable]::new('_', $ref.Value)
            $arguments = [object[]]::new(1)
            $arguments[0] = $ref.Value
            try {
                $Action.InvokeWithContext(@{}, $variables, $arguments)
            } catch {
                $PSCmdlet.WriteError($PSItem)
            }
        } finally {
            [Threading.Monitor]::Enter($syncRoot)
            try {
                if ($null -ne $ref.Value -and -not $isMissingDispose) {
                    $ref.Value.Dispose()
                }
            } finally {
                [Threading.Monitor]::Exit($syncRoot)
            }
        }
    }
}

$script:AssemblyResolutionTable = [Dictionary[ValueTuple[string, bool], ValueTuple[Assembly, ResolveEventHandler]]]::new()
function Add-AssemblyBinding {
    [CmdletBinding(DefaultParameterSetName = 'NameSet')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'NameSet')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'LiteralNameSet')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [Alias('To')]
        [Assembly] $ResolvedTo
    )
    begin {
        if ($PSBoundParameters.ContainsKey((nameof{$LiteralName}))) {
            $key = [ValueTuple]::Create($LiteralName, $true)
            $scriptBlock = {
                param($s, $e)
                end {
                    if ($e.Name -eq $LiteralName) {
                        return $ResolvedTo
                    }
                }
            }
        } else {
            $key = [ValueTuple]::Create($Name, $false)
            $scriptBlock = {
                param($s, $e)
                end {
                    if ($e.Name -like $Name) {
                        return $ResolvedTo
                    }
                }
            }
        }

        $existingValue = default([ValueTuple[Assembly, ResolveEventHandler]])
        if ($script:AssemblyResolutionTable.TryGetValue($key, [ref] $existingValue)) {
            if ($existingValue.Item1 -eq $ResolvedTo) {
                return
            }
        }

        $boundParameters = $PSBoundParameters
        $delegate = & {
            $LiteralName = $boundParameters[(nameof{$LiteralName})]
            $Name = $boundParameters[(nameof{$Name})]
            $ResolvedTo = $boundParameters[(nameof{$ResolvedTo})]
            [ResolveEventHandler]$scriptBlock.GetNewClosure()
        }

        $script:AssemblyResolutionTable[$key] = [ValueTuple]::Create([Assembly]$ResolvedTo, $delegate)
        [AppDomain]::CurrentDomain.add_AssemblyResolve($delegate)
    }
}

function Get-AssemblyBinding {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
    begin {
        $isNameSpecified = $PSBoundParameters.ContainsKey((nameof{$Name}))
        foreach ($kvp in $script:AssemblyResolutionTable.GetEnumerator()) {
            if ($isNameSpecified -and $kvp.Key.Item1 -notlike $Name) {
                continue
            }

            # yield
            [PSCustomObject]@{
                PSTypeName = 'UtilityProfile.AssemblyBinding'
                Name = $kvp.Key.Item1
                IsLiteral = $kvp.Key.Item2
                ResolvedAssembly = $kvp.Value.Item1
            }
        }
    }
}

function Remove-AssemblyBinding {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSTypeName('UtilityProfile.AssemblyBinding')]
        [psobject] $InputObject
    )
    process {
        if ($null -eq $InputObject) {
            return
        }

        $script:AssemblyResolutionTable.Remove(
            [ValueTuple]::Create($InputObject.Name, $InputObject.IsLiteral))
    }
}

function Invoke-Loop {
    [Alias('loop')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $Body
    )
    begin {
        class ReturnFinder : AstVisitor {
            [bool] $FoundReturnStatement;

            hidden ReturnFinder() { }

            static [bool] ContainsReturn([Ast] $ast) {
                $finder = [ReturnFinder]::new()
                $ast.Visit($finder)
                return $finder.FoundReturnStatement
            }

            [AstVisitAction] VisitReturnStatement([ReturnStatementAst] $returnStatementAst) {
                $this.FoundReturnStatement = $true
                return [AstVisitAction]::StopVisit
            }
        }

        if ([ReturnFinder]::ContainsReturn($Body.Ast)) {
            $exception = [PSArgumentException]::new(
                'The body of this type of loop may not contain a "return" statement because it''s symantics cannot be implemented outside of the engine.')
            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    $exception,
                    'LoopBodyContainsReturn',
                    'InvalidArgument',
                    $Body))
            return
        }
    }
    end {
        $ps = $null
        try {
            $ps = [powershell]::Create('CurrentRunspace').
                AddScript(
                    { param([scriptblock] $Body) end { . $Body } },
                    <# useLocalScope: #> $false).
                AddParameter("Body", $Body)

            $invokeSettings = [PSInvocationSettings]::new()
            $invokeSettings.ExposeFlowControlExceptions = $true
            $invokeSettings.Host = $Host
            $invokeSettings.AddToHistory = $false

            while ($true) {
                try {
                    # yield
                    $ps.Invoke($null, $invokeSettings)
                    foreach ($record in $ps.Streams.Error) {
                        $PSCmdlet.WriteError($record)
                    }

                    $ps.Streams.ClearStreams()
                } catch [ContinueException] {
                    continue
                } catch [BreakException] {
                    break
                } catch [TerminateException] {
                    throw
                } catch {
                    $exception = $PSItem.Exception.InnerException
                    if ($exception -is [IContainsErrorRecord]) {
                        throw [ErrorRecord]::new(
                            $exception.ErrorRecord,
                            $exception)
                    }

                    throw [ErrorRecord]::new(
                        $exception,
                        $exception.GetType().Name,
                        'NotSpecified',
                        $null)
                    return
                }
            }
        } finally {
            if ($null -ne $ps) {
                $ps.Dispose()
                $ps = $null
            }
        }
    }
}

function Find-File {
    <#
        .SYNOPSIS
            Quickly search the file system.

        .DESCRIPTION
            The Find-File function will search the file system for the specified
            file or directory with better performance than using Get-ChildItem.

        .PARAMETER Path
            The path to search. If the "Filter" parameter is not specified, the
            last path segment will be used as the filter. This parameter accepts
            wildcards.

        .PARAMETER LiteralPath
            The path to search. If the "Filter" parameter is not specified, the
            last path segment will be used as the filter. This parameter does not
            accept wildcards.

        .PARAMETER Filter
            The pattern to search for. If not specified, the last path segment of
            either the Path or LiteralPath parameters will be used as the filter.

        .PARAMETER Directory
            If specified, only directories will be returned. If specified with the
            File parameter, neither parameter will take effect.

        .PARAMETER File
            If specified, only files will be returned. If specified with the Directory
            parameter, neither parameter will take effect.

        .PARAMETER Recurse
            Specifies whether child folders should be included in the search.

        .PARAMETER Depth
            Specifies the maximum depth of child folders that should be included in
            the search. If specified, the Recurse parameter is implied.

        .EXAMPLE
            PS> Find-File
            Returns all files and directories in the current folder.

        .EXAMPLE
            PS> Find-File *application*
            Returns any file or directory in the current folder whose name contains
            the word "application".

        .EXAMPLE
            PS> Find-File C:\*.exe -Recurse -File
            Finds all executable files on the C drive, including child folders.

        .EXAMPLE
            PS> Find-File *.exe -Recurse -File
            Finds all executable files in the current folder, including child folders.

        .EXAMPLE
            PS> Find-File C:\ -Filter *.exe -Recurse -File
            Finds all executable files on the C drive, including child folders.

        .EXAMPLE
            PS> Find-File C:\Windows -Filter etc -Recurse -Directory
            Finds the "etc" folder in a nested folder within "C:\Windows".
    #>
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'ByPath')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Path = '*',

        [Parameter(Mandatory, ParameterSetName = 'ByLiteralPath')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(Position = 1, ParameterSetName = 'ByPath')]
        [Parameter(Position = 0, ParameterSetName = 'ByLiteralPath')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Filter,

        [Parameter()]
        [switch] $Directory,

        [Parameter()]
        [switch] $File,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Depth = -1
    )
    begin {
        class ItemToProcess {
            [int] $Depth;

            [string] $Path;

            [ItemToProcess] CreateChild([string] $path) {
                $result = [ItemToProcess]::new()
                $result.Depth = $this.Depth + 1
                $result.Path = $path
                return $result
            }
        }

        if ($PSBoundParameters.ContainsKey('LiteralPath')) {
            $isLiteral = $true
            $target = $LiteralPath
        } else {
            $isLiteral = $false
            $target = $Path
        }

        $provider = $null
        $target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $target,
            [ref] $provider,
            [ref] $null)

        if ($provider.Name -ne [Microsoft.PowerShell.Commands.FileSystemProvider]::ProviderName) {
            $exception = [PSInvalidOperationException]::new(
                'Only the FileSystem provider is supported by this function.')
            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    $exception,
                    'InvalidProvider',
                    [ErrorCategory]::InvalidArgument,
                    $provider))
        }

        if (-not $PSBoundParameters.ContainsKey('Filter')) {
            $Filter = $target | Split-Path -Leaf
            $target = $target | Split-Path -Parent
        }

        if (-not $isLiteral) {
            $target = Resolve-Path $target -ErrorAction Stop
            if ($target -is [array]) {
                $exception = [PSArgumentException]::new(
                    'The base search path specified resolves to multiple directories.')
                $PSCmdlet.ThrowTerminatingError(
                    [ErrorRecord]::new(
                        $exception,
                        'MultipleDirectories',
                        [ErrorCategory]::InvalidArgument,
                        $target))
            }

            if ($target -is [PathInfo]) {
                $target = $target.ProviderPath
            }
        }

        $items = [Stack[ItemToProcess]]::new()
        $items.Push([ItemToProcess]@{ Depth = 0; Path = $target })
        $pattern = [WildcardPattern]::Get(
            $Filter,
            [WildcardOptions]'Compiled, IgnoreCase, CultureInvariant')

        $shouldReturnDirectories = if ($PSBoundParameters.ContainsKey('Directory')) {
            $Directory.IsPresent
        } else {
            -not $File.IsPresent
        }

        $shouldReturnFiles = if ($PSBoundParameters.ContainsKey('File')) {
            $File.IsPresent
        } else {
            -not $Directory.IsPresent
        }

        if (-not ($shouldReturnDirectories -or $shouldReturnFiles)) {
            return
        }

        if ($Recurse.IsPresent -and $Depth -eq -1) {
            $Depth = [int]::MaxValue
        }

        $handleError = { param([PSCmdlet] $cmdlet, [ErrorRecord] $er) end {
            if ($er.Exception -is [MethodInvocationException]) {
                $cmdlet.WriteError(
                    [ErrorRecord]::new(
                        $er.Exception.InnerException,
                        'FileSystemEnumerationError',
                        [ErrorCategory]::NotSpecified,
                        $er))

                return
            }

            $cmdlet.WriteError($er)
        }}
    }
    end {
        if (-not ($shouldReturnDirectories -or $shouldReturnFiles)) {
            return;
        }

        while ($items.Count -gt 0) {
            $item = $items.Pop()
            $canRecurse = $Depth -ne -1 -and $item.Depth -lt $Depth
            try {
                if ($shouldReturnDirectories -or $canRecurse) {
                    foreach ($directoryPath in [Directory]::GetDirectories($item.Path)) {
                        if ($shouldReturnDirectories -and $pattern.IsMatch([Path]::GetFileName($directoryPath))) {
                            # yield
                            $directoryPath
                        }

                        if ($canRecurse) {
                            $items.Push($item.CreateChild($directoryPath))
                        }
                    }
                }

                if (-not $shouldReturnFiles) {
                    continue
                }

                foreach ($filePath in [Directory]::GetFiles($item.Path)) {
                    if ($pattern.IsMatch([Path]::GetFileName($filePath))) {
                        # yield
                        $filePath
                    }
                }
            } catch {
                & $handleError $PSCmdlet $PSItem
            }
        }
    }
}

function Get-PathEntry {
    [OutputType('UtilityProfile.PathEntry')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Pattern,

        [Parameter()]
        [ValidateNotNull()]
        [EnvironmentVariableTarget[]] $Scope
    )
    begin {
        if (-not $PSBoundParameters.ContainsKey((nameof{$Scope}))) {
            $Scope = [EnvironmentVariableTarget].GetEnumValues()
        }

        $pathEntries = foreach ($targetScope in $Scope) {
            $path = [Environment]::GetEnvironmentVariable('PATH', $targetScope)
            foreach ($entry in $path.Split([char][IO.Path]::PathSeparator, [StringSplitOptions]::RemoveEmptyEntries)) {
                [PSCustomObject]@{
                    PSTypeName = 'UtilityProfile.PathEntry'
                    Scope = $targetScope
                    Value = $entry
                }
            }
        }

        if (-not ($MyInvocation.ExpectingInput -or $PSBoundParameters.ContainsKey((nameof{$Pattern})))) {
            if (-not $PSBoundParameters.ContainsKey((nameof{$Pattern}))) {
                return $pathEntries
            }

            return $pathEntries.Where{
                $value = $PSItem.Value
                $Pattern.Where{ $value -like $PSItem }
            }
        }

        $patterns = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    process {
        if (-not ($MyInvocation.ExpectingInput -or $PSBoundParameters.ContainsKey((nameof{$Pattern})))) {
            return
        }

        if ($PSBoundParameters.ContainsKey((nameof{$Pattern}))) {
            $null = $patterns.Add($Pattern)
        }
    }
    end {
        if (-not ($MyInvocation.ExpectingInput -or $PSBoundParameters.ContainsKey((nameof{$Pattern})))) {
            return
        }

        if ($patterns.Count -eq 0) {
            return $pathEntries
        }

        return $pathEntries.Where{
            $value = $PSItem.Value
            $Pattern.Where{ $value -like $PSItem }
        }
    }
}

function Remove-PathEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSTypeName('UtilityProfile.PathEntry')]
        [ValidateNotNull()]
        [psobject] $PathEntry
    )
    process {
        $path = [Environment]::GetEnvironmentVariable(
            'PATH',
            $PathEntry.Scope)

        $entries = $path.
            Split([char][IO.Path]::PathSeparator, [StringSplitOptions]::RemoveEmptyEntries).
            Where{ -not $PSItem.Equals($PathEntry.Value, [StringComparison]::Ordinal) }

        $newPath = $entries -join [IO.Path]::PathSeparator
        try {
            [Environment]::SetEnvironmentVariable(
                'PATH',
                $newPath,
                $PathEntry.Scope)
        } catch [MethodInvocationException] {
            $exception = $PSItem.Exception.InnerException
            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    $exception,
                    'CannotSetPathAtScope',
                    [ErrorCategory]::WriteError,
                    $PathEntry))
        }
    }
}

function New-PathEntry {
    [OutputType('UtilityProfile.PathEntry')]
    [CmdletBinding(DefaultParameterSetName = 'ByPath', PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, Position = 0, ParameterSetName = 'ByPath')]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName')]
        [string[]] $Path,

        [Parameter(Mandatory, ParameterSetName = 'ByLiteralPath')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(Position = 1, ParameterSetName = 'ByPath')]
        [Parameter(Position = 0, ParameterSetName = 'ByLiteralPath')]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )
    begin {
        $comparer = if ($IsLinux) {
            [StringComparer]::Ordinal
        } else {
            [StringComparer]::OrdinalIgnoreCase
        }

        $pathsToSet = [HashSet[string]]::new($comparer)
        $pathsToSetOrdered = [List[string]]::new()
        $existingEntries = [HashSet[string]]::new($comparer)
        foreach ($entry in Get-PathEntry -Scope $Scope) {
            $null = $existingEntries.Add($entry.Value)
        }
    }
    process {
        if ($PSBoundParameters.ContainsKey((nameof{$LiteralPath}))) {
            $fullPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($LiteralPath)
            if ($existingEntries.Contains($fullPath)) {
                return
            }

            if ($pathsToSet.Add($fullPath)) {
                $pathsToSetOrdered.Add($fullPath)
            }

            return
        }

        foreach ($singlePath in $Path) {
            $resolvedPaths = $null
            try {
                $provider = $null
                $resolvedPaths = $PSCmdlet.GetResolvedProviderPathFromPSPath(
                    $singlePath,
                    [ref] $provider)

                if ($provider.Name -ne [FileSystemProvider]::ProviderName) {
                    $PSCmdlet.WriteError(
                        [ErrorRecord]::new(
                            [PSArgumentException]::new('Path must be of the FileSystem provider.'),
                            'PathNotFileSystem',
                            [ErrorCategory]::InvalidArgument,
                            $singlePath))
                    continue
                }
            } catch [MethodInvocationException] {
                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        $PSItem.Exception.InnerException,
                        'CannotResolvePath',
                        [ErrorCategory]::ObjectNotFound,
                        $singlePath))
                continue
            }

            $didFindDirectory = $false
            foreach ($resolvedPath in $resolvedPaths) {
                if (-not [IO.Directory]::Exists($resolvedPath)) {
                    continue
                }

                $didFindDirectory = $true
                if ($existingEntries.Contains($resolvedPath)) {
                    continue
                }

                if ($pathsToSet.Add($resolvedPath)) {
                    $pathsToSetOrdered.Add($resolvedPaths)
                }
            }

            if ($didFindDirectory) {
                continue
            }

            $exception = [ItemNotFoundException]::new(
                'Unable to find a directory with the path "{0}"' -f $singlePath)

            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    $exception,
                    'CannotResolvePath',
                    [ErrorCategory]::ObjectNotFound,
                    $singlePath))
        }
    }
    end {
        $rawEntries = Get-PathEntry -Scope $Scope |
            Select-Object -ExpandProperty Value |
            append { $pathsToSetOrdered }

        $newPath = $rawEntries -join [IO.Path]::PathSeparator
        try {
            [Environment]::SetEnvironmentVariable(
                'PATH',
                $newPath,
                $Scope)
        } catch [MethodInvocationException] {
            $exception = $PSItem.Exception.InnerException
            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    $exception,
                    'CannotSetPathAtScope',
                    [ErrorCategory]::WriteError,
                    $PathEntry))
            return
        }

        $pathsToSetOrdered.ForEach{
            [PSCustomObject]@{
                PSTypeName = 'UtilityProfile.PathEntry'
                Scope = $Scope
                Value = $PSItem
            }
        }
    }
}

function Invoke-Parser {
    [Alias('parse')]
    [OutputType([System.Management.Automation.Language.Ast])]
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'ByDefinition')]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ParameterSetName = 'ByDefinition')]
        [ValidateNotNullOrEmpty()]
        [string] $Script,

        [Parameter(ParameterSetName = 'ByDefinition')]
        [ValidateNotNullOrEmpty()]
        [string] $ClaimSourcePath,

        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'ByLiteralPath')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )
    begin {
        function processAst {
            param($ast, $tokens, $errors)
            end {
                if ($errors) {
                    $exception = [System.Management.Automation.ParseException]::new($errors)
                    $PSCmdlet.WriteError(
                        [System.Management.Automation.ErrorRecord]::new(
                            $exception.ErrorRecord,
                            $exception))
                }

                $ast.psobject.Properties.Add(
                    [psnoteproperty]::new(
                        'Tokens',
                        $tokens))

                $ast.psobject.Properties.Add(
                    [psnoteproperty]::new(
                        'Errors',
                        $errors))

                return $ast
            }
        }
    }
    process {
        $ast = $tokens = $errors = $pathsToParse = $null
        if ($PSCmdlet.ParameterSetName -eq 'ByDefinition') {
            try {
                if ($MyInvocation.BoundParameters.ContainsKey((nameof{$ClaimSourcePath}))) {
                    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
                        $Script,
                        $ClaimSourcePath,
                        [ref] $tokens,
                        [ref] $errors)

                    return processAst $ast $tokens $errors
                } else {
                    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
                        $Script,
                        [ref] $tokens,
                        [ref] $errors)

                    return processAst $ast $tokens $errors
                }
            } catch {
                $baseException = $PSItem.Exception.InnerException
                $exception = [System.Management.Automation.RuntimeException]::new(
                    ('An unexpected exception was thrown while parsing: {0}' -f $baseException.Message),
                    $baseException)

                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'UncaughtParseException',
                        [System.Management.Automation.ErrorCategory]::ParserError,
                        $null))
                return
            }
        }

        $pathsToParse = $provider = $null
        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            try {
                $pathsToParse = $PSCmdlet.SessionState.Path.GetResolvedProviderPathFromPSPath(
                    $Path,
                    [ref] $provider)
            } catch {
                $PSCmdlet.WriteError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $PSItem.Exception.InnerException.ErrorRecord,
                        $PSItem.Exception.InnerException))
                return
            }
        } else {
            $pathsToParse = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                $LiteralPath,
                [ref] $provider,
                [ref] $null)

            if (-not [System.IO.File]::Exists($pathsToParse)) {
                $exception = [System.Management.Automation.ItemNotFoundException]::new(
                    "Cannot find path '{0}' because it does not exist." -f $LiteralPath)
                $PSCmdlet.WriteError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'PathNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $LiteralPath))


                return
            }
        }

        if ($provider.Name -ne [Microsoft.PowerShell.Commands.FileSystemProvider]::ProviderName) {
            $exception = [System.Management.Automation.PSArgumentException]::new(
                'The specified path was not from the FileSystem provider.')
            $PSCmdlet.WriteError(
                [System.Management.Automation.ErrorRecord]::new(
                    $exception,
                    'PathNotFileSystem',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $null))

            return
        }

        foreach ($pathToParse in $pathsToParse) {
            try {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $pathToParse,
                    [ref] $tokens,
                    [ref] $errors)

                # yield
                processAst $ast $tokens $errors
            } catch {

                $baseException = $PSItem.Exception.InnerException
                $exception = [System.Management.Automation.RuntimeException]::new(
                    ('An unexpected exception was thrown while parsing: {0}' -f $baseException.Message),
                    $baseException)

                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'UncaughtParseException',
                        [System.Management.Automation.ErrorCategory]::ParserError,
                        $null))
            }
        }
    }
}

function New-TerminalHyperLink {
    [Alias('link')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [uri] $Uri,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Text
    )
    begin {
        $e = [char]0x1B
    }
    process {
        if ([string]::IsNullOrEmpty($Text)) {
            $Text = $Uri.ToString()
        }

        return "$e]8;;$Uri$e\$Text$e]8;;$e\"
    }
}

function Get-GenericParameterInfo {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $Type)
    process {
        if ($null -eq $Type) {
            return
        }

        if ($Type -is [Reflection.MethodInfo]) {
            if (-not $Type.IsGenericMethod) {
                return
            }

            return $Type.GetGenericArguments() | Get-GenericParameterInfo
        }

        if ($Type -isnot [type]) {
            return
        }

        if ($Type.IsGenericType) {
            if ($Type.IsGenericTypeDefinition) {
                return $Type.GetGenericArguments() | Get-GenericParameterInfo
            }

            return $Type.GetGenericTypeDefinition().GetGenericArguments() | Get-GenericParameterInfo
        }

        if (-not $Type.IsGenericParameter) {
            return
        }

        [PSCustomObject]@{
            Type = $Type
            Attributes = $Type.GenericParameterAttributes
            Contraints = $Type.GetGenericParameterConstraints()
            CustomAttributes = $Type.GetCustomAttributes($true)
        }
    }
}

function Invoke-InTempFile {
    [Alias('pester')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $ScriptBlock
    )
    end {
        $folder = [Path]::GetRandomFileName()
        $fileName = [Path]::ChangeExtension([Path]::GetRandomFileName(), '.ps1')
        $path = [Path]::Combine(
            [Path]::GetTempPath(),
            $folder,
            $fileName)

        $tempFolder = $path | Split-Path

        $null = New-Item -ItemType Directory $tempFolder
        Set-Content -LiteralPath $path -Value $ScriptBlock -ErrorAction Stop -Force
        try {
            Invoke-Pester -Path $path
        } finally {
            Remove-Item -LiteralPath $tempFolder -Force -Recurse -ErrorAction Stop
        }
    }
}

function compile {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Definition,

        [Parameter()]
        [switch] $PassThru
    )
    begin {
        $splat = @{}
        if ($PSVersionTable.PSVersion.Major -gt 5) {
            $splat['CompilerOptions'] = '-unsafe'
            $splat['IgnoreWarnings'] = $true
        } else {
            $options = [System.CodeDom.Compiler.CompilerParameters]::new()
            $options.TreatWarningsAsErrors = $false
            $options.CompilerOptions = '/unsafe'
            $splat['CompilerParameters'] = $options
        }

        if ($PassThru) {
            $splat['PassThru'] = $PassThru
        }
    }
    end {
        Add-Type @splat -TypeDefinition ('
using System;
using System.Management.Automation;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

{0}' -f $Definition)
    }
}

function New-WGMeeting {
    <#
        .SYNOPSIS
        Generate meeting notes for working group meetings.

        .DESCRIPTION
        Use the GitHub API to generate a meeting notes template from specified issue numbers.

        If invoked from the VSCode extension's PowerShell integrated console it will open
        the notes in an untitled file.

        .PARAMETER Issue
        An issue to be discussed. The issue PowerShell\PowerShell#16795 can be portrayed as:

        PowerShell\PowerShell#16795
        PowerShell#16795
        16795

        If not specified, the owner and repo will be "PowerShell".

        .PARAMETER Group
        The working group that will discussing these issues.

        .EXAMPLE
        PS> echo vscode-powershell#392 Microsoft\vscode#345 16795 16794 | New-WGMeeting Engine

        Generates meeting notes for the WG-Engine group.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Issue,

        [Parameter(Position = 0)]
        [ValidateSet('Engine', 'Language', 'DevEx', 'Cmdlets & Modules', 'DSC', 'Remoting', 'Interactive UX')]
        [string] $Group
    )
    begin {
        $headerTemplate = @'
__**PowerShell WG-{0} working group meeting summary for {1:yyyy-MM-dd}**__

__*Attendees*__

🔹 @ 👑
🔹 @ 📝
🔹 @
🔹 @
🔹 @


'@

        # The {3} is for an empty space so we don't need to retain a trailing space
        # in the following literal.
        # Also I use a keyboard shortcut snippet here:
        # {
        #     "key": "shift+enter",
        #     "command": "editor.action.insertSnippet",
        #     "args": {
        #         "snippet": "🔸 `${1:XX}:` $2",
        #         "langId": "markdown",
        #         "name": "Dialog",
        #     },
        #     "when": "editorTextFocus && editorLangId == 'markdown' && vim.mode == 'Insert'"
        # },
        $issueTemplate = @'
:pushpin: __{0}__ - `{1}` - <{2}>

🔸 `:`{3}

**Assigned:** @


'@

        $issues = [List[string]]::new()
    }
    process {
        if (-not $Issue) {
            return
        }

        $issues.AddRange($Issue)
    }
    end {

        $notes = [StringBuilder]::new(($headerTemplate -f $Group, [datetime]::Now))

        if (-not $issues.Count) {
            Write-Debug 'No issues piped, returning empty template.'
            return $notes.
                AppendFormat($issueTemplate, '<IssueTitle>', '<IssueNumber>', 'link-to-issue', ' ').
                ToString()
        }

        foreach ($singleIssue in $issues) {
            if ($singleIssue -notmatch '^((?<Org>[\w-]+)\\)?((?<Repo>[\w-]+)#)?(?<Issue>\d+)$') {
                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        [PSArgumentException]::new(
                            "The issue '$singleIssue' does not fit the expected pattern. Examples: " +
                                '4354, vscode-powershell#4214, or Microsoft\vscode#4353',
                            'Issue'),
                        'InvalidIssueFormat',
                        [ErrorCategory]::InvalidArgument,
                        $singleIssue))

                $null = $notes.AppendFormat(
                    $issueTemplate,
                    'title-here',
                    $singleIssue,
                    'url-here',
                    ' ')

                continue
            }

            $org = $matches['Org'] | ?? { 'PowerShell' }
            $repo = $matches['Repo'] | ?? { 'PowerShell' }
            $issueNumber = $matches['Issue']

            $issueData = $null
            try {
                $issueData = Invoke-RestMethod "https://api.github.com/repos/$org/$repo/issues/$issueNumber" -ErrorAction Stop
            } catch {
                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        [PSArgumentException]::new(
                            "GitHub API returned an error while processing issue '$singleIssue'. Error: $PSItem",
                            $PSItem.Exception),
                        'GitHubApiError',
                        [ErrorCategory]::InvalidArgument,
                        $singleIssue))

                $null = $notes.AppendFormat(
                    $issueTemplate,
                    'title-here',
                    $singleIssue,
                    # Since it failed we don't actually know if this is an issue or a PR but that's fine.
                    "https://github.com/$org/$repo/issues/$issueNumber",
                    ' ')

                continue
            }

            $null = $notes.AppendFormat(
                $issueTemplate,
                $issueData.title,
                ($singleIssue -eq $issueNumber | ?? { "#$issueNumber" } : { $singleIssue }),
                $issueData.html_url,
                ' ')
        }

        $notesContent = $notes.ToString().Trim()
        if ($psEditor) {
            $psEditor.Workspace.NewFile()
            $psEditor.GetEditorContext().CurrentFile.InsertText($notesContent)
            return
        }

        return $notesContent
    }
}

function Enter-Pwsh {
    [CmdletBinding()]
    [Alias('nest')]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [scriptblock] $Action
    )
    end {
        $sb = {}
        if ($Action) {
            $sb = [scriptblock]::Create(({
                prompt | Write-Host -NoNewline
                Write-Host @'
{0}
'@
                {0}
            }.ToString() -f $Action))
        }

        while ($true) {
            pwsh -NoExit $sb
            $ec = $LASTEXITCODE
            if ($ec -eq 0xbeef) {
                break
            }

            if ($ec -eq 0) {
                continue
            }

            $null = Read-Host -Prompt "Exited with code '$ec', press enter when ready to continue"
        }
    }
}

function Unlock-Bitwarden {
    [Alias('bwun')]
    [CmdletBinding()]
    param()
    end {
        $env:BW_SESSION = bw unlock --raw
    }
}

function Update-LocalRepo {
    [Alias('gup')]
    [CmdletBinding()]
    param()
    end {
        $branch = git rev-parse --abbrev-ref HEAD
        $yesToAll = $false
        $noToAll = $false
        if ($branch -notin 'main', 'master') {
            $continue = $PSCmdlet.ShouldContinue(
                "You are on the branch '$branch' which is not the default, continue?",
                'Confirm',
                [ref] $yesToAll,
                [ref] $noToAll)

            if (-not $continue) {
                return
            }
        }

        $continue = $PSCmdlet.ShouldContinue(
            "You are about to run:

git fetch upstream $branch
git merge upstream/$branch
git push

Continue?",
            "Confirm",
            [ref] $yesToAll,
            [ref] $noToAll)

        if (-not $continue) {
            return
        }

        git fetch upstream $branch
        if ($LASTEXITCODE) {
            throw [Win32Exception]::new($LASTEXITCODE)
        }

        git merge upstream/$branch
        if ($LASTEXITCODE) {
            throw [Win32Exception]::new($LASTEXITCODE)
        }

        git push
        if ($LASTEXITCODE) {
            throw [Win32Exception]::new($LASTEXITCODE)
        }
    }
}

function Push-WithSetOrigin {
    [Alias('gpush')]
    [CmdletBinding()]
    param()
    end {
        $existingOrigin = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> $null
        if ($existingOrigin) {
            git push
            return
        }

        git push -u origin (git branch --show-current)
    }
}

function Get-ImplementedInterface {
    [Alias('gii')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [type] $Type
    )
    process {
        $Type.GetInterfaces()
    }
}

function New-ExpressionParameter {
    [Alias('ep')]
    [CmdletBinding()]
    param(
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [type] $Type = [object],

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Name
    )
    process {
        if ($Name) {
            return [Expression]::Parameter($Type, $Name)
        }

        return [Expression]::Parameter($Type)
    }
}

function New-ExpressionLabel {
    [Alias('el')]
    [CmdletBinding()]
    param(
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [type] $Type = [object]
    )
    process {
        return [Expression]::Label($Type)
    }
}

$script:ProjectsPath = $env:PROJECTS_PATH | ?? { 'C:\Projects' }

$script:LocationAliases = @{
    'Captures' = '~\Videos\Captures'
    'ps' = '~\Documents\PowerShell'
    'gpg' = '~\scoop\persist\gpg\home'
    'chez' = '~\.local\share\chezmoi'
    'pwsh' = "$script:ProjectsPath\PowerShell"
    'pses' = "$script:ProjectsPath\PowerShellEditorServices"
    'ce' = "$script:ProjectsPath\ClassExplorer"
    'dl' = '~\Downloads'
    'doc' = '~\Documents'
    'vim' = '~\.vimfiles'
}

function Resolve-PathAlias {
    [Alias('repa')]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Name
    )
    process {
        $projectsPath = $script:ProjectsPath
        if (-not $Name -and -not $MyInvocation.ExpectingInput) {
            return $projectsPath
        }

        if ($Name -in 'other', 'o') {
            $providerPath = $PSCmdlet.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            $directory = [Path]::GetDirectoryName($providerPath)
            $leaf = [Path]::GetFileName($providerPath)
            if ($leaf -eq 'PowerShellEditorServices') {
                return Join-Path $directory -ChildPath 'vscode-powershell'
            }

            return Join-Path $projectsPath -ChildPath 'PowerShellEditorServices'
        }

        $locationAliases = $script:LocationAliases
        $first, $rest = $Name -split '[\\/]'
        if ($resolvedAlias = $locationAliases[$first]) {
            $resolvedPath = $resolvedAlias
            if ($rest) {
                $resolvedPath = [Path]::Combine(
                    $resolvedAlias,
                    $rest -join [Path]::DirectorySeparatorChar)
            }

            return $resolvedPath
        }

        return Join-Path $projectsPath -ChildPath $Name
    }
}

function Set-LocationPlus {
    [Alias('p')]
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Name,

        [Parameter()]
        [switch] $PassThru
    )
    process {
        $resolvedLocation = Resolve-PathAlias $Name
        try {
            $location = $PSCmdlet.SessionState.Path.SetLocation($resolvedLocation)
        } catch {
            $PSCmdlet.WriteError(
                [ErrorRecord]::new(
                    [ItemNotFoundException]::new(
                        $PSItem.Exception.InnerException.Message,
                        $PSItem.Exception),
                    'PathNotFound',
                    [ErrorCategory]::ObjectNotFound,
                    $resolvedLocation))

            return
        }

        if ($PassThru) {
            return $location
        }
    }
}

function Edit-FilePlus {
    [Alias('pvim')]
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Name
    )
    end {
        $resolvedLocation = Resolve-PathAlias $Name
        $pipe = { & $env:EDITOR $resolvedLocation }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($PSCmdlet)
        $pipe.Process($null)
        $pipe.End()
    }
}

function Out-ErrorPaging {
    [Alias('e')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0)]
        [int] $Newest,

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $pipe = { Get-Error @PSBoundParameters | less --quit-if-one-screen }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $old = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'Ansi'
            $pipe.Begin($PSCmdlet)
        } finally {
            $PSStyle.OutputRendering = $old
        }
    }
    process {
        $old = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'Ansi'
            $pipe.Process($PSItem)
        } finally {
            $PSStyle.OutputRendering = $old
        }
    }
    end {
        $old = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'Ansi'
            $pipe.End()
        } finally {
            $PSStyle.OutputRendering = $old
        }
    }
}

${function:Out-ErrorPaging} = ${function:Out-ErrorPaging}.Ast.Body.GetScriptBlock()

function Out-Paging {
    [Alias('op')]
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ArgumentList,

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $pipe = { Out-AnsiFormatting -Stream | less @ArgumentList }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($PSCmdlet)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function Out-AnsiFormatting {
    [Alias('oaf')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [scriptblock] $Pipeline = { Out-String @BoundParameters },

        [Parameter(Position = 1)]
        [IDictionary] $BoundParameters = @{},

        [Parameter()]
        [Alias('s')]
        [switch] $Stream
    )
    begin {
        $pipe = $null
        try {
            if ($Stream) {
                $BoundParameters['Stream'] = $Stream
            }

            if ($InputObject) {
                $BoundParameters['InputObject'] = $InputObject
            }

            $old = $global:PSStyle.OutputRendering
            try {
                $global:PSStyle.OutputRendering = 'Ansi'
                $pipe = $Pipeline.Ast.GetScriptBlock().GetSteppablePipeline($MyInvocation.CommandOrigin)
                $pipe.Begin($PSCmdlet)
            } finally {
                $global:PSStyle.OutputRendering = $old
            }
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    process {
        $BoundParameters['InputObject'] = $InputObject
        try {
            $old = $PSStyle.OutputRendering
            try {
                $PSStyle.OutputRendering = 'Ansi'
                $pipe.Process($PSItem)
            } finally {
                $PSStyle.OutputRendering = $old
            }
        }
        catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    end {
        $BoundParameters['InputObject'] = $InputObject
        try {
            $old = $PSStyle.OutputRendering
            try {
                $PSStyle.OutputRendering = 'Ansi'
                $pipe.End()
            } finally {
                $PSStyle.OutputRendering = $old
            }
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
}

function begin {}
function process {}
function end {}
function catch {}
function try {}
function while {}
function for {}

function Format-PowerShell {
    [Alias('psh')]
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ArgumentList,

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $ArgumentList += '-l', 'powershell'
        $pipe = { Out-Bat @ArgumentList }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($PSCmdlet)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function Format-CSharp {
    [Alias('cs')]
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ArgumentList,

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $ArgumentList += '-l', 'cs'
        $pipe = { Out-Bat @ArgumentList }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($PSCmdlet)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function Out-Bat {
    [Alias('ob')]
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ArgumentList,

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    begin {
        $includeStyle = $MyInvocation.ExpectingInput
        $style = '--style', 'grid,numbers,snip'
        foreach ($arg in $ArgumentList) {
            if ($arg -match '^--style=') {
                $includeStyle = $false
                break
            }

            if ($arg -match '^--file-name') {
                $style = '--style', 'grid,numbers,snip,header-filename'
            }
        }

        if ($includeStyle) {
            $ArgumentList += $style
        }

        $pipe = { bat @ArgumentList }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($PSCmdlet)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

$locationAliasCompleter = {
    param(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [System.Management.Automation.Language.CommandAst] $commandAst,
        [System.Collections.IDictionary] $fakeBoundParameters
    )
    end {
        class Helper {
            static [CompletionResult[]] GetCompletions(
                [SessionState] $sessionState,
                [string] $name,
                [string] $root,
                [string] $rest,
                [bool] $includeFiles)
            {
                $root = (Get-Item $root).FullName
                return & {
                    $path = $root
                    if ($rest) {
                        $path = Join-Path $root -ChildPath $rest
                    }

                    foreach ($result in [CompletionCompleters]::CompleteFilename($path)) {
                        if (-not $includeFiles -and $result.ResultType -eq [CompletionResultType]::ProviderItem) {
                            continue
                        }

                        $completionText = $result.CompletionText.Trim([char]"'")
                        if ($completionText.TrimEnd([char][Path]::DirectorySeparatorChar) -eq $root) {
                            $relativePath = $completionText = $aliasedPath = $name
                        } else {
                            $relativePath = $sessionState.Path.NormalizeRelativePath($completionText, $root)
                            if ($relativePath.Contains([string]'..')) {
                                continue
                            }
                            $completionText = $aliasedPath = Join-Path $name -ChildPath $relativePath
                        }

                        if ($aliasedPath.Contains([char]' ')) {
                            $completionText = "'$aliasedPath'"
                        }

                        [CompletionResult]::new(
                            $completionText,
                            $aliasedPath,
                            $result.ResultType,
                            $result.ToolTip)
                    }
                }
            }
        }

        $projectsPath = $env:PROJECTS_PATH | ?? { 'C:\Projects' }

        $first, $rest = $wordToComplete -split '[\\/]'
        if ($rest) {
            $rest = $rest -join [Path]::DirectorySeparatorChar
        } else {
            $rest = $null
            $first += '*'
        }

        $includeFiles = $commandName -ne 'Set-LocationPlus'
        $pattern = [WildcardPattern]::new($first, [WildcardOptions]::CultureInvariant -bor 'IgnoreCase')
        [CompletionResult[]]@(
            if ($pattern.IsMatch('other')) {
                # yield
                [CompletionResult]::new('other', 'other', [CompletionResultType]::ParameterValue, 'other')
            }

            $locationAliases = $script:LocationAliases
            foreach ($kvp in $locationAliases.GetEnumerator()) {
                if (-not $pattern.IsMatch($kvp.Key)) {
                    continue
                }

                # yield
                [Helper]::GetCompletions($ExecutionContext.SessionState, $kvp.Key, $kvp.Value, $rest, $includeFiles)
            }

            Get-ChildItem $projectsPath -Filter $first -Directory -ErrorAction Ignore | & { process {
                [Helper]::GetCompletions($ExecutionContext.SessionState, $PSItem.BaseName, $PSItem.FullName, $rest, $includeFiles)
            }})
    }
}

function Format-TableRow {
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [switch] $HideTableHeaders
    )
    begin {
        $ft = { Format-Table @PSBoundParameters -Group { $true } }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $ft.Begin($MyInvocation.ExpectingInput)

        $oafParams = @{}
        $os = { Out-AnsiFormatting -Stream @oafParams }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $os.Begin($MyInvocation.ExpectingInput)
    }
    process {
        foreach ($item in $ft.Process($PSItem)) {
            if ($null -ne $item.groupingEntry) {
                $item.groupingEntry = $null
            }

            $oafParams['InputObject'] = $item
            $os.Process($item) | & { process {
                if (-not $PSItem) {
                    return
                }

                return $PSItem
            }}
        }
    }
    end {
        foreach ($item in $ft.End()) {
            if ($null -ne $item.groupingEntry) {
                $item.groupingEntry = $null
            }

            $oafParams['InputObject'] = $item
            $os.Process($item) | & { process {
                if (-not $PSItem) {
                    return
                }

                return $PSItem
            }}
        }

        $os.End()
    }
}

function Show-DebugLine {
    [Alias('sdl')]
    [CmdletBinding()]
    param(
        [int] $Context = 5
    )
    end {
        if (-not $PSDebugContext) {
            return
        }

        [IScriptExtent] $scriptPosition = $PSDebugContext.InvocationInfo.
            GetType().
            GetProperty('ScriptPosition', 60).
            GetValue($PSDebugContext.InvocationInfo)

        $fullText = $scriptPosition.StartScriptPosition.GetFullScript()
        $hlstart = $scriptPosition.StartLineNumber
        $hlend = $scriptPosition.EndLineNumber

        $start = [Math]::Max($hlstart - $context, 1)
        $end = $hlend + $Context

        $argList = (
            '--language', 'powershell',
            '--highlight-line', "${hlstart}:${hlend}",
            '--line-range', "${start}:${end}",
            '--color=always',
            '--pager=never'
        )

        if ($scriptPosition.File) {
            $argList += '--file-name', $scriptPosition.File, '--style', 'grid,numbers,snip,header-filename'
        } else {
            $argList += '--style', 'grid,numbers,snip'
        }

        $fullText | bat @argList
    }
}

function Get-EnumFlag {
    [Alias('flags')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [ValidateNotNull()]
        [type] $Type,

        [Parameter()]
        [Alias('s')]
        [switch] $AsString,

        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [Alias('m')]
        [hashtable] $AdditionalValueMap = @{}
    )
    begin {
        function MakeFakeEnumObject {
            param($exampleValueInfo, $type, $name, $value)
            $lastBits = $exampleValueInfo.Bits
            $bitsPadding = ($lastBits -replace '[\. ]').Length / 8
            $hexPadding = $exampleValueInfo.Hex.Length - 2
            $info = [PSCustomObject]@{
                PSTypeName = 'UtilityProfile.EnumValueInfo'
                EnumType = $type
                Name = $name
                Value = $value
                Hex = hex -InputObject $value -Padding $hexPadding
                Bits = bits -InputObject $value -Padding $bitsPadding
            }

            $info.psobject.Members.Add(
                [PSMemberSet]::new(
                    'PSStandardMembers',
                    [PSMemberInfo[]](
                        [PSPropertySet]::new(
                            'DefaultDisplayPropertySet',
                            [string[]]('Name', 'Value', 'Hex', 'Bits')))))

            return $info
        }
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($AsString) {
            $null = $PSBoundParameters.Remove('AsString')
            $results = Get-EnumFlag @PSBoundParameters
            $matched = $results | Where-Object Name -ne Unmatched
            $unmatched = $results | Where-Object Name -eq Unmatched
            $resultString = $matched.Name -join ', '
            if (-not $unmatched) {
                return $resultString
            }

            if (-not $matched) {
                return hex -InputObject $unmatched.Value
            }

            return $resultString, (hex -InputObject $unmatched.Value) -join ', '
        }

        if ($null -eq $Type) {
            $Type = $InputObject.GetType()
        }

        if (-not $Type.IsEnum) {
            throw 'Must pass an enum to this function.'
        }

        # Yes this is on purpose
        $valueInfos = [hashtable]::new()

        foreach ($valueInfo in $Type | Get-EnumInfo) {
            $valueInfos[$valueInfo.Name] = $valueInfo
        }

        $unmatchedFlags = $InputObject
        foreach ($valueName in $Type.GetEnumNames()) {
            $value = $Type::$valueName
            if (-not ($InputObject -band $value)) {
                continue
            }

            $unmatchedFlags = $unmatchedFlags -band -bnot $value

            # yield
            $valueInfos[$valueName]
        }

        $exampleValueInfo = $valueInfos.Values | Select-Object -First 1
        foreach ($kvp in $AdditionalValueMap.GetEnumerator()) {
            if (-not ($unmatchedFlags -band $kvp.Value)) {
                continue
            }

            $unmatchedFlags = $unmatchedFlags -band -bnot $kvp.Value

            # yield
            MakeFakeEnumObject $exampleValueInfo $Type $kvp.Key $kvp.Value
        }

        if ($unmatchedFlags) {
            # yield
            MakeFakeEnumObject $exampleValueInfo $Type 'Unmatched' $unmatchedFlags
        }
    }
}

function Get-CommandParameter {
    [Alias('gcp')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNull()]
        [Alias('c')]
        [CommandInfoArgumentConverter()]
        [CommandInfo] $Command,

        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Parameter')]
        [SupportsWildcards()]
        [string[]] $Name,

        [Parameter()]
        [switch] $IncludeCommon
    )
    begin {
        [WildcardPattern[]] $targetParameters = foreach ($target in $Name) {
            [WildcardPattern]::Get($target, [WildcardOptions]::IgnoreCase -bor 'CultureInvariant')
        }

        if (-not $targetParameters) {
            $targetParameters = [WildcardPattern]::Get('*', [WildcardOptions]::IgnoreCase -bor 'CultureInvariant')
        }

        $isHiddenProp = [psnoteproperty].GetProperty('IsHidden', 60)
    }
    process {
        foreach ($set in $Command.ParameterSets) {
            foreach ($param in $set.Parameters) {
                if (-not $IncludeCommon -and [Cmdlet]::CommonParameters.Contains($param.Name)) {
                    continue
                }

                foreach ($target in $targetParameters) {
                    if ($target.IsMatch($param.Name)) {
                        $result = [PSCustomObject]@{
                            PSTypeName = 'Utility.CommandParameterInfo'
                            Set = $set.Name
                            Aliases = $param.Aliases
                            Position = $param.Position
                            IsDynamic = $param.IsDynamic
                            IsMandatory = $param.IsMandatory
                            ValueFromPipeline = $param.ValueFromPipeline
                            ValueFromPipelineByPropertyName = $param.ValueFromPipelineByPropertyName
                            ValueFromRemainingArguments = $param.ValueFromRemainingArguments
                            Type = $param.ParameterType
                            Name = $param.Name
                            Attributes = $param.Attributes
                        }

                        $_set = [psnoteproperty]::new('_set', $set)
                        $isHiddenProp.SetValue($_set, $true)
                        $result.psobject.Properties.Add($_set)

                        $_parameter = [psnoteproperty]::new('_parameter', $param)
                        $isHiddenProp.SetValue($_parameter, $true)
                        $result.psobject.Properties.Add($_parameter)

                        # yield
                        $result
                    }
                }
            }
        }
    }
}

Register-ArgumentCompleter -CommandName Get-CommandParameter -ParameterName Command -ScriptBlock {
    param(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [System.Management.Automation.Language.CommandAst] $commandAst,
        [System.Collections.IDictionary] $fakeBoundParameters
    )
    end {
        if (-not $wordToComplete) {
            $wordToComplete = '*'
        }

        return [CompletionCompleters]::CompleteCommand($wordToComplete)
    }
}

# Mainly just for Get-CommandParameter completers
function Get-InferredCommand {
    [CmdletBinding()]
    param(
        [IDictionary] $FakeBoundParameters,

        [CommandAst] $CommandAst
    )
    end {
        $command = $FakeBoundParameters['Command']
        if ($command -is [CommandInfo]) {
            return $command
        }

        if ($command -and $command -is [string]) {
            return Get-Command $command | Select-Object -First 1
        }

        if ($CommandAst.Parent -isnot [PipelineAst]) {
            return
        }

        $index = $CommandAst.Parent.PipelineElements.IndexOf($CommandAst)
        if ($index -le 0) {
            return
        }

        $previous = $CommandAst.Parent.PipelineElements[$index - 1]
        if ($previous -isnot [CommandAst]) {
            return
        }

        $previousName = $previous.GetCommandName()
        if ($previousName -notin 'gcm', 'Get-Command') {
            return
        }

        $firstArg = $Previous.CommandElements[1]
        if ($firstArg -isnot [StringConstantExpressionAst]) {
            return
        }

        $firstArg = $firstArg.Value
        if (-not $firstArg) {
            return
        }

        return Get-Command $firstArg | Select-Object -First 1
    }
}

Register-ArgumentCompleter -CommandName Get-CommandParameter -ParameterName Name -ScriptBlock {
    param(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [System.Management.Automation.Language.CommandAst] $commandAst,
        [System.Collections.IDictionary] $fakeBoundParameters
    )
    end {
        if (-not $wordToComplete) {
            $wordToComplete = '*'
        } else {
            $wordToComplete += '*'
        }

        $command = Get-InferredCommand -FakeBoundParameters $fakeBoundParameters -CommandAst $commandAst
        if (-not $command) {
            return
        }

        foreach ($parameter in $command.Parameters.Values) {
            if ($parameter.Name -like $wordToComplete) {
                # yield
                [CompletionResult]::new(
                    $parameter.Name,
                    $parameter.Name,
                    [CompletionResultType]::ParameterValue,
                    $parameter.Name)
            }
        }
    }
}

Register-ArgumentCompleter -CommandName Set-LocationPlus -ParameterName Name -ScriptBlock $locationAliasCompleter
Register-ArgumentCompleter -CommandName Resolve-PathAlias -ParameterName Name -ScriptBlock $locationAliasCompleter
Register-ArgumentCompleter -CommandName Edit-FilePlus -ParameterName Name -ScriptBlock $locationAliasCompleter

if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 3) {
    . "$PSScriptRoot\PreviewCommands.ps1"
}

. "$PSScriptRoot\intrinsics.ps1"

Export-ModuleMember -Function *-*, compile -Alias * -Cmdlet *
