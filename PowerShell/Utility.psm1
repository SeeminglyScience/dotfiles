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

# Terrible dirty hack to get around using non-exported classes in some of the function
# parameter blocks. Don't use this in a real module pls
$typeAccel = [ref].Assembly.GetType('System.Management.Automation.TypeAccelerators')
$typeAccel::Add('EncodingArgumentConverterAttribute', [EncodingArgumentConverterAttribute])
$typeAccel::Add('EncodingArgumentConverter', [EncodingArgumentConverterAttribute])
$typeAccel::Add('EncodingArgumentCompleter', [EncodingArgumentCompleter])

function Invoke-VSCode {
    [Alias('code')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ValueFromRemainingArguments)]
        [string]
        $Path
    )
    begin {
        $code = $global:PathToVSCodeOverride | ?? { 'C:\Program Files\Microsoft VS Code\Code.exe' }
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
                for ($i = 2; $i -lt $publicKeyToken.Length; $i += 2) {
                    $asHexString = '0x{0}{1}' -f $publicKeyToken[$i - 1], $publicKeyToken[$i]
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
    [Alias('p')]
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

function Get-GlobalSessionState {
    [CmdletBinding()]
    param()
    end {
        $npi = [BindingFlags]'NonPublic, Instance'
        $context = [EngineIntrinsics].GetField('_context', $npi).GetValue($ExecutionContext)
        return $context.GetType().GetProperty('TopLevelSessionState', $npi).GetValue($context)
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
        $encodedCommand = "Set-Location '$currentPath'" | ConvertTo-Base64String

        $pwsh = [Environment]::GetCommandLineArgs()[0] -replace "($([regex]::Escape("$env:windir\")))Sysnative", '$1system32' -replace 'pwsh\.dll', 'pwsh.exe'
        $process = Start-Process -PassThru -Verb RunAs $pwsh('-NoExit', "-EncodedCommand $encodedCommand")
        if ($process.HasExited) {
            throw "$pwsh exited with code $process.ExitCode"
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

        $sb = [StringBuilder]::new($arguments)
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
    [Alias('e')]
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
            $setupFile = Get-Item $Path -ErrorAction Stop

            if ([string]::IsNullOrEmpty($WorkingDirectory)) {
                $WorkingDirectory = Split-Path $setupFile
            } else {
                $WorkingDirectory = (Resolve-Path $WorkingDirectory -ErrorAction Stop).Path
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
            return
        }

        Use-Location $WorkingDirectory {
            $proc = Start-Process -FilePath $setupFile.FullName -ArgumentList $ArgumentList -PassThru
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
            if ($currentItem -is [Enum]) {
                # yield
                $currentItem.value__
                continue
            }

            if ($currentItem -isnot [ValueType]) {
                # yield
                $currentItem -as [int]
                continue
            }

            if ([array]::IndexOf($script:WellKnownNumericTypes, $currentItem.GetType()) -eq -1) {
                # yield
                $currentItem -as [int]
                continue
            }

            # yield
            $currentItem
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

filter decimal { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([decimal]) } }
filter double { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([double]) } }
filter single { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([single]) } }
filter ulong { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([uint64]) } }
filter long { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([int64]) } }
filter uint { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([uint32]) } }
filter int { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([int]) } }
filter ushort { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([uint16]) } }
filter short { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([int16]) } }
filter byte { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([byte]) } }
filter sbyte { foreach ($currentItem in $PSItem) { Convert-Object -InputObject $currentItem -Type ([sbyte]) } }

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
    [Alias('convert')]
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
        function GetBinaryString([psobject] $item) {
            $numeric = number $item
            if ($null -eq $numeric) {
                return
            }

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

        # You can emit the internal "StopUpstreamCommandsException" used by Select-Object via a
        # SteppablePipeline. This works while other methods don't because the compiler treats
        # method invocation exceptions differently if they come from one of SteppablePipeline's
        # methods.  Instead of wrapping them automatically, they'll emit like they came from our
        # command (sorta).
        $wrappedCommand = { & $ExecutionContext.InvokeCommand.GetCmdletByTypeName([SelectObjectCommand]) -First 1 }
        $stopper = $wrappedCommand.GetSteppablePipeline([CommandOrigin]::Internal)
        $stopper.Begin(<# expectingInput: #> $true)
    }
    process {
        if ($null -eq $InputObject) {
            return
        }

        # yield
        $InputObject

        $amountProcessed++
        if ($amountProcessed -ge $Count) {
            $stopper.Process($PSItem)
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
        $wrappedCommand = { & $ExecutionContext.InvokeCommand.GetCmdletByTypeName([SelectObjectCommand]) -First 1 }
        $stopper = $wrappedCommand.GetSteppablePipeline([CommandOrigin]::Internal)
        $stopper.Begin(<# expectingInput: #> $true)

        $lastPipe = $null
        $isIndexNegative = $Index -lt 0
        if ($Index -lt 0) {
            $keepCount = $Index * -1
            $lastPipe = { Select-LastObject -Count $keepCount }.GetSteppablePipeline([CommandOrigin]::Internal)
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
                $stopper.Process($PSItem)
            }

            $currentIndex++
            return
        }

        $lastPipe.Process($InputObject)
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
        [int] $Count = 1
    )
    begin {
        $currentIndex = 0
    }
    process {
        if ($currentIndex -ge $Count) {
            # yield
            $InputObject
        }

        $currentIndex++
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
