using namespace System
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Reflection

class AstRebuilder : ICustomAstVisitor2 {
    [object[]] VisitAll([Ast[]] $asts) {
        return & {
            foreach ($a in $asts) {
                $a.Visit($this)
            }
        }
    }

    [object] Visit([Ast] $ast) {
        return ($ast)?.Visit($this)
    }

    [Object] VisitTypeDefinition([TypeDefinitionAst] $typeDefinitionAst) {
        return [TypeDefinitionAst]::new(
            $typeDefinitionAst.Extent,
            $typeDefinitionAst.Name,
            [AttributeAst[]]$this.VisitAll($typeDefinitionAst.Attributes),
            [MemberAst[]]$this.VisitAll($typeDefinitionAst.Members),
            $typeDefinitionAst.TypeAttributes,
            [TypeConstraintAst[]]$this.VisitAll($typeDefinitionAst.BaseTypes))
    }

    [Object] VisitPropertyMember([PropertyMemberAst] $propertyMemberAst) {
        return [PropertyMemberAst]::new(
            $propertyMemberAst.Extent,
            $propertyMemberAst.Name,
            $this.Visit($propertyMemberAst.PropertyType),
            [AttributeAst[]]$this.VisitAll($propertyMemberAst.Attributes),
            $propertyMemberAst.PropertyAttributes,
            $this.Visit($propertyMemberAst.InitialValue))
    }

    [Object] VisitFunctionMember([FunctionMemberAst] $functionMemberAst) {
        return [FunctionMemberAst]::new(
            $functionMemberAst.Extent,
            $this.Visit($functionMemberAst.Body.Parent),
            $this.Visit($functionMemberAst.ReturnType),
            [AttributeAst[]]$this.VisitAll($functionMemberAst.Attributes),
            $functionMemberAst.MethodAttributes)
    }

    [Object] VisitBaseCtorInvokeMemberExpression([BaseCtorInvokeMemberExpressionAst] $baseCtorInvokeMemberExpressionAst) {
        return [BaseCtorInvokeMemberExpressionAst]::new(
            $baseCtorInvokeMemberExpressionAst.Expression.Extent,
            $baseCtorInvokeMemberExpressionAst.Member.Extent,
            [ExpressionAst[]]$this.VisitAll($baseCtorInvokeMemberExpressionAst.Arguments))
    }

    [Object] VisitUsingStatement([UsingStatementAst] $usingStatement) {
        if ($usingStatement.ModuleSpecification) {
            if ($usingStatement.Alias) {
                return [UsingStatementAst]::new(
                    $usingStatement.Extent,
                    $this.Visit($usingStatement.Alias),
                    $this.Visit($usingStatement.ModuleSpecification))
            }

            return [UsingStatementAst]::new(
                $usingStatement.Extent,
                $this.Visit($usingStatement.ModuleSpecification))
        }

        if ($usingStatement.Alias) {
            return [UsingStatementAst]::new(
                $usingStatement.Extent,
                $usingStatement.UsingStatementKind,
                $this.Visit($usingStatement.Name),
                $this.Visit($usingStatement.Alias))
        }

        return [UsingStatementAst]::new(
            $usingStatement.Extent,
            $usingStatement.UsingStatementKind,
            $this.Visit($usingStatement.Name))
    }

    [Object] VisitConfigurationDefinition([ConfigurationDefinitionAst] $configurationDefinitionAst) {
        return [ConfigurationDefinitionAst]::new(
            $configurationDefinitionAst.Extent,
            $this.Visit($configurationDefinitionAst.Body),
            $configurationDefinitionAst.ConfigurationType,
            $this.Visit($configurationDefinitionAst.InstanceName))
    }

    [Object] VisitDynamicKeywordStatement([DynamicKeywordStatementAst] $dynamicKeywordAst) {
        return [DynamicKeywordStatementAst]::new(
            $dynamicKeywordAst.Extent,
            [CommandElementAst[]]$this.VisitAll($dynamicKeywordAst.CommandElements))
    }

    [Object] VisitTernaryExpression([TernaryExpressionAst] $ternaryExpressionAst) {
        return [TernaryExpressionAst]::new(
            $ternaryExpressionAst.Extent,
            $this.Visit($ternaryExpressionAst.Condition),
            $this.Visit($ternaryExpressionAst.IfTrue),
            $this.Visit($ternaryExpressionAst.IfFalse))
    }

    [Object] VisitPipelineChain([PipelineChainAst] $statementChainAst) {
        return [PipelineChainAst]::new(
            $statementChainAst.Extent,
            $this.Visit($statementChainAst.LhsPipelineChain),
            $this.Visit($statementChainAst.RhsPipeline),
            $statementChainAst.Operator,
            $statementChainAst.Background)
    }

    [Object] DefaultVisit([Ast] $ast) {
        return $ast.Copy()
    }

    [Object] VisitErrorStatement([ErrorStatementAst] $errorStatementAst) {
        $errorFlags = [Dictionary[string, Tuple[Token, Ast]]]::new($errorStatementAst.Flags.Comparer)
        foreach ($flag in $errorStatementAst.Flags.GetEnumerator()) {
            $errorFlags.Add(
                $flag.Key,
                [Tuple[Token, Ast]]::new($flag.Value.Item1, $this.Visit($flag.Value.Item2)))
        }

        $flags = [BindingFlags]::Instance -bor 'NonPublic'
        return [ErrorStatementAst].
            GetConstructor(
                $flags,
                ([IScriptExtent], [Token], [IEnumerable[KeyValuePair[string, Tuple[Token, Ast]]]], [IEnumerable[Ast]], [IEnumerable[Ast]])).
            Invoke((
                $errorStatementAst.Extent,
                $errorStatementAst.Kind,
                $errorFlags.GetEnumerator(),
                [Ast[]]$this.VisitAll($errorStatementAst.Conditions),
                [Ast[]]$this.VisitAll($errorStatementAst.Bodies)))
    }

    [Object] VisitErrorExpression([ErrorExpressionAst] $errorExpressionAst) {
        $flags = [BindingFlags]::Instance -bor 'NonPublic'
        return [ErrorExpressionAst].
            GetConstructor(
                $flags,
                ([IScriptExtent], [IEnumerable[Ast]])).
            Invoke((
                $errorExpressionAst.Extent,
                [Ast[]]$this.VisitAll($errorExpressionAst.NestedAst)))
    }

    [Object] VisitScriptBlock([ScriptBlockAst] $scriptBlockAst) {
        return [ScriptBlockAst]::new(
            $scriptBlockAst.Extent,
            [UsingStatementAst[]]$this.VisitAll($scriptBlockAst.UsingStatements),
            [AttributeAst[]]$this.VisitAll($scriptBlockAst.Attributes),
            $this.Visit($scriptBlockAst.ParamBlock),
            $this.Visit($scriptBlockAst.BeginBlock),
            $this.Visit($scriptBlockAst.ProcessBlock),
            $this.Visit($scriptBlockAst.EndBlock),
            $this.Visit($scriptBlockAst.CleanBlock),
            $this.Visit($scriptBlockAst.DynamicParamBlock))
    }

    [Object] VisitParamBlock([ParamBlockAst] $paramBlockAst) {
        return [ParamBlockAst]::new(
            $paramBlockAst.Extent,
            [AttributeAst[]]$this.VisitAll($paramBlockAst.Attributes),
            [ParameterAst[]]$this.VisitAll($paramBlockAst.Parameters))
    }

    [Object] VisitNamedBlock([NamedBlockAst] $namedBlockAst) {
        return [NamedBlockAst]::new(
            $namedBlockAst.Extent,
            $namedBlockAst.BlockKind,
            [StatementBlockAst]::new(
                $namedBlockAst.Extent,
                [StatementAst[]]$this.VisitAll($namedBlockAst.Statements),
                [TrapStatementAst[]]$this.Visitall($namedBlockAst.Traps)),
            $namedBlockAst.Unnamed)
    }

    [Object] VisitTypeConstraint([TypeConstraintAst] $typeConstraintAst) {
        return $typeConstraintAst.Copy()
    }

    [Object] VisitAttribute([AttributeAst] $attributeAst) {
        return [AttributeAst]::new(
            $attributeAst.Extent,
            $attributeAst.TypeName,
            [ExpressionAst[]]$this.VisitAll($attributeAst.PositionalArguments),
            [NamedAttributeArgumentAst[]]$this.VisitAll($attributeAst.NamedArguments))
    }

    [Object] VisitNamedAttributeArgument([NamedAttributeArgumentAst] $namedAttributeArgumentAst) {
        return [NamedAttributeArgumentAst]::new(
            $namedAttributeArgumentAst.Extent,
            $namedAttributeArgumentAst.ArgumentName,
            $this.Visit($namedAttributeArgumentAst.Argument),
            $namedAttributeArgumentAst.ExpressionOmitted)
    }

    [Object] VisitParameter([ParameterAst] $parameterAst) {
        return [ParameterAst]::new(
            $parameterAst.Extent,
            $this.Visit($parameterAst.Name),
            [AttributeBaseAst[]]$this.VisitAll($parameterAst.Attributes),
            $this.Visit($parameterAst.DefaultValue))
    }

    [Object] VisitFunctionDefinition([FunctionDefinitionAst] $functionDefinitionAst) {
        return [FunctionDefinitionAst]::new(
            $functionDefinitionAst.Extent,
            $functionDefinitionAst.IsFilter,
            $functionDefinitionAst.IsWorkflow,
            $functionDefinitionAst.Name,
            [ParameterAst[]]$this.VisitAll($functionDefinitionAst.Parameters),
            $this.Visit($functionDefinitionAst.Body))
    }

    [Object] VisitStatementBlock([StatementBlockAst] $statementBlockAst) {
        return [StatementBlockAst]::new(
            $statementBlockAst.Extent,
            [StatementAst[]]$this.VisitAll($statementBlockAst.Statements),
            [TrapStatementAst[]]$this.Visitall($statementBlockAst.Traps))
    }

    [Object] VisitIfStatement([IfStatementAst] $ifStmtAst) {
        [Tuple[PipelineBaseAst, StatementBlockAst][]] $clauses = foreach ($clause in $ifStmtAst.Clauses) {
            [Tuple[PipelineBaseAst, StatementBlockAst]]::new(
                $this.Visit($clause.Item1),
                $this.Visit($clause.Item2))
        }

        return [IfStatementAst]::new(
            $ifStmtAst.Extent,
            $clauses,
            $this.Visit($ifStmtAst.ElseClause))
    }

    [Object] VisitTrap([TrapStatementAst] $trapStatementAst) {
        return [TrapStatementAst]::new(
            $trapStatementAst.Extent,
            $this.Visit($trapStatementAst.TrapType),
            $this.Visit($trapStatementAst.Body))
    }

    [Object] VisitSwitchStatement([SwitchStatementAst] $switchStatementAst) {
        [Tuple[ExpressionAst, StatementBlockAst][]] $clauses = foreach ($clause in $switchStatementAst.Clauses) {
            [Tuple[ExpressionAst, StatementBlockAst]]::new(
                $this.Visit($clause.Item1),
                $this.Visit($clause.Item2))
        }
        return [SwitchStatementAst]::new(
            $switchStatementAst.Extent,
            $switchStatementAst.Label,
            $this.Visit($switchStatementAst.Condition),
            $switchStatementAst.Flags,
            $clauses,
            $this.Visit($switchStatementAst.Default))
    }

    [Object] VisitDataStatement([DataStatementAst] $dataStatementAst) {
        return [DataStatementAst]::new(
            $dataStatementAst.Extent,
            $dataStatementAst.Variable,
            [ExpressionAst[]]$this.VisitAll($dataStatementAst.Variable),
            $this.Visit($dataStatementAst.Body))
    }

    [Object] VisitForEachStatement([ForEachStatementAst] $forEachStatementAst) {
        return [ForEachStatementAst]::new(
            $forEachStatementAst.Extent,
            $forEachStatementAst.Label,
            $forEachStatementAst.Flags,
            $this.Visit($forEachStatementAst.Variable),
            $this.Visit($forEachStatementAst.Condition),
            $this.Visit($forEachStatementAst.Body))
    }

    [Object] VisitDoWhileStatement([DoWhileStatementAst] $doWhileStatementAst) {
        return [DoWhileStatementAst]::new(
            $doWhileStatementAst.Extent,
            $doWhileStatementAst.Label,
            $this.Visit($doWhileStatementAst.Condition),
            $this.Visit($doWhileStatementAst.Body))
    }

    [Object] VisitForStatement([ForStatementAst] $forStatementAst) {
        return [ForStatementAst]::new(
            $forStatementAst.Extent,
            $forStatementAst.Label,
            $this.Visit($forStatementAst.Initializer),
            $this.Visit($forStatementAst.Condition),
            $this.Visit($forStatementAst.Iterator),
            $this.Visit($forStatementAst.Body))
    }

    [Object] VisitWhileStatement([WhileStatementAst] $whileStatementAst) {
        return [WhileStatementAst]::new(
            $whileStatementAst.Extent,
            $whileStatementAst.Label,
            $this.Visit($whileStatementAst.Condition),
            $this.Visit($whileStatementAst.Body))
    }

    [Object] VisitCatchClause([CatchClauseAst] $catchClauseAst) {
        return [CatchClauseAst]::new(
            $catchClauseAst.Extent,
            [TypeConstraintAst[]]$this.VisitAll($catchClauseAst.CatchTypes),
            $this.Visit($catchClauseAst.Body))
    }

    [Object] VisitTryStatement([TryStatementAst] $tryStatementAst) {
        return [TryStatementAst]::new(
            $tryStatementAst.Extent,
            $this.Visit($tryStatementAst.Body),
            [CatchClauseAst[]]$this.VisitAll($tryStatementAst.CatchClauses),
            $this.Visit($tryStatementAst.Finally))
    }

    [Object] VisitBreakStatement([BreakStatementAst] $breakStatementAst) {
        return [BreakStatementAst]::new(
            $breakStatementAst.Extent,
            $this.Visit($breakStatementAst.Label))
    }

    [Object] VisitContinueStatement([ContinueStatementAst] $continueStatementAst) {
        return [ContinueStatementAst]::new(
            $continueStatementAst.Extent,
            $this.Visit($continueStatementAst.Label))
    }

    [Object] VisitReturnStatement([ReturnStatementAst] $returnStatementAst) {
        return [ReturnStatementAst]::new(
            $returnStatementAst.Extent,
            $this.Visit($returnStatementAst.Label))
    }

    [Object] VisitExitStatement([ExitStatementAst] $exitStatementAst) {
        return [ExitStatementAst]::new(
            $exitStatementAst.Extent,
            $this.Visit($exitStatementAst.Pipeline))
    }

    [Object] VisitThrowStatement([ThrowStatementAst] $throwStatementAst) {
        return [ThrowStatementAst]::new(
            $throwStatementAst.Extent,
            $this.Visit($throwStatementAst.Pipeline))
    }

    [Object] VisitDoUntilStatement([DoUntilStatementAst] $doUntilStatementAst) {
        return [DoUntilStatementAst]::new(
            $doUntilStatementAst.Extent,
            $doUntilStatementAst.Label,
            $this.Visit($doUntilStatementAst.Condition),
            $this.Visit($doUntilStatementAst.Body))
    }

    [Object] VisitAssignmentStatement([AssignmentStatementAst] $assignmentStatementAst) {
        return [AssignmentStatementAst]::new(
            $assignmentStatementAst.Extent,
            $this.Visit($assignmentStatementAst.Left),
            $assignmentStatementAst.Operator,
            $this.Visit($assignmentStatementAst.Right),
            $assignmentStatementAst.ErrorPosition)
    }

    [Object] VisitPipeline([PipelineAst] $pipelineAst) {
        return [PipelineAst]::new(
            $pipelineAst.Extent,
            [CommandBaseAst[]]$this.VisitAll($pipelineAst.PipelineElements),
            $pipelineAst.Background)
    }

    [Object] VisitCommand([CommandAst] $commandAst) {
        return [CommandAst]::new(
            $commandAst.Extent,
            [CommandElementAst[]]$this.VisitAll($commandAst.CommandElements),
            $commandAst.InvocationOperator,
            [RedirectionAst[]]$this.VisitAll($commandAst.Redirections))
    }

    [Object] VisitCommandExpression([CommandExpressionAst] $commandExpressionAst) {
        return [CommandExpressionAst]::new(
            $commandExpressionAst.Extent,
            $this.Visit($commandExpressionAst.Expression),
            [RedirectionAst[]]$this.VisitAll($commandExpressionAst.Redirections))
    }

    [Object] VisitCommandParameter([CommandParameterAst] $commandParameterAst) {
        return [CommandParameterAst]::new(
            $commandParameterAst.Extent,
            $commandParameterAst.ParameterName,
            $this.Visit($commandParameterAst.Argument),
            $commandParameterAst.Extent)
    }

    [Object] VisitFileRedirection([FileRedirectionAst] $fileRedirectionAst) {
        return [FileRedirectionAst]::new(
            $fileRedirectionAst.Extent,
            $fileRedirectionAst.FromStream,
            $this.Visit($fileRedirectionAst.Location),
            $fileRedirectionAst.Append)
    }

    [Object] VisitMergingRedirection([MergingRedirectionAst] $mergingRedirectionAst) {
        return [MergingRedirectionAst]::new(
            $mergingRedirectionAst.Extent,
            $mergingRedirectionAst.FromStream,
            $mergingRedirectionAst.ToStream)
    }

    [Object] VisitBinaryExpression([BinaryExpressionAst] $binaryExpressionAst) {
        return [BinaryExpressionAst]::new(
            $binaryExpressionAst.Extent,
            $this.Visit($binaryExpressionAst.Left),
            $binaryExpressionAst.Operator,
            $this.Visit($binaryExpressionAst.Right),
            $binaryExpressionAst.ErrorPosition)
    }

    [Object] VisitUnaryExpression([UnaryExpressionAst] $unaryExpressionAst) {
        return [UnaryExpressionAst]::new(
            $unaryExpressionAst.Extent,
            $unaryExpressionAst.TokenKind,
            $this.Visit($unaryExpressionAst.Child))
    }

    [Object] VisitConvertExpression([ConvertExpressionAst] $convertExpressionAst) {
        return [ConvertExpressionAst]::new(
            $convertExpressionAst.Extent,
            $this.Visit($convertExpressionAst.Type),
            $this.Visit($convertExpressionAst.Child))
    }

    [Object] VisitConstantExpression([ConstantExpressionAst] $constantExpressionAst) {
        return $constantExpressionAst.Copy()
    }

    [Object] VisitStringConstantExpression([StringConstantExpressionAst] $stringConstantExpressionAst) {
        return $stringConstantExpressionAst.Copy()
    }

    [Object] VisitSubExpression([SubExpressionAst] $subExpressionAst) {
        return [SubExpressionAst]::new(
            $subExpressionAst.Extent,
            $this.Visit($subExpressionAst.SubExpression))
    }

    [Object] VisitUsingExpression([UsingExpressionAst] $usingExpressionAst) {
        return [UsingExpressionAst]::new(
            $usingExpressionAst.Extent,
            $this.Visit($usingExpressionAst.SubExpression))
    }

    [Object] VisitVariableExpression([VariableExpressionAst] $variableExpressionAst) {
        return [VariableExpressionAst]::new(
            $variableExpressionAst.Extent,
            $variableExpressionAst.VariablePath,
            $variableExpressionAst.Splatted)
    }

    [Object] VisitTypeExpression([TypeExpressionAst] $typeExpressionAst) {
        return [TypeExpressionAst]::new(
            $typeExpressionAst.Extent,
            $typeExpressionAst.TypeName)
    }

    [Object] VisitMemberExpression([MemberExpressionAst] $memberExpressionAst) {
        return [MemberExpressionAst]::new(
            $memberExpressionAst.Extent,
            $this.Visit($memberExpressionAst.Expression),
            $this.Visit($memberExpressionAst.Member),
            $memberExpressionAst.Static,
            $memberExpressionAst.NullConditional)
    }

    [Object] VisitInvokeMemberExpression([InvokeMemberExpressionAst] $invokeMemberExpressionAst) {
        return [InvokeMemberExpressionAst]::new(
            $invokeMemberExpressionAst.Extent,
            $this.Visit($invokeMemberExpressionAst.Expression),
            $this.Visit($invokeMemberExpressionAst.Member),
            [ExpressionAst[]]$this.VisitAll($invokeMemberExpressionAst.Arguments),
            $invokeMemberExpressionAst.Static,
            $invokeMemberExpressionAst.NullConditional)
    }

    [Object] VisitArrayExpression([ArrayExpressionAst] $arrayExpressionAst) {
        return [ArrayExpressionAst]::new(
            $arrayExpressionAst.Extent,
            $this.Visit($arrayExpressionAst.SubExpression))
    }

    [Object] VisitArrayLiteral([ArrayLiteralAst] $arrayLiteralAst) {
        return [ArrayLiteralAst]::new(
            $arrayLiteralAst.Extent,
            [ExpressionAst[]]$this.VisitAll($arrayLiteralAst.Elements))
    }

    [Object] VisitHashtable([HashtableAst] $hashtableAst) {
        [Tuple[ExpressionAst, StatementAst][]] $clauses = foreach ($clause in $hashtableAst.KeyValuePairs) {
            [Tuple[ExpressionAst, StatementAst]]::new(
                $this.Visit($clause.Item1),
                $this.Visit($clause.Item2))
        }

        return [HashtableAst]::new(
            $hashtableAst.Extent,
            $clauses)
    }

    [Object] VisitScriptBlockExpression([ScriptBlockExpressionAst] $scriptBlockExpressionAst) {
        return [ScriptBlockExpressionAst]::new(
            $scriptBlockExpressionAst.Extent,
            $this.Visit($scriptBlockExpressionAst.ScriptBlock))
    }

    [Object] VisitParenExpression([ParenExpressionAst] $parenExpressionAst) {
        return [ParenExpressionAst]::new(
            $parenExpressionAst.Extent,
            $this.Visit($parenExpressionAst.Pipeline))
    }

    [Object] VisitExpandableStringExpression([ExpandableStringExpressionAst] $expandableStringExpressionAst) {
        return $this.MakeExpandableString(
            $expandableStringExpressionAst.Extent,
            $expandableStringExpressionAst.Value,
            $this.GetFormatString($expandableStringExpressionAst),
            $expandableStringExpressionAst.StringConstantType,
            [ExpressionAst[]]$this.VisitAll($expandableStringExpressionAst.NestedExpressions))
    }

    [string] GetFormatString([ExpandableStringExpressionAst] $expandableStringExpressionAst) {
        $flags = [BindingFlags]::Instance -bor 'NonPublic'
        return [ExpandableStringExpressionAst].
            GetProperty('FormatExpression', $flags).
            GetValue($expandableStringExpressionAst)
    }

    [ExpandableStringExpressionAst] MakeExpandableString(
        [IScriptExtent] $extent,
        [string] $value,
        [string] $formatExpression,
        [StringConstantType] $kind,
        [ExpressionAst[]] $nestedExpressions)
    {
        $flags = [BindingFlags]::Instance -bor 'NonPublic'
        return [ExpandableStringExpressionAst].
            GetConstructor(
                $flags,
                ([IScriptExtent], [string], [string], [StringConstantType], [IEnumerable[ExpressionAst]])).
            Invoke((
                $extent,
                $value,
                $formatExpression,
                $kind,
                $nestedExpressions))
    }

    [Object] VisitIndexExpression([IndexExpressionAst] $indexExpressionAst) {
        return [IndexExpressionAst]::new(
            $indexExpressionAst.Extent,
            $this.Visit($indexExpressionAst.Target),
            $this.Visit($indexExpressionAst.Index),
            $indexExpressionAst.NullConditional)
    }

    [Object] VisitAttributedExpression([AttributedExpressionAst] $attributedExpressionAst) {
        return [AttributedExpressionAst]::new(
            $attributedExpressionAst.Extent,
            $this.Visit($attributedExpressionAst.Attribute),
            $this.Visit($attributedExpressionAst.Child))
    }

    [Object] VisitBlockStatement([BlockStatementAst] $blockStatementAst) {
        return [BlockStatementAst]::new(
            $blockStatementAst.Extent,
            $blockStatementAst.Kind,
            $this.Visit($blockStatementAst.Body))
    }
}

class VariableReplacer : AstRebuilder {
    [string] $Old

    [string] $New

    VariableReplacer([string] $old, [string] $new) {
        $this.Old = $old
        $this.New = $new
    }

    [Object] VisitVariableExpression([VariableExpressionAst] $variableExpressionAst) {
        if ($variableExpressionAst.VariablePath.UserPath -ne $this.Old) {
            return ([AstRebuilder]$this).VisitVariableExpression($variableExpressionAst)
        }

        return [VariableExpressionAst]::new(
            $variableExpressionAst.Extent,
            [VariablePath]::new($this.New),
            $variableExpressionAst.Splatted)
    }

    [Object] VisitExpandableStringExpression([ExpandableStringExpressionAst] $expandableStringExpressionAst) {
        return $this.MakeExpandableString(
            $expandableStringExpressionAst.Extent,
            ($expandableStringExpressionAst.Value -replace '/', '\'),
            ($this.GetFormatString($expandableStringExpressionAst) -replace '/', '\'),
            $expandableStringExpressionAst.StringConstantType,
            [ExpressionAst[]]$this.VisitAll($expandableStringExpressionAst.NestedExpressions))
    }
}
