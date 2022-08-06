. $PSScriptRoot\ReplacePSScriptRoot.ps1
$global:__registered_extensions = . "$PSScriptRoot/CompletionClasses.ps1"
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

        $namespaces = & {
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
        }

        ${//completion_extensions} = & {
            $scriptAst = $boundParams['ast']

            $allRelatedAsts = $scriptAst.FindAll(
                {
                    param([System.Management.Automation.Language.Ast] $a)
                    end {
                        return $positionOfCursor.Offset -ge $a.Extent.StartOffset -and
                            $positionOfCursor.Offset -le $a.Extent.EndOffset
                    }
                },
                $true)

            $lastRelatedAst = $allRelatedAsts | Select-Object -Last 1
            foreach (${//completion_extension} in $global:__registered_extensions) {
                ${//completion_extension} = ${//completion_extension}::new()
                ${//completion_extension}.Cmdlet = $PSCmdlet
                ${//completion_extension}.BoundParameters = $boundParams
                ${//completion_extension}.DynamicUsings = $namespaces
                ${//completion_extension}.RelatedAst = $lastRelatedAst
                ${//completion_extension}.OriginalAst = $scriptAst
                ${//completion_extension}.PreProcess()

                # yield
                ${//completion_extension}
            }
        }

        Remove-Variable boundParams
        Remove-Variable namespaces

        try {
            if ($PSBoundParameters.ContainsKey('OutBuffer')) {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(
                'TabExpansion2',
                [System.Management.Automation.CommandTypes]::Function)
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($MyInvocation.ExpectingInput)
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
            ${++completion} = $steppablePipeline.End()[0]
            ${++ref} = [ref] ${++completion}
            $boundParams = $PSBoundParameters
            & {
                $positionOfCursor = $boundParams['positionOfCursor']
                $scriptText = ${//completion_extensions}[0].OriginalAst.Extent.StartScriptPosition.GetFullScript()

                $textToBeReplaced = $scriptText.Substring(
                    ${++completion}.ReplacementIndex,
                    ${++completion}.ReplacementLength)

                foreach (${++completion_extension} in ${//completion_extensions}) {
                    ${++completion_extension}.TextToBeReplaced = $textToBeReplaced
                    ${++completion_extension}._result = ${++ref}
                    ${++completion_extension}.DoPostProcess()
                }
            }

            return ${++ref}.Value
        } catch {
            $PSCmdlet.WriteError($PSItem)
        }
    }
    <#
    .ForwardHelpTargetName TabExpansion2
    .ForwardHelpCategory Function
    #>
}

Microsoft.PowerShell.Utility\Set-Alias TabExpansion2 -Value NewProxyTabExpansion2 -Scope Global
