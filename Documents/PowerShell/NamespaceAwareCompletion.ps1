function global:NewProxyTabExpansion2 {
    [OutputType([System.Management.Automation.CommandCompletion])]
    [CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
    param(
        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 0)]
        [string] $inputScript,

        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 1)]
        [int] $cursorColumn,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 0)]
        [System.Management.Automation.Language.Ast] $ast,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 1)]
        [System.Management.Automation.Language.Token[]] $tokens,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 2)]
        [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,

        [Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
        [hashtable] $options
    )
    begin {
        $boundParams = $PSBoundParameters
        if ($PSCmdlet.ParameterSetName -eq 'ScriptInputSet') {
            $null = & {
                $completionInfo = [System.Management.Automation.CommandCompletion]::
                    MapStringInputToParsedInput(
                        $boundParams['inputScript'],
                        $boundParams['cursorColumn'])

                $boundParams.Remove('inputScript')
                $boundParams.Remove('cursorColumn')
                $boundParams.Add('ast', $completionInfo.Item1)
                $boundParams.Add('tokens', $completionInfo.Item2)
                $boundParams.Add('positionOfCursor', $completionInfo.Item3)
            }
        }

        & {
            $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
            $internalSessionState = $ExecutionContext.SessionState.GetType().
                GetProperty('Internal', $flags).
                GetValue($ExecutionContext.SessionState)

            $globalScope = $internalSessionState.GetType().
                GetProperty('GlobalScope', $flags).
                GetValue($internalSessionState)

            $typeResolutionState = $globalScope.GetType().
                GetProperty('TypeResolutionState', $flags).
                GetValue($globalScope)

            $namespaces = $typeResolutionState.GetType().
                GetField('namespaces', $flags).
                GetValue($typeResolutionState)

            $usingStatements = [System.Collections.Generic.List[System.Management.Automation.Language.UsingStatementAst]]::new()
            foreach ($namespace in $namespaces) {
                $usingExtent = [System.Management.Automation.Language.ScriptExtent]::new(
                    [System.Management.Automation.Language.ScriptPosition]::new(
                        $boundParams['ast'].Extent.File,
                        1,
                        1,
                        'using namespace {0}' -f $namespace,
                        $boundParams['ast'].Extent.Text),
                    [System.Management.Automation.Language.ScriptPosition]::new(
                        $boundParams['ast'].Extent.File,
                        1,
                        17 + $namespace.Length,
                        'using namespace {0}' -f $namespace,
                        $boundParams['ast'].Extent.Text))

                $stringExtent = [System.Management.Automation.Language.ScriptExtent]::new(
                    [System.Management.Automation.Language.ScriptPosition]::new(
                        $boundParams['ast'].Extent.File,
                        1,
                        17,
                        'using namespace {0}' -f $namespace,
                        $boundParams['ast'].Extent.Text),
                    [System.Management.Automation.Language.ScriptPosition]::new(
                        $boundParams['ast'].Extent.File,
                        1,
                        17 + $namespace.Length,
                        'using namespace {0}' -f $namespace,
                        $boundParams['ast'].Extent.Text))

                $usingStatements.Add(
                    [System.Management.Automation.Language.UsingStatementAst]::new(
                        $usingExtent,
                        [System.Management.Automation.Language.UsingStatementKind]::Namespace,
                        [System.Management.Automation.Language.StringConstantExpressionAst]::new(
                            $stringExtent,
                            $namespace,
                            [System.Management.Automation.Language.StringConstantType]::BareWord)))
            }

            if ($boundParams['ast'].UsingStatements) {
                $oldUsingStatements =
                    $boundParams['ast'].UsingStatements -as [System.Management.Automation.Language.UsingStatementAst[]]
                $newUsingStatements = [System.Management.Automation.Language.UsingStatementAst[]]::new(
                    $oldUsingStatements.Length)

                for ($i = 0; $i -lt $newUsingStatements.Length; $i++) {
                    $current = $oldUsingStatements[$i]
                    if ($current.Alias) {
                        $newUsingStatements[$i] = [System.Management.Automation.Language.UsingStatementAst]::new(
                            $current.Extent,
                            $current.UsingStatementKind,
                            $current.Name.Copy(),
                            $current.Alias.Copy())

                        continue
                    }

                    $newUsingStatements[$i] = [System.Management.Automation.Language.UsingStatementAst]::new(
                        $current.Extent,
                        $current.UsingStatementKind,
                        $current.Name.Copy())
                }

                $usingStatements.AddRange($newUsingStatements)
            }

            $boundParams['ast'] = [System.Management.Automation.Language.ScriptBlockAst]::new(
                $boundParams['ast'].Extent,
                [System.Management.Automation.Language.UsingStatementAst[]]$usingStatements,
                $boundParams['ast'].Attributes.
                    ForEach('Copy').
                    ForEach([System.Management.Automation.Language.AttributeAst]),
                $boundParams['ast'].ParamBlock.ForEach('Copy')[0],
                $boundParams['ast'].BeginBlock.ForEach('Copy')[0],
                $boundParams['ast'].ProcessBlock.ForEach('Copy')[0],
                $boundParams['ast'].EndBlock.ForEach('Copy')[0],
                $boundParams['ast'].DynamicParamBlock.ForEach('Copy')[0])
        }

        Remove-Variable boundParams

        try {
            if ($PSBoundParameters.ContainsKey('OutBuffer')) {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(
                'TabExpansion2',
                [System.Management.Automation.CommandTypes]::Function)
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
        }
    }
    process {
        try {
            $steppablePipeline.Process($PSItem)
        } catch {
        }
    }
    end {
        try {
            $steppablePipeline.End()
        } catch {
        }
    }
    <#
    .ForwardHelpTargetName TabExpansion2
    .ForwardHelpCategory Function
    #>
}

Microsoft.PowerShell.Utility\Set-Alias TabExpansion2 -Value NewProxyTabExpansion2 -Scope Global
