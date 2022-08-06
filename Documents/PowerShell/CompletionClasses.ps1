using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class ExpansionExtension {
    hidden [ref] $_result

    [PSCmdlet] $Cmdlet

    [Dictionary[string, object]] $BoundParameters

    [bool] $ImplementsResultProcessor

    [string] $TextToBeReplaced

    [Ast] $RelatedAst

    [Ast] $OriginalAst

    [string[]] $DynamicUsings

    hidden [void] DoPreProcess() {
    }

    [void] PreProcess() {
    }

    [void] PostProcess() {
        if ($this.ImplementsResultProcessor) {
            $this.EnumerateAndAlterMatches()
        }
    }

    hidden [void] DoPostProcess() {
        $completion = $this.GetCommandCompletion()
        if ($completion.ReplacementLength -eq 0) {
            $this.PostProcess()
            return
        }

        # $ast = $this.BoundParameters['ast']
        # $positionOfCursor = $this.BoundParameters['positionOfCursor']
        # $scriptText = $ast.Extent.StartScriptPosition.GetFullScript()

        # $this.TextToBeReplaced = $scriptText.Substring(
        #     $completion.ReplacementIndex,
        #     $completion.ReplacementLength)

        # $allRelatedAsts = $ast.FindAll(
        #     {
        #         param([Ast] $a)
        #         end {
        #             return $positionOfCursor.Offset -ge $a.Extent.StartOffset -and
        #                 $positionOfCursor.Offset -le $a.Extent.EndOffset
        #         }
        #     },
        #     $true)

        # $this.RelatedAst = $allRelatedAsts | Select-Object -Last 1

        $this.PostProcess()
    }

    [CompletionResult] ProcessResult([CompletionResult] $completionResult) {
        return $completionResult
    }

    [CommandCompletion] GetCommandCompletion() {
        if ($null -eq $this._result.Value) {
            throw 'GetCommandCompletion cannot be called outside of PostProcess'
        }

        return $this._result.Value
    }

    [void] SetCommandCompletion([CommandCompletion] $commandCompletion) {
        $this._result.Value = $commandCompletion
    }

    [void] EnumerateAndAlterMatches() {
        $setIndex = 0
        $completion = $this.GetCommandCompletion()
        for ($i = 0; $i -lt $completion.CompletionMatches.Count; $i++) {
            $newResult = $null
            try {
                $newResult = $this.ProcessResult($completion.CompletionMatches[$i])
            } catch {
                $this.Cmdlet.WriteError($PSItem)
                $completion.CompletionMatches[$setIndex++] = $completion.CompletionMatches[$i]
                continue
            }

            if ($null -eq $newResult) {
                continue
            }

            $completion.CompletionMatches[$setIndex++] = $newResult
        }

        $removed = $i - 1 - $setIndex
        for ($i = 0; $i -lt $removed; $i++) {
            $completion.CompletionMatches.RemoveAt($completion.CompletionMatches.Count - $i - 1)
        }
    }
}

class FileResultProcessor : ExpansionExtension {
    [string] $Home = (Get-Item ~).FullName -replace '\\', '/'

    FileResultProcessor() {
        $this.ImplementsResultProcessor = $true
    }

    [CompletionResult] ProcessResult([CompletionResult] $completionResult) {
        $isMatch = $completionResult.ResultType.Equals([CompletionResultType]::ProviderContainer) -or
            $completionResult.ResultType.Equals([CompletionResultType]::ProviderItem)

        if (-not $isMatch) {
            return $completionResult
        }

        $completionText = $completionResult.CompletionText
        $didReplaceSep = $false
        if ($this.TextToBeReplaced.Contains([IO.Path]::AltDirectorySeparatorChar)) {
            $completionText = $completionText.Replace([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $didReplaceSep = $true
        }

        if ($this.TextToBeReplaced[0] -eq '~') {
            $completionText = $completionText.Replace($this.Home, '~')
        }

        $variableMap = [List[Tuple[ExpressionAst, object]]]::new()
        if ($this.RelatedAst -is [ExpandableStringExpressionAst]) {
            foreach ($nestedExpression in $this.RelatedAst.NestedExpressions) {
                if ($nestedExpression -is [VariableExpressionAst]) {
                    $variable = $nestedExpression.VariablePath.UserPath
                    $result = $null
                    if ($variable -in 'PSScriptRoot', '++PSScriptRoot') {
                        $result = [System.IO.Path]::GetDirectoryName($this.BoundParameters['ast'].Extent.File)
                    } else {
                        $result = $this.Cmdlet.GetVariableValue($variable)
                    }

                    if ($didReplaceSep) {
                        $result = $result.Replace([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                    }

                    if (-not [string]::IsNullOrEmpty($result)) {
                        $variableMap.Add([Tuple[ExpressionAst, object]]::new($nestedExpression, $result))
                    }
                }
            }
        }

        $variableMap.Reverse()
        foreach ($kvp in $variableMap.GetEnumerator()) {
            $index = $completionText.IndexOf([string]$kvp.Item2, [System.StringComparison]::Ordinal)
            if ($index -eq -1) {
                continue
            }

            $completionText = $completionText.Remove($index, ([string]$kvp.Item2).Length).
                Insert($index, [string]$kvp.Item1)
        }

        if ($completionText -eq $completionResult.CompletionText) {
            return $completionResult
        }

        return [CompletionResult]::new(
            $completionText,
            $completionResult.ListItemText,
            $completionResult.ResultType,
            $completionResult.ToolTip)
    }
}

class UsingNamespacesPreProcessor : ExpansionExtension {
    [void] PreProcess() {
        $boundParams = $this.BoundParameters
        $namespaces = $this.DynamicUsings
        $usingStatements = [List[UsingStatementAst]]::new()
        foreach ($namespace in $namespaces) {
            $usingExtent = [ScriptExtent]::new(
                [ScriptPosition]::new(
                    $boundParams['ast'].Extent.File,
                    1,
                    1,
                    'using namespace {0}' -f $namespace,
                    $boundParams['ast'].Extent.Text),
                [ScriptPosition]::new(
                    $boundParams['ast'].Extent.File,
                    1,
                    17 + $namespace.Length,
                    'using namespace {0}' -f $namespace,
                    $boundParams['ast'].Extent.Text))

            $stringExtent = [ScriptExtent]::new(
                [ScriptPosition]::new(
                    $boundParams['ast'].Extent.File,
                    1,
                    17,
                    'using namespace {0}' -f $namespace,
                    $boundParams['ast'].Extent.Text),
                [ScriptPosition]::new(
                    $boundParams['ast'].Extent.File,
                    1,
                    17 + $namespace.Length,
                    'using namespace {0}' -f $namespace,
                    $boundParams['ast'].Extent.Text))

            $usingStatements.Add(
                [UsingStatementAst]::new(
                    $usingExtent,
                    [UsingStatementKind]::Namespace,
                    [StringConstantExpressionAst]::new(
                        $stringExtent,
                        $namespace,
                        [StringConstantType]::BareWord)))
        }

        if ($boundParams['ast'].UsingStatements) {
            $oldUsingStatements =
                $boundParams['ast'].UsingStatements -as [UsingStatementAst[]]
            $newUsingStatements = [UsingStatementAst[]]::new(
                $oldUsingStatements.Length)

            for ($i = 0; $i -lt $newUsingStatements.Length; $i++) {
                $current = $oldUsingStatements[$i]
                if ($current.Alias) {
                    $newUsingStatements[$i] = [UsingStatementAst]::new(
                        $current.Extent,
                        $current.UsingStatementKind,
                        $current.Name.Copy(),
                        $current.Alias.Copy())

                    continue
                }

                $newUsingStatements[$i] = [UsingStatementAst]::new(
                    $current.Extent,
                    $current.UsingStatementKind,
                    $current.Name.Copy())
            }

            $usingStatements.AddRange($newUsingStatements)
        }

        $boundParams['ast'] = [ScriptBlockAst]::new(
            $boundParams['ast'].Extent,
            [UsingStatementAst[]]$usingStatements,
            $boundParams['ast'].Attributes.
                ForEach('Copy').
                ForEach([AttributeAst]),
            $boundParams['ast'].ParamBlock.ForEach('Copy')[0],
            $boundParams['ast'].BeginBlock.ForEach('Copy')[0],
            $boundParams['ast'].ProcessBlock.ForEach('Copy')[0],
            $boundParams['ast'].EndBlock.ForEach('Copy')[0],
            $boundParams['ast'].DynamicParamBlock.ForEach('Copy')[0])
    }
}

class ReplacePSScriptRootPreProcessor : ExpansionExtension {
    [void] PreProcess() {
        $scriptAst = $this.BoundParameters['ast']
        $newAst = $scriptAst.Visit([VariableReplacer]::new('PSScriptRoot', '++PSScriptRoot'))
        $this.BoundParameters['ast'] = $newAst
        ${global:++PSScriptRoot} = [System.IO.Path]::GetDirectoryName($newAst.Extent.File)
    }
}

return [FileResultProcessor], [UsingNamespacesPreProcessor], [ReplacePSScriptRootPreProcessor]
