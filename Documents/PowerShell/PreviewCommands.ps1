using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.Management.Automation

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
        gh search issues @argList | ConvertFrom-Json | & { process {
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
            $cb = $cb * [System.Runtime.InteropServices.Marshal]::SizeOf([type]$Type)
        }

        if ($CoTaskMem) {
            return [System.Runtime.InteropServices.Marshal]::AllocCoTaskMem($cb)
        }

        return [System.Runtime.InteropServices.Marshal]::AllocHGlobal($cb)
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
            return [System.Runtime.InteropServices.Marshal]::StringToBSTR($Value)
        }

        if ($CoTaskMem) {
            if ($MarshalType -eq [StringMarshalType]::Ansi) {
                return [System.Runtime.InteropServices.Marshal]::StringToCoTaskMemAnsi($Value)
            }

            if ($MarshalType -eq [StringMarshalType]::Utf8) {
                return [System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUTF8($Value)
            }

            return [System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUni($Value)
        }

        if ($MarshalType -eq [StringMarshalType]::Ansi) {
            return [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($Value)
        }

        if ($MarshalType -eq [StringMarshalType]::Utf8) {
            return [System.Runtime.InteropServices.Marshal]::StringToHGlobalUTF8($Value)
        }

        return [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($Value)
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
