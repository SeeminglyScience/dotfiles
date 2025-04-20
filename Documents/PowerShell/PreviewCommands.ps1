using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Reflection
using namespace PowerShellRun

function Get-AssemblyLoadContext {
    [Alias('galc')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory)]
        [System.Reflection.Assembly] $Assembly
    )
    process {
        [System.Runtime.Loader.AssemblyLoadContext]::GetLoadContext($Assembly)
    }
}

function New-PromptBox {
    param([string] $text)
    end {
        $whitefg = $PSStyle.Foreground.FromRgb(0xffffff)
        $greenfg = $PSStyle.Foreground.FromRgb(0x005000)
        $greenbg = $PSStyle.Background.FromRgb(0x005000)
        $reset = $PSStyle.Reset
        return "${whitefg}${greenbg}${text}${reset}${greenfg}`u{E0B0} "
    }
}

function Invoke-Fzf {
    [Alias('fz')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('t')]
        [string] $Title,

        [Parameter()]
        [Alias('p')]
        [ValidateNotNullOrEmpty()]
        [string] $Preview,

        [Parameter()]
        [Alias('h')]
        [ValidateRange(10, 100)]
        [int] $Height = 60,

        [Parameter()]
        [Alias('f')]
        [ValidateNotNull()]
        [object] $Format,

        [Parameter()]
        [string] $Prompt = (New-PromptBox 'fzf'),

        [Parameter()]
        [string] $Marker = "`u{2713} ",

        [Parameter()]
        [switch] $Multiple,

        [Parameter()]
        [switch] $Sync,

        [Parameter()]
        [string] $AdditionalArguments,

        [Parameter()]
        [string] $Bind,

        [Parameter()]
        [switch] $NoSearch,

        [Parameter()]
        [string] $WithNth,

        [Parameter()]
        [string] $Nth,

        [Parameter(DontShow)]
        [System.Management.Automation.PSCmdlet] $Context
    )
    clean {
        if ($null -eq $process) {
            return
        }

        try {
            if (-not $process.HasExited) {
                $process.Close()
                $process.WaitForExit(200)
            }
        } catch {
        } finally {
            $process.Dispose()
            ($inputWriter)?.Dispose()
        }
    }
    begin {
        class InputWriter : System.IDisposable {
            hidden [Process] $_process
            hidden [System.Collections.Generic.List[psobject]] $_input
            hidden [System.Management.Automation.SteppablePipeline] $_pipe
            hidden [bool] $_headerReceived
            hidden [bool] $_includeHeader

            InputWriter([Process] $process, [System.Management.Automation.SteppablePipeline] $pipe) {
                $this._process = $process
                $this._pipe = $pipe
            }

            [string] GetAdditionalArgs([bool] $skipWithNth) {
                if ($skipWithNth) {
                    return "--delimiter=`"`u{00a0}`"" + ' --read0'
                }

                return "--delimiter=`"`u{00a0}`"" + ' --with-nth=2..-2 --read0'
            }

            [void] WriteObject([psobject] $pso) {
                $index = $this._input.Count
                ($this._input ??= [System.Collections.Generic.List[psobject]]::new()).Add($pso)
                $this._process.StandardInput.Write(
                    ($index, $this.GetInputString($pso) -join "`u{00a0}") + "`0")
            }


            [psobject] GetOutputObject([string] $line) {
                $index, $null = $line -split "`u{00a0}"
                return $this._input[[int]$index]
            }

            hidden [string] GetInputString([psobject] $pso) {
                $line = $null
                if (-not $this._headerReceived) {
                    $this._headerReceived = $true
                    $this._pipe.Begin($true)
                    $lines = $this._pipe.Process([psobject]$pso)
                    $formatItem = $pso | Format-Table
                    if ($formatItem[0].formatEntryInfo?.GetType().Name -in 'RawTextFormatEntry', 'ComplexViewEntry') {
                        $this._process.StandardInput.Write("-1`u{00a0} " + '' + "`u{00a0}`0")
                        $line = $lines[0]
                    } else {
                        $this._process.StandardInput.Write("-1`u{00a0} " + [string]$lines[0] + "`u{00a0}`0")
                        $line = $lines[2]
                    }
                } else {
                    $line = $this._pipe.Process([psobject]$pso)
                }

                if ($global:IsWindows) {
                    $line = $line -replace ('Am' + 'si'), 'Anty'
                }

                return ([string]$line) + "`u{00a0}"
            }

            [void] Dispose() {
                ($this._pipe)?.Dispose()
            }
        }

        class FormatInputWriter : InputWriter {
            hidden [scriptblock] $_searchable
            hidden [scriptblock] $_preview
            hidden [bool] $_skipPreviewCompression

            FormatInputWriter(
                [Process] $process,
                [SteppablePipeline] $pipe,
                [scriptblock] $searchable,
                [scriptblock] $preview,
                [bool] $skipPreviewCompression)
                : base($process, $pipe)
            {
                $this._searchable = $searchable
                $this._preview = $preview
                $this._skipPreviewCompression = $skipPreviewCompression
            }

            static [FormatInputWriter] Create(
                [Process] $process,
                [psobject] $formatObject,
                [SteppablePipeline] $pipe,
                [bool] $skipPreviewCompression)
            {
                if ($formatObject -is [hashtable]) {
                    $searchable = $null
                    $preview = $null
                    foreach ($kvp in $formatObject.GetEnumerator()) {
                        if ([FormatInputWriter]::DoesMatch('Searchable', $kvp.Key)) {
                            $searchable = $kvp.Value
                            continue
                        }

                        if ([FormatInputWriter]::DoesMatch('Preview', $kvp.Key)) {
                            $preview = $kvp.Value
                            continue
                        }

                        throw 'Unknown hashtable key "{0}". Supported values are "Searchable" and "Preview".' -f $kvp.Key
                    }

                    if (-not ($searchable -or $preview)) {
                        throw 'Hashtable must have a key for "Searchable" and/or "Preview".'
                    }

                    return [FormatInputWriter]::new($process, $pipe, $searchable, $preview, $skipPreviewCompression)
                }

                if ($formatObject -is [scriptblock]) {
                    return [FormatInputWriter]::new($process, $pipe, $formatObject, $null, $skipPreviewCompression)
                }

                throw 'Expected "Format" parameter to be a scriptblock or hashtable containing the keys "Searchable" and/or "Preview".'
            }

            hidden static [bool] DoesMatch([string] $target, [string] $key) {
                return $target.StartsWith($key, [System.StringComparison]::OrdinalIgnoreCase)
            }

            [string] GetAdditionalArgs([bool] $skipWithNth) {
                if ($this._skipPreviewCompression) {
                    return ([InputWriter]$this).GetAdditionalArgs($skipWithNth)
                }

                return (& {
                    ([InputWriter]$this).GetAdditionalArgs($skipWithNth)

                    if ($this._preview) {
                        if (-not (Get-Command psudad -ErrorAction Ignore)) {
                            throw [System.InvalidOperationException]::new(
                                'Expected "psudad" console application to be installed. See https://github.com/SeeminglyScience/psudad')
                        }

                        '--preview "psudad {-1}"'
                    }
                }) -join ' '
            }

            hidden [string] GetInputString([psobject] $pso) {
                $stringValue = $null
                if (-not $this._searchable) {
                    $stringValue = ([InputWriter]$this).GetInputString($pso)
                } else {
                    if (-not $this._headerReceived) {
                        $this._process.StandardInput.Write("-1`u{00a0} " + '' + "`u{00a0}`0")
                        $this._headerReceived = $true
                    }

                    $stringValue = $this.Evaluate($this._searchable, $pso) -join "`u{00a0}"
                }

                if (-not $this._preview) {
                    return $stringValue
                }

                $previewString = [string]$this.Evaluate($this._preview, $pso)
                if (-not $this._skipPreviewCompression) {
                    $previewString = $this.GetAsGzBase64($previewString)
                }

                return $stringValue, $previewString -join "`u{00a0}"
            }

            hidden [string] GetAsGzBase64([string] $value) {
                return $this.GetAsGzBase64($value, $false)
            }

            hidden [string] GetAsGzBase64([string] $value, [bool] $alreadyStripped) {
                $ms = [System.IO.MemoryStream]::new()
                $zip = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
                $zip.Write([System.Text.UTF8Encoding]::new().GetBytes($value))
                $zip.Close()
                $result = [convert]::ToBase64String($ms.ToArray())
                if ($result.Length -gt 0x2000) {
                    if ($alreadyStripped) {
                        # Try to avoid the 0x2000 limit if possible, but if stripping escapes
                        # doesn't do it then :shrug:
                        return $result
                    }

                    $stripped = [System.Management.Automation.Host.PSHostUserInterface]::GetOutputString(
                        <# text: #> $value,
                        <# supportsVirtualTerminal: #> $false)

                    return $this.GetAsGzBase64("// Color stripped due to length`n" + $stripped, $true)
                }

                return $result
            }

            hidden [string[]] Evaluate([scriptblock] $sb, [psobject] $pso) {
                return [string[]]$sb.InvokeWithContext(
                    @{},
                    [System.Collections.Generic.List[psvariable]][psvariable]::new.Invoke(@('_', $pso)))
            }
        }

        $Context ??= $PSCmdlet

        $process = $null
        $fullArgs = (
            '--no-mouse',
            "--height=$Height%",
            '--layout=reverse',
            '--info=hidden',
            '--ansi',
            '--border=rounded',
            "--pointer=`u{25c6}",
            "--marker=`"$Marker`"",
            '--cycle',
            '--no-sort',
            '--header-lines=1')

        $allBinds = (
            'change:first',
            'alt-p:up',
            'alt-n:down',
            'alt-0:first',
            'esc:clear-query',
            'ctrl-G:preview-bottom',
            'ctrl-g:preview-top',
            'alt-P:preview-up',
            'alt-N:preview-down') -join ','

        if ($NoSearch) {
            $disabledKeys = (@(
                'a'..'z'
                'A'..'Z'
                0..9
                '!@#$%^&*()_+-={}|\;/?.><`~'.ToCharArray()
            ) | & { process { "${_}:ignore" } }) -join ','
            $allBinds = $disabledKeys, $allBinds, (
                'j:down',
                'k:up',
                'space:toggle',
                'd:half-page-down',
                'u:half-page-up',
                'D:preview-half-page-down',
                'U:preview-half-page-up',
                'a:select-all',
                'J:preview-down',
                'K:preview-up',
                'G:preview-bottom',
                'q:abort',
                'g:first' -join ',') -join ','
            $fullArgs += '--disabled', '--prompt=""'
        } else {
            $fullArgs += "--prompt=`"$Prompt`""
        }

        if ($Bind) {
            $allBinds = $allBinds, $Bind -join ','
        }

        $fullArgs += '--bind="{0}"' -f $allBinds

        if ($Multiple) {
            $fullArgs += '--multi'
        }

        if ($Sync) {
            $fullArgs += '--sync'
        }

        if (-not $MyInvocation.ExpectingInput -and -not $Preview) {
            $fullArgs += '--preview="bat --style=numbers --color=always {}"'
        }

        if ($Preview) {
            $alteredPreview = '@ECHO OFF && for %g in ({{-1}}) do ({0})' -f (
                $Preview -replace '\$_', '%~g' -replace '"', '\"')

            $fullArgs += '--preview="{0}"' -f $alteredPreview
        }

        if ($Header) {
            $fullArgs += '--header="{0}"' -f $Header
        }

        $fullArgsLine = $fullArgs -join ' '
        if ($AdditionalArguments) {
            $fullArgsLine += ' {0}' -f $AdditionalArguments
        }

        $process = [System.Diagnostics.Process]::new()
        $inputWriter = $null
        if ($MyInvocation.ExpectingInput) {
            # Need to create the steppable pipeline in a scope that won't be orphaned
            # https://github.com/PowerShell/PowerShell/issues/17868
            $pipe = { Format-TableRow }.GetSteppablePipeline([System.Management.Automation.CommandOrigin]::Internal)
            $inputWriter = $Format ?
                [FormatInputWriter]::Create($process, $Format, $pipe, (!!$Preview)) :
                [InputWriter]::new($process, $pipe)

            $argsFromInputWriter = $inputWriter.GetAdditionalArgs(!!$WithNth)
            if ($argsFromInputWriter) {
                $fullArgsLine += ' {0}' -f $argsFromInputWriter
            }
        }

        if ($WithNth) {
            $fullArgsLine += " --with-nth $WithNth"
        }

        # if ($PreviewCommand) {
        #     $fullArgsLine += " --preview `"$PreviewCommand`""
        # }

        $psi = [System.Diagnostics.ProcessStartInfo]@{
            FileName = 'fzf'
            Arguments = $fullArgsLine
            WorkingDirectory = & (Get-GlobalSessionState) { $PWD.ProviderPath }
            UseShellExecute = $false
            RedirectStandardOutput = $true
            RedirectStandardError = $false
            RedirectStandardInput = $MyInvocation.ExpectingInput
            StandardInputEncoding = $MyInvocation.ExpectingInput ? [System.Text.UTF8Encoding]::new() : $null
            StandardOutputEncoding = [System.Text.UTF8Encoding]::new()
        }

        $process.StartInfo = $psi
        $hasProcessStarted = $false
    }
    process {
        if ($InputObject -and -not $hasProcessStarted) {
            $hasProcessStarted = $true
            $null = $process.Start()
        }

        if (-not $MyInvocation.ExpectingInput -or -not $InputObject) {
            return
        }

        $onExited = {
            while (-not $process.StandardOutput.EndOfStream) {
                $line = $process.StandardOutput.ReadLine()
                if ($IsWindows) {
                    $line = $line -replace ('Am' + 'si'), 'Anty'
                }
                if ($inputWriter) {
                    $Context.WriteObject($inputWriter.GetOutputObject($line), $false)
                    $process.StandardInput.Close()
                    continue
                }

                # yield
                $line
            }

            EnsureCommandStopperInitialized
            [UtilityProfile.CommandStopper]::Stop($Context)
        }

        if ($process.HasExited) {
            & $onExited
            return
        }

        try {
            if ($InputObject -is [string]) {
                $InputObject = $InputObject -replace ('Am' + 'si'), 'Anty'
            }

            $inputWriter.WriteObject($InputObject)
        } catch [System.IO.IOException] {
            & $onExited
            return
        }
    }
    end {
        if (-not $hasProcessStarted) {
            $hasProcessStarted = $true
            $null = $process.Start()
        }

        if ($MyInvocation.ExpectingInput) {
            $process.StandardInput.Close()
        }

        try {
            while (-not $process.WaitForExit(200)) { }
            while (-not $process.StandardOutput.EndOfStream) {
                $line = $process.StandardOutput.ReadLine()
                if ($inputWriter) {
                    # yield
                    $inputWriter.GetOutputObject($line)
                    continue
                }

                # yield
                $line
            }
        } catch {
            throw
        }
    }
}

function Show-TypeSearch {
    [Alias('wts')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNull()]
        [psobject] $InputObject,

        [Parameter()]
        [switch] $Multiple
    )
    begin {
        $getAccess = { process {
            $str = (& {
                if ($_.IsPublic -or $_.IsNestedPublic) {
                    return 'public'
                }

                if ($_.IsNotPublic -or $_.IsNestedAssembly) {
                    return 'internal'
                }

                if ($_.IsNestedFamily) {
                    return 'protected'
                }

                if ($_.IsNestedFamANDAssem) {
                    return 'private protected'
                }

                if ($_.IsNestedFamORAssem) {
                    return 'internal protected'
                }

                if ($_.IsNestedPrivate) {
                    return 'private'
                }
            }) -join ' '

            return [ClassExplorer.Internal._Format]::Keyword($str, 13)
        }}

        $getMods = { process {
            $str = (& {
                if ($_.BaseType -eq [enum]) {
                    return 'enum'
                }

                if ($_.BaseType -eq [ValueType]) {
                    # if ($_.CustomAttributes.AttributeType.Name -contains 'IsReadOnlyAttribute') {
                    #     'readonly'
                    # }

                    # if ($_.IsByRefLike) {
                    #     'ref'
                    # }

                    return 'struct'
                }

                if ($_.IsInterface) {
                    return 'interface'
                }

                # if ($_.IsSealed -and $_.IsAbstract) {
                #     return 'static class'
                # }

                # if ($_.IsSealed) {
                #     return 'sealed class'
                # }

                # if ($_.IsAbstract) {
                #     return 'abstract class'
                # }

                return 'class'
            }) -join ' '

            return [ClassExplorer.Internal._Format]::Keyword($str)
        }}

        $params = @{
            Prompt = New-PromptBox 'Type:'
            Multiple = $Multiple
            Height = 90
            AdditionalArguments = '--nth 2 --preview-window="right:60%"'
            Format = @{
                Searchable = {
                    # $_ | & $getAccess
                    $_ | & $getMods
                    [ClassExplorer.Internal._Format]::Type($PSItem)
                }
                Preview = {
                    Format-MemberSignature -InputObject $_ -Recurse
                }
            }
            Context = $PSCmdlet
        }

        $pipe = { Invoke-Fzf @params }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($MyInvocation.ExpectingInput)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

function Show-MemberSearch {
    [Alias('wms')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNull()]
        [psobject] $InputObject,

        [Parameter()]
        [switch] $Multiple,

        [Parameter()]
        [switch] $Sync
    )
    begin {
        $params = @{
            WithNth = '2..-3'
            Multiple = $Multiple
            Sync = $Sync
            Height = 90
            AdditionalArguments = '--nth 2 --preview "dnSpy.Console.exe {-2} --md {-1} --no-tokens | bat --language cs --color always --style grid,numbers,snip" --preview-window="right:60%"'
            Prompt = New-PromptBox 'Member:'
            Format = @{
                Searchable = {
                    [ClassExplorer.Internal._Format]::Keyword($PSItem.MemberType.ToString().ToLower())
                    if ($PSItem -is [System.Reflection.ConstructorInfo]) {
                        [ClassExplorer.Internal._Format]::MemberName($PSItem.ReflectedType.Name)
                    } else {
                        [ClassExplorer.Internal._Format]::MemberName($PSItem.Name)
                    }

                    if ($PSItem -is [System.Reflection.MethodBase]) {
                        $sb = [System.Text.StringBuilder]::new()
                        $null = & {
                            $sb = $sb
                            if ($PSItem.IsGenericMethod) {
                                $sb.Append([ClassExplorer.Internal._Format]::Operator('<'))
                                $first = $true
                                foreach ($gp in $PSItem.GetGenericArguments()) {
                                    if ($first) {
                                        $first = $false
                                    } else {
                                        $sb.Append([ClassExplorer.Internal._Format]::Operator(', '))
                                    }

                                    $sb.Append([ClassExplorer.Internal._Format]::Type($gp))
                                }

                                $sb.Append([ClassExplorer.Internal._Format]::Operator('>'))
                            }

                            $sb.Append([ClassExplorer.Internal._Format]::Operator('('))
                            $first = $true
                            foreach ($p in $PSItem.GetParameters()) {
                                if ($first) {
                                    $first = $false
                                } else {
                                    $sb.Append([ClassExplorer.Internal._Format]::Operator(', '))
                                }

                                $sb.Append([ClassExplorer.Internal._Format]::Type($p))
                            }

                            $sb.Append([ClassExplorer.Internal._Format]::Operator(')'))
                        }

                        $sb.ToString()
                    }

                    $_.Module.Assembly.Location
                    $_.MetadataToken
                }
                # Preview = {
                #     Format-MemberSignature -InputObject $_
                # }
            }
            Context = $PSCmdlet
        }

        $pipe = { Invoke-Fzf @params }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($MyInvocation.ExpectingInput)
    }
    process {
        $pipe.Process($PSItem)
    }
    end {
        $pipe.End()
    }
}

enum GitUIKind {
    addrestore = 0
    status = 1
    s = 1
    branch = 2
    b = 2
    commit = 3
    c = 3
    stash = 4
    sh = 4
}

function Show-GitTui {
    [Alias('g')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Position = 0)]
        [GitUIKind] $Kind = [GitUIKind]::addrestore,

        [Alias('s')]
        [switch] $Search,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]] $GitArgs
    )
    end {
        if ($Kind -eq [GitUIKind]::addrestore) {
            Show-GitAddRestoreTui @GitArgs
            return
        }

        if ($Kind -eq [GitUIKind]::status) {
            Show-GitStatusTui @GitArgs
            return
        }

        if ($Kind -eq [GitUIKind]::branch) {
            Show-GitBranchTui -NoSearch:(-not $Search) -Multiple @GitArgs
            return
        }

        if ($Kind -eq [GitUIKind]::commit) {
            Show-GitCommitTui -NoSearch:(-not $Search) -Multiple @GitArgs
            return
        }

        if ($Kind -eq [GitUIKind]::stash) {
            if (-not $GitArgs.Length -or ($GitArgs)?[0] -eq '-m') {
                git stash push --include-untracked
            }
        }
    }
}

function Show-GitCommitTui {
    [CmdletBinding()]
    param(
        [Alias('ns')]
        [switch] $NoSearch,

        [Alias('m')]
        [switch] $Multiple,

        [Alias('nsm', 'mns')]
        [switch] $Both,

        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $GitArgs
    )
    end {
        $previewWindow = $Host.UI.RawUI.WindowSize.Height -lt 20 ?
            'right:50%' :
            'top:75%'

        $invokeFzfSplat = @{
            Format = {
                $prefix, $rest = ($_ -split '(?<=\*) +', 2)
                if (-not $rest) {
                    $prefix
                    return
                }

                $prefix
                $rest -split ' +', 2
            }
            AdditionalArguments = (
                '--preview "git -c color.ui=always diff {3}^^^^! | sed \"/^\x1b\[1m---/d;/^\x1b\[1mindex/d;/^\x1b\[1mdiff --/d;s@^\x1b\[1m+++ .*/@=== @gm\""',
                "--preview-window `"$previewWindow`"") -join ' '
            Height = 90
            NoSearch = $NoSearch
            Multiple = $Multiple
            WithNth = '2..'
            Prompt = (New-PromptBox 'commit')
        }

        $PSNativeCommandArgumentPassing = 'Legacy'
        git -c color.ui=always log --oneline --decorate --abbrev-commit --graph @GitArgs
            | Invoke-Fzf @invokeFzfSplat
            | & { process {
                [System.Management.Automation.Host.PSHostUserInterface]::GetOutputString(
                    (($_ -split '\* +', 2)[1] -split ' +', 2)[0],
                    $false) -replace '\x1b\[m'
            }}
    }
}

function Show-GitBranchTui {
    [CmdletBinding()]
    param(
        [Alias('ns')]
        [switch] $NoSearch,

        [Alias('m')]
        [switch] $Multiple,

        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $GitArgs
    )
    end {
        $previewWindow = $Host.UI.RawUI.WindowSize.Height -lt 20 ?
            'right:50%' :
            'top:40%'

        $invokeFzfSplat = @{
            Format = { ($_ -split ' +', 2)[1], $null }
            AdditionalArguments = (
                '--preview "git -c color.ui=always log --oneline --graph --decorate --abbrev-commit ..{-2}"',
                "--preview-window `"$previewWindow`"") -join ' '
            Height = 60
            NoSearch = $NoSearch
            Multiple = $Multiple
            Prompt = (New-PromptBox branch)
        }

        $PSNativeCommandArgumentPassing = 'Legacy'
        git -c color.branch=always branch -a @GitArgs
            | & { process { $_ -replace 'remotes/' }}
            | Invoke-Fzf @invokeFzfSplat
            | & { process {
                [System.Management.Automation.Host.PSHostUserInterface]::GetOutputString(
                    ($_ -split ' +', 2)[1],
                    $false) -replace '\x1b\[m'
            }}
    }
}

function Show-GitAddRestoreTui {
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $GitArgs
    )
    end {
        $PSNativeCommandArgumentPassing = 'Legacy'
        Show-GitStatusTui -Prompt (New-PromptBox 'stage/unstage') @GitArgs
            | & { process {
                if ($_.Staged) {
                    git restore --staged $_.File
                    return
                }

                git add $_.File
            }}

        git -c color.status=always status
    }
}

function Show-GitStatusTui {
    param(
        [string] $Prompt = (New-PromptBox Status),

        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $GitArgs
    )
    begin {
        function MakeObj {
            param(
                [bool] $staged,
                [string] $mod,
                [string] $file,
                [string] $display
            )
            end {
                $obj = [PSCustomObject]@{
                    Staged = $staged
                    Modifier = $mod
                    File = $file
                    Display = $display
                }

                $obj.psobject.Methods.Add([psscriptmethod]::new('ToString', { $this.File }))
                $obj.psobject.Members.Add(
                    [System.Management.Automation.PSMemberSet]::new(
                        'PSStandardMembers',
                        [System.Management.Automation.PSMemberInfo[]](
                            [System.Management.Automation.PSPropertySet]::new(
                                'DefaultDisplayPropertySet',
                                [string[]]('Staged', 'Modifier', 'File')))))

                return $obj
            }
        }
    }
    end {
        $PSNativeCommandArgumentPassing = 'Legacy'
        $invokeFzfSplat = @{
            Format = { $_.Display, $_.File, $null }
            AdditionalArguments = '--preview-window="right:70%" --preview "git diff HEAD --color=always -- {-2} | sed 1,4d" --exit-0'
            Multiple = $true
            Height = 90
            NoSearch = $true
            Marker = 'S '
            Prompt = $Prompt
            WithNth = 2
        }

        & {
            $textResults = @(git -c color.status=always status --short @GitArgs)
            $parsableResults = @(git status --porcelain=v2 @GitArgs)
            for ($i = 0; $i -lt $textResults.Length; $i++) {
                $display = $textResults[$i]
                $parsable = $parsableResults[$i]
                if ($parsable.StartsWith('?')) {
                    $null, $name = $parsable -split ' ', 2
                    MakeObj $false '??' $name $display
                    continue
                }

                $parts = $parsable -split ' ', 9
                $status = $parts[1]
                $path = $parts[8]
                $isStaged = $status[0] -ne '.'[0]

                MakeObj $isStaged ($status -replace '\.') $path $display
            }
        } | Invoke-Fzf @invokeFzfSplat

        # if ($Preserve) {
        #     return $results
        # }

        # $results | & { process {
        #         $null, $file = $_.Trim() -split ' +', 2

        #         return $file.Trim('"')
        #     }}
    }
}

function Show-GitStashTui {
    param(
        [string] $Prompt = (New-PromptBox Stash),

        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $GitArgs
    )
    begin {
        function MakeObj {
            param(
                [int] $index,
                [string] $message,
                [string] $display
            )
            end {
                $obj = [PSCustomObject]@{
                    Index = $index
                    Message = $message
                    Display = $display
                }

                $obj.psobject.Methods.Add([psscriptmethod]::new('ToString', { $this.Display }))
                $obj.psobject.Members.Add(
                    [System.Management.Automation.PSMemberSet]::new(
                        'PSStandardMembers',
                        [System.Management.Automation.PSMemberInfo[]](
                            [System.Management.Automation.PSPropertySet]::new(
                                'DefaultDisplayPropertySet',
                                [string[]]('Index', 'Message')))))

                return $obj
            }
        }
    }
    end {
        $previewWindow = $Host.UI.RawUI.WindowSize.Height -lt 20 ?
            'right:50%' :
            'top:75%'
            # AdditionalArguments = (
            #     '--preview "git -c color.ui=always diff {3}^^^^! | sed \"/^\x1b\[1m---/d;/^\x1b\[1mindex/d;/^\x1b\[1mdiff --/d;s@^\x1b\[1m+++ .*/@=== @gm\""',
            #     "--preview-window `"$previewWindow`"") -join ' '
        $PSNativeCommandArgumentPassing = 'Legacy'
        $invokeFzfSplat = @{
            Format = { $_.Id, $_.Message, $null }
            AdditionalArguments = "--preview-window=`"$previewWindow`" " + '--preview "git -c color.ui=always stash show -p {1} | sed \"/^\x1b\[1m---/d;/^\x1b\[1mindex/d;/^\x1b\[1mdiff --/d;s@^\x1b\[1m+++ .*/@=== @gm\"" --exit-0'
            Height = 90
            NoSearch = $true
            Prompt = $Prompt
            WithNth = '2..'
        }

        & {
            $textResults = @(git stash list @GitArgs)
            for ($i = 0; $i -lt $textResults.Length; $i++) {
                $display, $message = $textResults[$i] -split ': ', 2
                $id = $display -replace '(stash@\{|\})', ''

                MakeObj $index $message $display
            }
        } | Invoke-Fzf @invokeFzfSplat
    }
}

function Show-WatchPanel {
    param(
        [Parameter()]
        [string] $Header,

        [Parameter()]
        [object] $State = @{},

        [Parameter()]
        [scriptblock] $Getter,

        [Parameter()]
        [scriptblock] $Init,

        [Parameter()]
        [timespan] $Interval = [timespan]::FromSeconds(10)
    )
    clean {
        # Ugh, you can't scroll in an alternate screen buffer without implementing it yourself
        # aaand I'm only ever going to use this in a dedicated window soooo...
        # [Console]::Write("`e[?1049l")
        [Console]::Write("`e[?25h")
        Clear-Host
    }
    begin {
        # [Console]::Write("`e[?1049h")
        Clear-Host
        [Console]::Write("`e[?25l")
        if ($Header) {
            Write-Host $Header
        }
        $variables = [List[psvariable]][psvariable]::new('this', $State)
        $State['AlreadyReturnedIds'] = [HashSet[int]]::new()

        function MaybeWriteResults {
            param($Results, $State, $UniqueIdGetter)
            end {
                if (-not $Results) {
                    return
                }

                if ($UniqueIdGetter) {
                    $Results = foreach ($result in $Results) {
                        $id = $UniqueIdGetter.InvokeWithContext(
                            $null,
                            [List[psvariable]][psvariable]::new('_', $result))

                        if (-not $id -or $id.Count -gt 1 -or -not $id[0] -as [int]) {
                            throw [ErrorRecord]::new(
                                [PSInvalidOperationException]::new('Could not obtain unique ID a result.'),
                                'NoUniqueId',
                                [ErrorCategory]::InvalidData,
                                $result)
                        }

                        if (-not $State['AlreadyReturnedIds'].Add($id[0])) {
                            continue
                        }

                        # yield to $Results
                        $result
                    }
                }

                $lines = @($Results | Out-AnsiFormatting -Stream)
                [array]::Reverse($lines)
                foreach ($line in $lines) {
                    [Console]::Write("`e[1;1f")
                    [Console]::Write("`e[1L")
                    [Console]::Write($line)
                }
            }
        }
    }
    end {
        $State['LastUpdated'] = $null
        if ($Init) {
            $results = $Init.InvokeWithContext($null, [List[psvariable]]::new($variables))
            $State['LastUpdated'] = Get-Date -AsUTC
            MaybeWriteResults $results $State $UniqueIdGetter

            Start-Sleep -Milliseconds $Interval.TotalMilliseconds
        }


        [Console]::Write("`e[1;1f")
        while ($true) {
            $results = $Getter.InvokeWithContext($null, [List[psvariable]]::new($variables))
            $State['LastUpdated'] = Get-Date -AsUTC
            MaybeWriteResults $results $State $UniqueIdGetter

            Start-Sleep -Milliseconds $Interval.TotalMilliseconds
        }
    }
}

function Watch-InvolvedIssue {
    $splat = @{
        Involved = $true
        State = 'Open'
    }

    Show-WatchPanel `
        -Init { Find-Issue @splat } `
        -Getter { Find-Issue @splat -UpdatedSince $this.LastUpdated } `
        -Interval ([timespan]::FromMinutes(5))
}

function Watch-PsesIssue {
    $splat = @(
        '--repo', 'PowerShell/vscode-powershell,PowerShell/PowerShellEditorServices'
    )

    Show-WatchPanel `
        -Init { Find-Issue @splat } `
        -Getter { Find-Issue @splat -UpdatedSince $this.LastUpdated } `
        -Interval ([timespan]::FromMinutes(5))
}

function Watch-ReviewRequested {
    $splat = @{
        ReviewRequested = $true
        State = 'Open'
    }

    Show-WatchPanel `
        -Init { Find-PullRequest @splat } `
        -Getter { Find-PullRequest @splat -UpdatedSince $this.LastUpdated } `
        -Interval ([timespan]::FromMinutes(5))
}

function Get-GithubLabelDisplay {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
    begin {
        $re = $PSStyle.Reset
    }
    process {
        $color = [int]('0x' + $Color)
        $b = [byte]($color -band 0xFF)
        $g = [byte]($color -shr 8 -band 0xFF)
        $r = [byte]($color -shr 16 -band 0xFF)

        $primaryR = [Math]::Min(($r * 1.8), 255)
        $primaryG = [Math]::Min(($g * 1.8), 255)
        $primaryB = [Math]::Min(($b * 1.8), 255)

        $secondaryR = [Math]::Min(($r * 0.33), 255)
        $secondaryG = [Math]::Min(($g * 0.33), 255)
        $secondaryB = [Math]::Min(($b * 0.33), 255)

        $bgPrimary = $PSStyle.Background.FromRgb($primaryR, $primaryG, $primaryB)
        $fgPrimary = $PSStyle.Foreground.FromRgb($primaryR, $primaryG, $primaryB)
        $bgSecondary = $PSStyle.Background.FromRgb($secondaryR, $secondaryG, $secondaryB)
        $fgSecondary = $PSStyle.Foreground.FromRgb($secondaryR, $secondaryG, $secondaryB)

        return "$fgSecondary`u{e0d4}$fgPrimary$bgSecondary $Name $re$fgSecondary`u{e0b0}$re"
    }
}
function Find-Issue {
    [Alias('fiis')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]] $ArgumentList,

        [Parameter()]
        [ValidateSet('Open', 'Closed')]
        [string] $State,

        [Parameter()]
        [string[]] $Filter,

        [Parameter()]
        [datetime] $UpdatedSince,

        [Parameter()]
        [switch] $Involved
    )
    end {
        $PSNativeCommandArgumentPassing = 'Legacy'
        $properties =
            'assignees', 'author', 'authorAssociation', 'body',
            'closedAt', 'commentsCount', 'createdAt', 'id', 'isLocked',
            'isPullRequest', 'labels', 'number', 'repository', 'state',
            'title', 'updatedAt', 'url'

        $argList = ('--json', ($properties -join ','), '--sort', 'updated')

        $queries = @($Filter)
        $queryTemplate = 'map(select({0}))'


        if ($PSBoundParameters.ContainsKey((nameof{$UpdatedSince}))) {
            $queries += ('((.updatedAt | fromdate) > ("{0}" | fromdate))' -f (
                $UpdatedSince.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'")))
        }

        if ($Involved) {
            $argList += '--involves=@me'
        }

        if ($State) {
            $argList += '--state={0}' -f $State.ToLowerInvariant()
        }

        if ($queries) {
            $fullQuery = ($queries -match '.') -join ' and ' -replace '"', '\"'
            $argList += '--jq', ($queryTemplate -f $fullQuery)
        }

        $argList += $ArgumentList

        # gh search issues @argList
        # Write-Host @argList
        gh search issues @argList | Out-String | ConvertFrom-Json | & { process {
            $PSItem.updatedAt = $PSItem.updatedAt.ToLocalTime()
            $PSItem.createdAt = $PSItem.createdAt.ToLocalTime()
            $PSItem.closedAt = $PSItem.closedAt.ToLocalTime()
            $PSItem.pstypenames.Insert(0, 'Utility.Issue')
            $PSItem
        }}
    }
}

function Find-PullRequest {
    [Alias('fipr')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]] $ArgumentList,

        [Parameter()]
        [ValidateSet('Open', 'Closed', 'Merged', 'Draft')]
        [string] $State,

        [Parameter()]
        [string[]] $Filter,

        [Parameter()]
        [datetime] $UpdatedSince,

        [Parameter()]
        [switch] $ReviewRequested,

        [Parameter()]
        [switch] $IncludeBots
    )
    end {
        $PSNativeCommandArgumentPassing = 'Legacy'
        $properties =
            'assignees', 'author', 'authorAssociation', 'body', 'closedAt',
            'commentsCount', 'createdAt', 'id', 'isLocked', 'labels', 'number',
            'repository', 'state', 'title', 'updatedAt', 'url'

        $argList = ('--json', ($properties -join ','), '--sort', 'updated')

        $queries = @($Filter)
        $queryTemplate = 'map(select({0}))'

        if (-not $IncludeBots) {
            $queries += '.author.type != "Bot"'
        }

        if ($PSBoundParameters.ContainsKey((nameof{$UpdatedSince}))) {
            $queries += ('((.updatedAt | fromdate) > ("{0}" | fromdate))' -f (
                $UpdatedSince.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'")))
        }

        if ($State -eq 'merged') {
            $argList += '--merged'
        } elseif ($State -eq 'draft') {
            $argList += '--draft'
        } elseif ($State) {
            $argList += '--state={0}' -f $State.ToLowerInvariant()
        }

        if ($ReviewRequested) {
            $argList += '--review-requested=@me'
        }

        if ($queries) {
            $fullQuery = ($queries -match '.') -join ' and ' -replace '"', '\"'
            $argList += '--jq', ($queryTemplate -f $fullQuery)
        }

        $argList += $ArgumentList

        # gh search prs @argList
        gh search prs @argList | ConvertFrom-Json | & { process {
            $PSItem.updatedAt = $PSItem.updatedAt.ToLocalTime()
            $PSItem.createdAt = $PSItem.createdAt.ToLocalTime()
            $PSItem.closedAt = $PSItem.closedAt.ToLocalTime()
            $PSItem.pstypenames.Insert(0, 'Utility.PullRequest')
            $PSItem
        }}
    }
}

function New-Allocation {
    [Alias('alloc')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [int] $Length,

        [Parameter(Position = 1)]
        [type] $Type,

        [Parameter()]
        [switch] $CoTaskMem
    )
    end {
        $cb = $Length
        if ($Type) {
            return [ptr]::Alloc($Type, $cb)
        }

        if ($CoTaskMem) {
            if ($Type) { throw 'sorry, lazy' }

            return [ptr][System.Runtime.InteropServices.Marshal]::AllocCoTaskMem($cb)
        }

        return [ptr]::Alloc($cb)
    }
}

function Revoke-Allocation {
    [CmdletBinding()]
    [Alias('free')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [IntPtr] $Pointer,

        [Parameter()]
        [switch] $CoTaskMem,

        [Parameter()]
        [switch] $Bstr
    )
    end {
        if ($CoTaskMem) {
            [System.Runtime.InteropServices.Marshal]::FreeCoTaskMem($Pointer)
            return
        }

        if ($Bstr) {
            [System.Runtime.InteropServices.Marshal]::FreeBSTR($Pointer)
            return
        }

        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)
    }
}

enum StringMarshalType {
    None
    Ansi
    BStr
    Unicode
    Utf8
}

function Read-Memory {
    [CmdletBinding(PositionalBinding = $false)]
    [Alias('read')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [IntPtr] $Pointer,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Single')]
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [Alias('as')]
        [type] $Type,

        [Parameter(Position = 2, ParameterSetName = 'Single')]
        [StringMarshalType] $StringMarshalType,

        [Parameter()]
        [Alias('o')]
        [int] $Offset,

        [Parameter(ParameterSetName = 'Block')]
        [Alias('c')]
        [int] $Count
    )
    end {
        $Pointer = [IntPtr]::Add($Pointer, $Offset)

        if ($PSCmdlet.ParameterSetName -eq 'Block') {
            $block = [byte[]]::new($Count)
            for ($i = 0; $i -lt $Count; $i++) {
                $block[$i] = [System.Runtime.InteropServices.Marshal]::ReadByte(
                    [IntPtr]::Add($Pointer, $i))
            }

            return ,$block
        }

        if ($Type -eq [string]) {
            if ($StringMarshalType -eq [StringMarshalType]::Ansi) {
                return [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($Pointer)
            }

            if ($StringMarshalType -eq [StringMarshalType]::BStr) {
                return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Pointer)
            }

            if ($StringMarshalType -eq [StringMarshalType]::Utf8) {
                return [System.Runtime.InteropServices.Marshal]::PtrToStringUTF8($Pointer)
            }

            return [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Pointer)
        }

        if ([type] -eq [byte]) {
            return [System.Runtime.InteropServices.Marshal]::ReadByte($Pointer)
        }

        if ([type] -eq [short]) {
            return [System.Runtime.InteropServices.Marshal]::ReadInt16($Pointer)
        }

        if ([type] -eq [int]) {
            return [System.Runtime.InteropServices.Marshal]::ReadInt32($Pointer)
        }

        if ([type] -eq [long]) {
            return [System.Runtime.InteropServices.Marshal]::ReadInt64($Pointer)
        }

        if ([type] -eq [IntPtr]) {
            return [System.Runtime.InteropServices.Marshal]::ReadIntPtr($Pointer)
        }

        return [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer, [type]$Type)
    }
}

function New-MarshalledString {
    [CmdletBinding()]
    [Alias('marshal')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Value,

        [Parameter(Position = 1)]
        [StringMarshalType] $MarshalType,

        [Parameter()]
        [switch] $CoTaskMem
    )
    end {
        if ($MarshalType -eq [StringMarshalType]::BStr) {
            return [ptr[char]][System.Runtime.InteropServices.Marshal]::StringToBSTR($Value)
        }

        if ($CoTaskMem) {
            if ($MarshalType -eq [StringMarshalType]::Ansi) {
                return [ptr[byte]][System.Runtime.InteropServices.Marshal]::StringToCoTaskMemAnsi($Value)
            }

            if ($MarshalType -eq [StringMarshalType]::Utf8) {
                return [ptr[byte]][System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUTF8($Value)
            }

            return [ptr[char]][System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUni($Value)
        }

        if ($MarshalType -eq [StringMarshalType]::Ansi) {
            return [ptr[byte]][System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($Value)
        }

        if ($MarshalType -eq [StringMarshalType]::Utf8) {
            return [ptr[byte]][System.Runtime.InteropServices.Marshal]::StringToHGlobalUTF8($Value)
        }

        return [ptr[char]][System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($Value)
    }
}

function Write-Memory {
    [CmdletBinding(PositionalBinding = $false)]
    [Alias('put')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [IntPtr] $Pointer,

        [Parameter(Mandatory, Position = 1)]
        [object] $Value,

        [Parameter()]
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [Alias('as')]
        [type] $Type,

        [Parameter()]
        [Alias('o')]
        [int] $Offset
    )
    end {
        if (-not $Type) {
            if ($Value -is [array]) {
                $Type = $Value[0].GetType()
            } else {
                $Type = $Value.GetType()
            }
        }

        $Pointer = [IntPtr]::Add($Pointer, $Offset)
        if ($Type -in [string[]], [string]) {
            throw
        }

        $size = [System.Runtime.InteropServices.Marshal]::SizeOf([type]$Type)
        $i = 0
        foreach ($singleValue in $Value) {
            if ([type] -eq [byte]) {
                [System.Runtime.InteropServices.Marshal]::WriteByte($Pointer, $i, $singleValue)
                $i += $size
                continue
            }

            if ([type] -eq [short]) {
                [System.Runtime.InteropServices.Marshal]::WriteInt16($Pointer, $i, $singleValue)
                $i += $size
                continue
            }

            if ([type] -eq [int]) {
                [System.Runtime.InteropServices.Marshal]::WriteInt32($Pointer, $i, $singleValue)
                $i += $size
                continue
            }

            if ([type] -eq [long]) {
                [System.Runtime.InteropServices.Marshal]::WriteInt64($Pointer, $i, $singleValue)
                $i += $size
                continue
            }

            if ([type] -eq [IntPtr]) {
                [System.Runtime.InteropServices.Marshal]::WriteIntPtr($Pointer, $i, $singleValue)
                $i += $size
                continue
            }

            [System.Runtime.InteropServices.Marshal]::StructureToPtr(
                [object][LanguagePrimitives]::ConvertTo($singleValue, $Type),
                [IntPtr]::Add($Pointer, $i),
                $true)

            $i += $size
        }
    }
}

function Clear-Memory {
    [CmdletBinding()]
    [Alias('zero')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [IntPtr] $Pointer,

        [Parameter(Mandatory, Position = 1)]
        [int] $Size,

        [Parameter(Position = 3)]
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [Alias('as')]
        [type] $Type
    )
    end {
        if ($Type) {
            $Size = $Size * [System.Runtime.InteropServices.Marshal]::SizeOf([type]$Type)
        }

        for ($i = 0; $i -lt $Size; $i++) {
            [System.Runtime.InteropServices.Marshal]::WriteByte($Pointer, $i, 0)
        }
    }
}

function Get-MarshalledSize {
    [CmdletBinding()]
    [Alias('size')]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter([ClassExplorer.TypeFullNameArgumentCompleter])]
        [type] $Type
    )
    end {
        return [System.Runtime.InteropServices.Marshal]::SizeOf([type]$Type)
    }
}

$DotNetStore = $env:DOTNET_STORE ?? 'C:/dotnet'

# Trying to manage a ton of different dotnet installs for a ton of projects with
# global.json's demanding specific versions can be annoying. This aims to fix that.
function Install-DotNet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [SemanticVersion] $Version
    )
    end {
        $store = $script:DotNetStore
        $versions = Get-ChildItem -LiteralPath $store -Directory | Where-Object Name -notin current, stable
        if ($versions.Name -contains $Version.ToString()) {
            return
        }

        $targetPath = Join-Path $store $Version
        $dotnetInstall = Get-Command $store/dotnet-install.ps1 -ErrorAction Ignore
        if (-not $dotnetInstall) {
            Invoke-WebRequest https://dot.net/v1/dotnet-install.ps1 -OutFile $store/dotnet-install.ps1 -ErrorAction Stop
            $dotnetInstall = Get-Command $store/dotnet-install.ps1 -ErrorAction Stop
        }

        & $dotnetInstall -Version $Version -InstallDir $targetPath

        if (-not ($versions.Name | Where-Object { ([SemanticVersion]$_) -gt $Version })) {
            if (Test-Path -LiteralPath $store/current) {
                Remove-Item -LiteralPath $store/current
            }

            $null = New-Item -ItemType SymbolicLink -Path $store/current -Value $targetPath -ErrorAction Stop
        }

        if ($Version.PreReleaseLabel) {
            return
        }

        $stableVersions = $versions.Name.ForEach([SemanticVersion]).
            Where{ -not $_.PreReleaseLabel }

        if (-not ($stableVersions | Where-Object { $_ -gt $Version })) {
            if (Test-Path -LiteralPath $store/stable) {
                Remove-Item -LiteralPath $store/stable
            }

            $null = New-Item -ItemType SymbolicLink -Path $store/stable -Value $targetPath -ErrorAction Stop
        }
    }
}

# Mainly to make it easy to check if an SDK release is live, or to simply get the
# latest version. Typically for when I'm on release duty.
function Get-LatestDotNet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Channel
    )
    end {
        function _normalize {
            param([string] $value)
            end {
                if ($value -eq 'lts') {
                    return 'LTS'
                }

                if ($value -eq 'sts') {
                    return 'STS'
                }

                return "$([int]$value).0"
            }
        }

        Invoke-RestMethod "https://dotnetcli.azureedge.net/dotnet/Sdk/$(_normalize $Channel)/latest.version"
    }
}

# Try to determine what project I'm trying to build and just do it for me. At some point
# I need to make the `AdditionalArguments` add the note property to make splatting it
# work for PowerShell commands.
function Invoke-ProjectBuild {
    [Alias('b')]
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter()]
        [Alias('c')]
        [string] $Configuration,

        [Parameter()]
        [Alias('a')]
        [switch] $All,

        [Parameter(ValueFromRemainingArguments)]
        [string[]] $AdditionalArguments
    )
    end {
        $location = $PSCmdlet.SessionState.Path.CurrentFileSystemLocation.ProviderPath
        if (Test-Path -LiteralPath (Join-Path $location global.json)) {
            $json = Get-Content -Raw -LiteralPath (Join-Path $location global.json) | ConvertFrom-Json
            if ($json.sdk.version) {
                if ((dotnet --version) -ne $json.sdk.version) {
                    Install-DotNet $json.sdk.version
                    Add-PathEntry -Path (Join-Path $script:DotNetStore $json.sdk.version) -Prefix
                }
            }
        }

        if (Test-Path -LiteralPath (Join-Path $location PowerShell.sln)) {
            if (-not (Get-Module build)) {
                Import-Module (Join-Path $location build.psm1) -Global
            }

            $splat = @{
                ReleaseTag = "v$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).0-preview.99"
                Output = Join-Path ($env:PWSH_STORE ?? 'C:\pwsh') dev
            }

            $splat['Configuration'] = $Configuration ? $Configuration : 'Debug'

            if ($All) {
                Start-PSBuild @splat -Restore -PSModuleRestore -ResGen -TypeGen
                return
            }

            Start-PSBuild @splat
            return
        }

        if (Test-Path -LiteralPath (Join-Path $location build.ps1)) {
            $build = Get-Command (Join-Path $location build.ps1)
            if ($Configuration -and $build.Parameters['Configuration']) {
                & $build -Configuration $Configuration
                return
            }

            & $build
            return
        }

        $PSNativeCommandArgumentPassing = 'Legacy'
        if ($Configuration) {
            $argList = @(
                $AdditionalArguments
                '--configuration', $Configuration)
        } else {
            $argList = $AdditionalArguments
        }

        dotnet publish @argList
    }
}

$IsSlashInited = $false
function Invoke-CustomPSRun {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter()]
        [hashtable] $PSRunParams = @{},

        [Parameter(ValueFromPipeline)]
        [psobject] $InputObject
    )
    clean { $pipe -is [SteppablePipeline] ? $pipe.Clean() : $() }
    begin {
        class PropertyNameOrIndex {
            [object] $Value

            [bool] $IsIndex

            PropertyNameOrIndex([string] $value) {
                $this.Value = $value
                $this.IsIndex = $false
            }

            PropertyNameOrIndex([int] $value) {
                $this.Value = $value
                $this.IsIndex = $true
            }

            [object] Apply([psobject] $source) {
                if ($this.IsIndex) {
                    return $source[$this.Value]
                }

                return $source.($this.Value)
            }
        }

        class ObjectPath {
            hidden static [char[]] $s_toFind = '.', '['

            [PropertyNameOrIndex[]] $Entries

            ObjectPath([string] $path) {
                $next = $path.IndexOfAny($this::s_toFind, 0)
                $this.Entries = while ($next -ne -1) {
                    if ($path[$next] -eq '.') {
                        if ($next -eq ($path.Length - 1)) {
                            throw [InvalidOperationException]::new('Last character cannot be "."')
                        }

                        $propStart = $next + 1
                        $next = $path.IndexOfAny($this::s_toFind, $propStart)
                        if ($next -eq -1) {
                            [PropertyNameOrIndex]$path.Substring($propStart)
                            break
                        }

                        $length = $next - $propStart
                        if (-not $length) {
                            throw [InvalidOperationException]::new(
                                ('Property name starting at offset {0} is empty.' -f $next))
                        }

                        [PropertyNameOrIndex]$path.Substring($propStart, $length)
                        continue
                    }

                    $indexStart = $next + 1
                    if ($indexStart -eq $path.Length) {
                        throw [InvalidOperationException]::new('Last character cannot be "["')
                    }


                    $indexEnd = $path.IndexOf(']'[0], $indexStart)
                    if ($indexEnd -eq -1) {
                        throw [InvalidOperationException]::new(
                            ('Index expression starting at index {0} is missing the terminating "]" character' -f $indexStart))
                    }

                    if ($indexEnd -eq $indexStart) {
                        throw [InvalidOperationException]::new(
                            ('Index value starting at offset {0} is empty.' -f $indexStart))
                    }

                    $indexValue = $path.Substring($indexStart, $indexEnd - $indexStart)
                    $indexValue -match '\d+' ? [PropertyNameOrIndex]::new([int]$indexValue) : [PropertyNameOrIndex]$indexValue

                    $next = $indexEnd + 1
                    if ($next -eq $path.Length) {
                        break
                    }

                    $nextChar = $path[$next]
                    if ($nextChar -notin $this::s_toFind) {
                        throw [InvalidOperationException]::new(
                            ('Expected "." or "[" at offset {0}.' -f $next))
                    }

                    continue
                }
            }

            [object] Apply([psobject] $source) {
                $obj = $source
                foreach ($entry in $this.Entries) {
                    $obj = $entry.Apply($obj)
                }

                return $obj
            }
        }

        class Transform {
            [string] $PropertyName

            [scriptblock] $Script


        }

        function ProcessArg {
            param([object] $arg) end {
                if ($null -eq $arg) {
                    return $null
                }

                if ($arg -is [hashtable]) {
                    return $arg
                }

                if ($arg -is [scriptblock]) {
                    return @{ Expression = $arg }
                }

                return @{ PropertyName = [string]$arg }
            }
        }

        function ProcessInput {
            param([ref] $arg, [object] $pipelineObject) end {
                if ($null -eq $arg.Value) {
                    return $null
                }

                if ($null -ne $arg.Value -and $arg.Value -isnot [hashtable]) {
                    $arg.Value = ProcessArg $arg.Value
                }
            }
        }

        [PowerShellRun.SelectorOption] $options = Get-PSRunDefaultSelectorOption
        $slashKey = default([PowerShellRun.Key])
        $slashKey.value__ = 0x1000

        if (-not $script:IsSlashInited) {
            $field = Find-Type -Force -FullName PowerShellRun.KeyInput
                | Find-Member -Static -Force _keyConsoleKeyTable

            $value = $field.GetValue($null)
            [Array]::Resize(
                [ref] $value,
                $value.Length + 1)

            $value[-1] = [ValueTuple[PowerShellRun.Key, ConsoleKey]]::new(
                $slashKey,
                [ConsoleKey]::Oem2)

            $field.SetValue($null, $value)
            $script:IsSlashInited = $true
        }

        $options.KeyBinding.QuitKeys = [PowerShellRun.KeyCombination]::new('Ctrl', 'C')
        $options.KeyBinding.EnableTextInputInRemapMode = $false
        $options.KeyBinding.InitialRemapMode = $true
        $options.KeyBinding.RemapModeExitKeys = [PowerShellRun.KeyCombination]::new('None', $slashKey)
        $options.KeyBinding.RemapModeEnterKeys = [PowerShellRun.KeyCombination]::new('None', 'Enter')

        $remaps = @{
            j = 'DownArrow'
            k = 'UpArrow'
            q = 'ctrl+c'
            Space = 'Tab'
        }

        $options.KeyBinding.RemapKeys = foreach ($kvp in $remaps.GetEnumerator()) {
            [PowerShellRun.RemapKey]::new([PowerShellRun.KeyCombination]::new($kvp.Key), [PowerShellRun.KeyCombination]::new($kvp.Value))
        }

        # $options.KeyBinding.RemapKeys = @(
        #     [PowerShellRun.RemapKey]::new([PowerShellRun.KeyCombination]::new('j'), [PowerShellRun.KeyCombination]::new('DownArrow'))
        #     [PowerShellRun.RemapKey]::new([PowerShellRun.KeyCombination]::new('k'), [PowerShellRun.KeyCombination]::new('UpArrow'))
        #     [PowerShellRun.RemapKey]::new([PowerShellRun.KeyCombination]::new('q'), [PowerShellRun.KeyCombination]::new('Ctrl', 'C'))
        #     [PowerShellRun.RemapKey]::new([PowerShellRun.KeyCombination]::new('Space'), [PowerShellRun.KeyCombination]::new('Tab'))
        # )

        $bg = '282828'
        $hl = '303030'
        $line = '5f5f5f'
        $fg = 'e4e4e4'

        $options.Theme.NameFocusStyle = [PowerShellRun.FontStyle]::Default
        $options.Theme.NameFocusHighlightStyle = [PowerShellRun.FontStyle]::Default
        $options.Theme.DescriptionFocusStyle = [PowerShellRun.FontStyle]::Default
        $options.Theme.DescriptionFocusHighlightStyle = [PowerShellRun.FontStyle]::Default

        $focusBg = [PowerShellRun.FontColor]::FromHex('#303030')
        $focusFg = [PowerShellRun.FontColor]::FromHex('#e4e4e4')

        $border = [PowerShellRun.FontColor]::FromHex("#5a5a5a")

        $markerFg = [PowerShellRun.FontColor]::FromHex('#d7005f')

        $options.Theme.SearchBarBorderForegroundColor = $border

        $options.Theme.MarkerForegroundColor = $markerFg
        $options.Theme.PromptForegroundColor = $markerFg
        $options.Theme.CursorForegroundColor = $markerFg

        $options.Theme.DescriptionHighlightForegroundColor = $focusFg
        $options.Theme.DescriptionFocusHighlightForegroundColor = $focusFg
        $options.Theme.NameHighlightForegroundColor = $focusFg
        $options.Theme.NameFocusHighlightForegroundColor = $focusFg
        $options.Theme.IconFocusForegroundColor = $focusFg
        $options.Theme.NameFocusForegroundColor = $focusFg
        $options.Theme.DescriptionFocusForegroundColor = $focusFg
        $options.Theme.ActionWindowCursorForegroundColor = $focusFg

        $options.Theme.MarkerBoxBackgroundColor = $focusBg
        $options.Theme.NameFocusBackgroundColor = $focusBg
        $options.Theme.DescriptionFocusBackgroundColor = $focusBg
        $options.Theme.DescriptionHighlightBackgroundColor = $focusBg
        $options.Theme.DescriptionFocusHighlightBackgroundColor = $focusBg
        $options.Theme.NameHighlightBackgroundColor = $focusBg
        $options.Theme.NameFocusHighlightBackgroundColor = $focusBg
        $options.Theme.IconFocusBackgroundColor = $focusBg
        $options.Theme.CursorBackgroundColor = $focusBg
        $options.Theme.ActionWindowCursorBackgroundColor = $focusBg

        $pipe = { Invoke-PSRunSelectorCustom -Option $options @PSRunParams }.GetSteppablePipeline($MyInvocation.CommandOrigin)
        $pipe.Begin($MyInvocation.ExpectingInput)
    }
    process {
        if (-not $InputObject) {
            return
        }

        $entry = [PowerShellRun.SelectorEntry]::new()
        $entry.Name = $InputObject
        $entry.Description = 'whaaat'
        $entry.UserData = $InputObject
        # $entry
        $PSRunParams['Entry'] = $entry
        $pipe.Process($entry)
    }
    end {
        $result = $pipe.End()
        if ($result.KeyCombination.Modifier -eq 'Ctrl' -and $result.KeyCombination.Key -eq 'c') {
            throw [PipelineStoppedException]::new()
        }

        $result
    }
}

function Get-CustomDefaultSelectorOption {
    end {
        [PowerShellRun.SelectorOption] $options = Get-PSRunDefaultSelectorOption
        $slashKey = default([PowerShellRun.Key])
        $slashKey.value__ = 0x1000

        if (-not $script:IsSlashInited) {
            $field = Find-Type -Force -FullName PowerShellRun.KeyInput
                | Find-Member -Static -Force _keyConsoleKeyTable

            $value = $field.GetValue($null)
            [Array]::Resize(
                [ref] $value,
                $value.Length + 1)

            $value[-1] = [ValueTuple[PowerShellRun.Key, ConsoleKey]]::new(
                $slashKey,
                [ConsoleKey]::Oem2)

            $field.SetValue($null, $value)
            $script:IsSlashInited = $true
        }

        $options.KeyBinding.RestartKeys = [PowerShellRun.KeyCombination]::new('Ctrl', 'P')
        $options.KeyBinding.ActionWindowOpenKeys = [PowerShellRun.KeyCombination]::new('Ctrl', 'H')
        $options.KeyBinding.QuitKeys = [PowerShellRun.KeyCombination]::new('Ctrl', 'C')
        $options.KeyBinding.PageDownKeys = [PowerShellRun.KeyCombination]::new('Ctrl', 'F')
        $options.KeyBinding.PageUpKeys = [PowerShellRun.KeyCombination]::new('Ctrl', 'B')
        $options.KeyBinding.PreviewPageDownKeys = [PowerShellRun.KeyCombination]::new('Ctrl, Shift', 'F')
        $options.KeyBinding.PreviewPageUpKeys = [PowerShellRun.KeyCombination]::new('Ctrl, Shift', 'B')
        $options.KeyBinding.EnableTextInputInRemapMode = $false
        $options.KeyBinding.InitialRemapMode = $true
        $options.KeyBinding.RemapModeExitKeys = [PowerShellRun.KeyCombination]::new('None', $slashKey)
        $options.KeyBinding.RemapModeEnterKeys = [PowerShellRun.KeyCombination]::new('None', 'Enter')

        $remaps = @{
            j = 'DownArrow'
            k = 'UpArrow'
            q = 'ctrl+c'
            Spacebar = 'Tab'
            'shift+j' = 'shift+DownArrow'
            'shift+k' = 'shift+UpArrow'
            'shift+f' = 'ctrl+shift+f'
            'shift+b' = 'ctrl+shift+b'
        }

        $options.KeyBinding.RemapKeys = foreach ($kvp in $remaps.GetEnumerator()) {
            [PowerShellRun.RemapKey]::new([PowerShellRun.KeyCombination]::new($kvp.Key), [PowerShellRun.KeyCombination]::new($kvp.Value))
        }

        $bg = '282828'
        $hl = '303030'
        $line = '5f5f5f'
        $fg = 'e4e4e4'

        $options.Theme.NameFocusStyle = [PowerShellRun.FontStyle]::Default
        $options.Theme.NameFocusHighlightStyle = [PowerShellRun.FontStyle]::Default
        $options.Theme.DescriptionFocusStyle = [PowerShellRun.FontStyle]::Default
        $options.Theme.DescriptionFocusHighlightStyle = [PowerShellRun.FontStyle]::Default

        $focusBg = [PowerShellRun.FontColor]::FromHex('#303030')
        $focusFg = [PowerShellRun.FontColor]::FromHex('#e4e4e4')

        $border = [PowerShellRun.FontColor]::FromHex("#5a5a5a")

        $markerFg = [PowerShellRun.FontColor]::FromHex('#d7005f')

        $options.Theme.SearchBarBorderForegroundColor = $border

        $options.Theme.MarkerForegroundColor = $markerFg
        $options.Theme.PromptForegroundColor = $markerFg
        $options.Theme.CursorForegroundColor = $markerFg

        $options.Theme.DescriptionHighlightForegroundColor = $focusFg
        $options.Theme.DescriptionFocusHighlightForegroundColor = $focusFg
        $options.Theme.NameHighlightForegroundColor = $focusFg
        $options.Theme.NameFocusHighlightForegroundColor = $focusFg
        $options.Theme.IconFocusForegroundColor = $focusFg
        $options.Theme.NameFocusForegroundColor = $focusFg
        $options.Theme.DescriptionFocusForegroundColor = $focusFg
        $options.Theme.ActionWindowCursorForegroundColor = $focusFg

        $options.Theme.MarkerBoxBackgroundColor = $focusBg
        $options.Theme.NameFocusBackgroundColor = $focusBg
        $options.Theme.DescriptionFocusBackgroundColor = $focusBg
        $options.Theme.DescriptionHighlightBackgroundColor = $focusBg
        $options.Theme.DescriptionFocusHighlightBackgroundColor = $focusBg
        $options.Theme.NameHighlightBackgroundColor = $focusBg
        $options.Theme.NameFocusHighlightBackgroundColor = $focusBg
        $options.Theme.IconFocusBackgroundColor = $focusBg
        $options.Theme.CursorBackgroundColor = $focusBg
        $options.Theme.ActionWindowCursorBackgroundColor = $focusBg

        return $options
    }
}

Set-PSRunDefaultSelectorOption (Get-CustomDefaultSelectorOption)

function Invoke-WithEnv {
    [CmdletBinding()]
    param(
        [string] $Command,
        [string] $ArgumentList,
        [hashtable] $Variables = @{}
    )
    begin {
        [NoRunspaceAffinity()]
        class ProcessReader {
            [Process] $Process
            [PSCmdlet] $Context
            [System.Threading.Tasks.Task] $StdOutTask
            [System.Threading.Tasks.Task] $StdErrTask
            [System.Threading.Tasks.Task[]] $Tasks = [System.Threading.Tasks.Task[]]::new(2)

            ProcessReader([Process] $process, [PSCmdlet] $context) {
                $this.Process = $process
                $this.Context = $context
            }

            [bool] WaitForAny() {
                if (-not $this.StdOutTask -and -not $this.Process.StandardOutput.EndOfStream) {
                    $this.StdOutTask = $this.Process.StandardOutput.ReadLineAsync()
                }

                $shouldReadStdErr = $this.Process.StartInfo.RedirectStandardError -and
                    -not $this.StdErrTask -and
                    -not $this.Process.StandardError.EndOfStream

                if ($shouldReadStdErr) {
                    $this.StdErrTask = $this.Process.StandardError.ReadLineAsync()
                }

                if ($this.StdOutTask -and $this.StdErrTask) {
                    $this.Tasks[0] = $this.StdOutTask
                    $this.Tasks[1] = $this.StdErrTask

                    while ($true) {
                        $index = [System.Threading.Tasks.Task]::WaitAny($this.Tasks, 200)
                        if ($index -eq -1) {
                            continue
                        }

                        if ($index -eq 0) {
                            $this.ProcessStdOut($this.StdOutTask)
                            return $true
                        }

                        $this.ProcessStdErr($this.StdErrTask)
                        return $true
                    }
                }

                if ($this.StdOutTask) {
                    while (-not $this.StdOutTask.AsyncWaitHandle.WaitOne(200)) { }
                    $this.ProcessStdOut($this.StdOutTask)
                    return $true
                }

                if ($this.StdErrTask) {
                    while (-not $this.StdErrTask.AsyncWaitHandle.WaitOne(200)) { }
                    $this.ProcessStdErr($this.StdErrTask)
                    return $true
                }

                return $false
            }

            [void] ProcessStdOut([System.Threading.Tasks.Task] $task) {
                $line = $task.GetAwaiter().GetResult()
                $this.StdOutTask = $null
                $this.Context.WriteObject($line)
            }

            [void] ProcessStdErr([System.Threading.Tasks.Task] $task) {
                $line = $task.GetAwaiter().GetResult()
                $er = [ErrorRecord]::new(
                    [RemoteException]::new($line),
                    'NativeCommandError',
                    [ErrorCategory]::NotSpecified,
                    $line)

                $this.StdErrTask = $null
                $this.Context.WriteError($er)
            }
        }
    }
    end {
        $startInfo = [ProcessStartInfo]::new($Command, $ArgumentList)
        # $startInfo = [ProcessStartInfo]@{
        #     # FileName = $Command
        #     # Arguments = $ArgumentList
        #     RedirectStandardOutput = $true
        #     RedirectStandardError = $true
        #     RedirectStandardInput = $true
        #     UseShellExecute = $false
        # }

        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $false
        $startInfo.RedirectStandardInput = $false
        $startInfo.UseShellExecute = $false

        foreach ($kvp in $Variables.GetEnumerator()) {
            # if ($startInfo.Environment.ContainsKey($kvp.Name)) {
                $startInfo.Environment[$kvp.Name] = $kvp.Value
            #     continue
            # }

            # $startInfo.Environment.Add($kvp.Name, $kvp.Value)
        }

        $process = [Process]::Start($startInfo)
        # if (-not $process.Start()) {
        #     throw
        # }

        # $process.StandardInput.Close()
        $reader = [ProcessReader]::new($process, $PSCmdlet)
        while ($reader.WaitForAny()) { }

        # while (-not $process.WaitForExit(200)) { }

        # $task = $process.StandardOutput.ReadToEndAsync()
        # while (-not $task.AsyncWaitHandle.WaitOne(200)) { }
        # $task.GetAwaiter().GetResult()

        # foreach ($task in $process.StandardError.ReadLineAsync()) {
        #     while (-not $task.AsyncWaitHandle.WaitOne(200)) { }
        #     $line = $task.GetAwaiter().GetResult()
        #     $PSCmdlet.WriteError(
        #         [ErrorRecord]::new(
        #             [RemoteException]::new($line),
        #             'NativeCommandError',
        #             [ErrorCategory]::NotSpecified,
        #             $line))
        # }

        # $tasks = [System.Threading.Tasks.Task[]]::new(2)
        # while ($true) {
        #     $stdOutIndex = -1
        #     $stdErrIndex = -1
        #     $i = 0
        #     if (-not $process.StandardOutput.EndOfStream) {
        #         $stdOutIndex = $i
        #         $tasks[$i++] ??= $process.StandardOutput.ReadLineAsync()
        #     }

        #     if (-not $process.StandardError.EndOfStream) {
        #         $stdErrIndex = $i
        #         $tasks[$i++] ??= $process.StandardError.ReadLineAsync()
        #     }

        #     if ($i -eq 0) {
        #         foreach ($task in $tasks) {
        #             if ($null -eq $task) {
        #                 continue
        #             }

        #             while ($task.AsyncWaitHandle.WaitOne(200)) { }
        #             $task.GetAwaiter().GetResult()
        #         }
        #     }

        #     while ($true) {
        #         $readyIndex = [System.Threading.Tasks.Task]::WaitAny($tasks, 200)
        #         if ($readyIndex -eq -1) {
        #             continue
        #         }

        #         $task = $tasks[$readyIndex]
        #         $line = $task.GetAwaiter().GetResult()
        #         if ($readyIndex -eq $stdOutIndex) {
        #             $PSCmdlet.WriteObject($line)
        #             $tasks[$readyIndex] = $null
        #             break
        #         }

        #         if ($readyIndex -eq $stdErrIndex) {
        #             $er = [ErrorRecord]::new(
        #                 [RemoteException]::new($line),
        #                 'NativeCommandError',
        #                 [ErrorCategory]::NotSpecified,
        #                 $line)

        #             $tasks[$readyIndex] = $null
        #             $PSCmdlet.WriteError($er)
        #             break
        #         }
        #     }
        # }
    }
}

function Invoke-PwshTriage {
    [CmdletBinding()]
    param()
    begin {

        class Label {
            [string] $Name

            [string] $Color

            [bool] $Added

            [bool] $Removed

            Label([object] $json) {
                $this.Name = $json.name
                $this.Color = $json.color
                $this.Added = $false
                $this.Removed = $false
            }

            Label([string] $name, [string] $color) {
                $this.Name = $name
                $this.Color = $color
                $this.Added = $false
                $this.Removed = $false
            }

            Label([string] $name, [string] $color, [bool] $added, [bool] $removed) {
                $this.Name = $name
                $this.Color = $color
                $this.Added = $added
                $this.Removed = $removed
            }

            static [Label] Added([object] $json) {
                return [Label]::Added($json.name, $json.color)
            }

            static [Label] Added([string] $name, [string] $color) {
                return [Label]::new($name, $color, $true, $false)
            }

            static [Label] Removed([object] $json) {
                return [Label]::Removed($json.name, $json.color)
            }

            static [Label] Removed([string] $name, [string] $color) {
                return [Label]::new($name, $color, $false, $true)
            }

            [bool] Equals([object] $other) {
                return $this.Name -eq $other.Name
            }

            [int] GetHashCode() {
                return $this.Name.GetHashCode()
            }
        }

        class Labeler {
            [int] $Issue

            [hashtable] $Labels

            [hashtable] $LabelGroups

            [List[Label]] $WorkingList

            Labeler([int] $issue, [hashtable] $labels, [hashtable] $labelGroups, [List[Label]] $initialLabels) {
                $this.Issue = $issue
                $this.Labels = $labels
                $this.LabelGroups = $labelGroups
                $this.WorkingList = $initialLabels
            }

            [void] AddByName([string] $name) {
                $this.WorkingList.Add([Label]::Added($this.Labels[$name]))
            }

            [void] Add([object] $jsonLabel) {
                $this.WorkingList.Add([Label]::Added($jsonLabel))
            }

            [void] Show() {
                $options = Get-PSRunDefaultSelectorOption

                $remaps = @{
                    'x' = 'ctrl+x'
                    'i' = 'ctrl+i'
                    'w' = 'ctrl+w'
                    's' = 'ctrl+s'
                }

                $options.KeyBinding.RemapKeys = @(
                    $options.KeyBinding.RemapKeys

                    foreach ($kvp in $remaps.GetEnumerator()) {
                        ('PowerShellRun.RemapKey' -as [type])::new(
                            ('PowerShellRun.KeyCombination' -as [type])::new($kvp.Key),
                            ('PowerShellRun.KeyCombination' -as [type])::new($kvp.Value))
                    }
                )

                $context = @{}
                while ($true) {
                    $result = & {
                        $style = $global:PSStyle
                        foreach ($label in $this.WorkingList) {
                            $entry = ('PowerShellRun.SelectorEntry' -as [type])::new()
                            $entry.UserData = $label
                            $entry.ActionKeys = @(
                                $options.KeyBinding.DefaultActionKeys
                                ('PowerShellRun.ActionKey' -as [type])::new('ctrl+x', 'Remove')
                                ('PowerShellRun.ActionKey' -as [type])::new('ctrl+i', 'Add')
                                ('PowerShellRun.ActionKey' -as [type])::new('ctrl+w', 'Assign working group')
                                ('PowerShellRun.ActionKey' -as [type])::new('ctrl+s', 'Solve with resolution')
                            )

                            if ($label.Removed) {
                                $entry.Name = $style.Strikethrough + $label.Name + $style.StrikethroughOff
                                # The `StrikethroughOff` above seems to get trimmed out for some reason,
                                # so we add a dummy description to force it.
                                $entry.Description = $style.StrikethroughOff + "`u{00a0}"
                            } elseif ($label.Added) {
                                $entry.Name = $style.Italic + $label.Name + $style.ItalicOff
                                # The above issue with strikethrough is probably also true here, but
                                # is untested.
                                $entry.Description = $style.ItalicOff + "`u{00a0}"
                            } else {
                                $entry.Name = $label.Name
                            }

                            $entry
                        }
                    } | Invoke-PSRunSelectorCustom -Option $options @context

                    $context['Context'] = $result.Context

                    if ($result.KeyCombination.Modifier -eq 'Ctrl') {
                        $key = $result.KeyCombination.Key
                        if ($key -eq 'c') {
                            $this.WorkingList.Clear()
                            return
                        }

                        if ($key -eq 'x') {
                            if (-not $result.FocusedEntry) {
                                continue
                            }

                            $focused = $result.FocusedEntry.UserData
                            if ($focused.Added) {
                                $this.WorkingList.Remove($focused)
                                continue
                            }

                            $focused.Removed = -not $focused.Removed
                            continue
                        }

                        if ($key -eq 'w') {
                            $wgToAdd = $this.LabelGroups['Workgroups'] |
                                Invoke-PSRunSelector -NameProperty name

                            if (-not $wgToAdd) {
                                continue
                            }

                            if ($this.WorkingList.Name -notcontains 'WG-NeedsReview') {
                                $this.AddByName('WG-NeedsReview')
                            }

                            $this.Add($wgToAdd)
                            continue
                        }

                        if ($key -eq 's') {
                            $resolution = $this.LabelGroups['Resolution'] |
                                Invoke-PSRunSelector -NameProperty name

                            if (-not $resolution) {
                                continue
                            }

                            if ($resolution.Name -eq 'Resolution-Answered') {
                                $isQuestionAdded = $false
                                foreach ($label in $this.WorkingList.ToArray()) {
                                    if (-not $label.Name.StartsWith('Issue-', [StringComparison]::OrdinalIgnoreCase)) {
                                        continue
                                    }

                                    if ($label.Name -eq 'Issue-Question') {
                                        $isQuestionAdded = $true
                                        $label.Removed = $false
                                        continue
                                    }

                                    if ($label.Added) {
                                        $this.WorkingGroup.Remove($label)
                                        continue
                                    }

                                    $label.Removed = $true
                                }

                                if (-not $isQuestionAdded) {
                                    $this.AddByName('Issue-Question')
                                }
                            }

                            $this.Add($resolution)
                            continue
                        }

                        if ($key -eq 'i') {
                            $labelsToAdd = & {
                                $this.Labels['WG-NeedsReview']
                                $this.LabelGroups['Workgroups']
                                $this.LabelGroups['Issue']
                                $this.LabelGroups['Resolution']
                            } | Where-Object name -notin $this.WorkingList.Name |
                                Invoke-PSRunSelector -MultiSelection -NameProperty name

                            foreach ($label in $labelsToAdd) {
                                $this.Add($label)
                            }

                            continue
                        }
                    }

                    if ($result.KeyCombination.Key -eq 'Enter') {
                        break
                    }
                }
            }
        }
    }
    end {
        $allLabels = gh label list --repo PowerShell/PowerShell --limit 200 --json 'name,color'
            | ConvertFrom-Json
            | Group-Object -AsHashTable -AsString -Property name

        $addableLabels = @{
            Workgroups = (
                $allLabels['WG-Engine'],
                $allLabels['WG-Cmdlets'],
                $allLabels['WG-Interactive-Console'],
                $allLabels['WG-Language'],
                $allLabels['WG-Remoting'],
                $allLabels['WG-Security'],
                $allLabels['Area-Maintainers-Build'],
                $allLabels['Area-Maintainers-Documentation'])
            Issue = (
                $allLabels['Issue-Bug'],
                $allLabels['Issue-Question'],
                $allLabels['Issue-Enhancement'],
                $allLabels['Issue-Regression'])
            Resolution = (
                $allLabels['Resolution-Answered'],
                $allLabels['Resolution-Duplicate'],
                $allLabels['Resolution-External'],
                $allLabels['Resolution-Won''t Fix'],
                $allLabels['Resolution-By Design'],
                $allLabels['Resolution-Fixed'],
                $allLabels['Resolution-Declined'],
                $allLabels['Resolution-No Activity'])
        }

        $wgLabels = (
            'WG-Interactive-PSReadLine', 'WG-Interactive-Console',
            'WG-Interactive-Debugging', 'WG-Interactive-IntelliSense',
            'WG-Interactive-HelpSystem', 'WG-Engine', 'WG-Engine-Performance',
            'WG-Engine-Providers', 'WG-Engine-Format', 'WG-Engine-ETS',
            'WG-Engine-ParameterBinder', 'WG-Engine-Pipeline',
            'WG-Engine-Module', 'WG-Cmdlets', 'WG-Cmdlets-Utility',
            'WG-Cmdlets-Management', 'WG-Cmdlets-Core', 'WG-Language',
            'WG-DevEx-Portability', 'WG-DevEx-SDK', 'WG-Remoting',
            'WG-Security', 'Area-Maintainers-Build')

        $dontInclude = [System.Collections.Generic.HashSet[string]]$wgLabels

        [PowerShellRun.SelectorOption] $options = Get-PSRunDefaultSelectorOption
        $options.Theme.PreviewSizePercentage = 80
        $options.Theme.CanvasHeightPercentage = 90
        $options.EntryCycleScrollEnable = $false

        $remaps = @{
            'o' = 'ctrl+o'
            'r' = 'ctrl+r'
            'e' = 'ctrl+e'
        }

        $options.KeyBinding.RemapKeys = @(
            $options.KeyBinding.RemapKeys

            foreach ($kvp in $remaps.GetEnumerator()) {
                [PowerShellRun.RemapKey]::new(
                    [PowerShellRun.KeyCombination]::new($kvp.Key),
                    [PowerShellRun.KeyCombination]::new($kvp.Value))
            }
        )

        $global:lastOptions = $options

        $loader = {
            Find-Issue --repo 'PowerShell/PowerShell' -State Open --label 'Needs-Triage' | & { process {

                $dontInclude = $dontInclude
                foreach ($name in $_.labels.name) {
                    if ($dontInclude.Contains($name)) {
                        return
                    }
                }

                $entry = [PowerShellRun.SelectorEntry]::new()
                $entry.UserData = $_
                $entry.ActionKeys = @(
                    $options.KeyBinding.DefaultActionKeys
                    [PowerShellRun.ActionKey]::new('ctrl+o', 'Open in web')
                    # [PowerShellRun.ActionKey]::new('ctrl+x', 'Remove labels')
                    # [PowerShellRun.ActionKey]::new('ctrl+s', 'Add resolution')
                    # [PowerShellRun.ActionKey]::new('ctrl+w', 'Add workgroup')
                    # [PowerShellRun.ActionKey]::new('ctrl+i', 'Add issue label')
                    [PowerShellRun.ActionKey]::new('ctrl+e', 'Edit labels')
                    [PowerShellRun.ActionKey]::new('ctrl+r', 'Reload')
                )

                $entry.Name = $_.title
                $entry.PreviewAsyncScript = {
                    param([int] $number, [scriptblock] $func)
                    ${function:Invoke-WithEnv} = $func.Ast.Body.GetScriptBlock()
                    Invoke-WithEnv gh "issue view $number --repo PowerShell/PowerShell --comments" @{
                        GH_FORCE_TTY = [Console]::WindowWidth
                    }

                    # gh issue view $args[0] --repo PowerShell/PowerShell --comments
                    # $oldValue = $env:GH_FORCE_TTY
                    # try {
                    #     $env:GH_FORCE_TTY = [Console]::WindowWidth
                    #     gh issue view $args[0] --repo PowerShell/PowerShell --comments
                    # } finally {
                    #     $env:GH_FORCE_TTY = $oldValue
                    # }
                }

                $entry.PreviewAsyncScriptArgumentList = $_.number, ${function:Invoke-WithEnv}

                $entry
            }}
        }

        $needsTriage = & $loader

        $context = @{}
        while ($true) {
            $result = $needsTriage | Invoke-PSRunSelectorCustom -Option $options @context
            if ($result.KeyCombination.Modifier -eq 'Ctrl' -and $result.KeyCombination.Key -eq 'C') {
                return
            }

            $focused = $result.FocusedEntry.UserData
            if (-not $focused) {
                continue
            }

            $context['Context'] = $result.Context
            if ($result.KeyCombination.Modifier -eq 'Ctrl') {
                $key = $result.KeyCombination.Key
                if ($key -eq 'o') {
                    $null = gh issue view $result.FocusedEntry.UserData.number --repo PowerShell/PowerShell --web
                    continue
                }

                if ($key -eq 'r') {
                    $needsTriage = & $loader
                    continue
                }

                if ($key -eq 'x') {
                    if (-not $result.FocusedEntry.UserData.labels) {
                        continue
                    }

                    $removalResult = $result.FocusedEntry.UserData.labels |
                        Invoke-PSRunSelector -MultiSelection -NameProperty name -DescriptionProperty description

                    foreach ($entry in $removalResult) {
                        gh issue edit --repo PowerShell/PowerShell $result.FocusedEntry.UserData.number --remove-label $entry.name
                        if ($LASTEXITCODE) {
                            throw $LASTEXITCODE
                        }
                    }

                    continue
                }

                if ($key -eq 's') {
                    $labelToAdd = $addableLabels['Resolution'] |
                        Invoke-PSRunSelector -NameProperty name -DescriptionProperty description

                    if (-not $labelToAdd) {
                        continue
                    }

                    "gh issue edit --repo PowerShell/PowerShell $($result.FocusedEntry.UserData.number) --add-label $($labelToAdd.name)"
                    if ($LASTEXITCODE) {
                        throw
                    }

                    continue
                }

                if ($key -eq 'w') {
                    $labelToAdd = $addableLabels['Workgroups'] |
                        Invoke-PSRunSelector -NameProperty name -DescriptionProperty description

                    if (-not $labelToAdd) {
                        continue
                    }

                    foreach ($label in ($labelToAdd.name, 'WG-NeedsReview')) {
                        "gh issue edit --repo PowerShell/PowerShell $($result.FocusedEntry.UserData.number) --add-label $label"
                        if ($LASTEXITCODE) {
                            throw
                        }
                    }

                    continue
                }

                if ($key -eq 'i') {
                    $labelToAdd = $addableLabels['Issue'] |
                        Invoke-PSRunSelector -NameProperty name -DescriptionProperty description

                    if (-not $labelToAdd) {
                        continue
                    }

                    "gh issue edit --repo PowerShell/PowerShell $($result.FocusedEntry.UserData.number) --add-label $($labelToAdd.name)"
                    if ($LASTEXITCODE) {
                        throw
                    }

                    continue
                }

                if ($key -eq 'e') {
                    $labeler = [Labeler]::new($focused.number, $allLabels, $addableLabels, $focused.labels)
                    $labeler.Show()
                    $changes = $labeler.WorkingList
                    if (-not $changes) {
                        continue
                    }

                    $toRemove = $changes | Where-Object Removed -eq $true
                    $toAdd = $changes | Where-Object Added -eq $true

                    if (-not ($toAdd -or $toRemove)) {
                        continue
                    }

                    $argList = @(
                        'issue'
                        'edit'
                        '--repo'
                        'PowerShell/PowerShell'
                        $focused.number
                        if ($toRemove) {
                            '--remove-label'
                            $toRemove.Name -join ','
                        }

                        if ($toAdd) {
                            '--add-label'
                            $toAdd.Name -join ','
                        }
                    )

                    gh @argList
                    continue
                }
            }

            return $result
        }
    }
}

function Update-Symlink {
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'Path', Mandatory, Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Target
    )
    process {
        $splat = @{ ErrorAction = 'Stop' }
        $inputString = $null
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $splat['Path'] = $Path
            $inputString = $Path
        } else {
            $splat['LiteralPath'] = $LiteralPath
            $inputString = $LiteralPath
        }

        $psDrive = $provider = $null
        $solvedValue = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $Target,
            [ref] $psDrive,
            [ref] $provider)

        if (Test-Path @splat -ErrorAction Stop) {
            $item = Get-Item @splat
            if (-not $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
                $PSCmdlet.WriteError(
                    [ErrorRecord]::new(
                        <# exception: #> [PSArgumentException]::new(
                            ('Target path "{0}" is not a symlink.' -f $inputString),
                            $PSCmdlet.ParameterSetName),
                        <# errorId: #> 'TargetNotSymlink',
                        <# errorCategory: #> [ErrorCategory]::InvalidArgument,
                        <# targetObject: #> $inputString))

                return
            }

            if ($item.Target -eq $solvedValue) {
                $PSCmdlet.WriteVerbose("'$inputString' already points to '$solvedValue', skipping.")
                return
            }

            Remove-Item @splat
        }

        $null = New-Item @splat -ItemType SymbolicLink -Value $solvedValue
    }
}

function Find-Header {
    param(
        [string] $Name,

        [string] $LiteralName
    )
    end {
        $target = Search-Everything -Global -PathInclude 'Windows Kits\10\Include' -ChildFileName 'cppwinrt' |
            Sort-Object { ($_ | Split-Path -Leaf) -as [version] } |
            Select-Object -Last 1

        Search-Everything -Global -PathInclude $target -Extension '.h' | & {
            process {
                $name = $Name
                $literalName = $LiteralName
                $target = $target

                $afterVersion = $_.Replace($target, '').TrimStart([char]'\')
                $fileName = $afterVersion | Split-Path -Leaf
                if ($name -and $fileName -notlike $name) {
                    return
                } elseif ($literalName -and $fileName -ne $literalName) {
                    return
                }

                $pso = [pscustomobject]@{
                    PSTypeName = 'UtilityProfile.HeaderFile'
                    Name = $fileName
                    Category = $afterVersion | Split-Path
                    PSPath = $_
                }

                $pso.psobject.Methods.Add(
                    [psscriptmethod]::new(
                        'ToString',
                        { $this.PSPath }));

                $pso
            }
        }
    }
}