using namespace System.Diagnostics
using namespace System.Management.Automation

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

                    return 'struct'
                }

                if ($_.IsInterface) {
                    return 'interface'
                }

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
    addrestore
    status
    branch
    commit
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
        switch ($Kind) {
            addrestore { return Show-GitAddRestoreTui @GitArgs }
            status { return Show-GitStatusTui @GitArgs }
            branch { return Show-GitBranchTui -NoSearch:(-not $Search) -Multiple @GitArgs }
            commit { return Show-GitCommitTui -NoSearch:(-not $Search) -Multiple @GitArgs }
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
    }
}
