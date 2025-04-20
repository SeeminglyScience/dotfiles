using System.Management.Automation.Language;
using System.Runtime.CompilerServices;

namespace Profile;

public static class AstExtensions
{
    public static TResult Traverse<TAst, TResult>(this TAst ast, TypedVisitor<TResult> visitor)
        where TAst : Ast
        where TResult : class
    {
        return Unsafe.As<TResult>(ast.Visit(visitor));
    }

    public static TResult TraverseValue<TAst, TResult>(this TAst ast, TypedVisitor<TResult> visitor)
        where TAst : Ast
        where TResult : struct
    {
        return Unsafe.Unbox<TResult>(ast.Visit(visitor));
    }

    public static void Traverse<TAst>(this TAst ast, VoidVisitor visitor)
        where TAst : Ast
    {
        ast.Visit(visitor);
    }
}

public abstract class VoidVisitor : ICustomAstVisitor2
{
    public virtual void DefaultVisit(Ast ast) => DefaultVisit(ast);
    public virtual void VisitErrorStatement(ErrorStatementAst errorStatementAst) => DefaultVisit(errorStatementAst);
    public virtual void VisitErrorExpression(ErrorExpressionAst errorExpressionAst) => DefaultVisit(errorExpressionAst);
    public virtual void VisitScriptBlock(ScriptBlockAst scriptBlockAst) => DefaultVisit(scriptBlockAst);
    public virtual void VisitParamBlock(ParamBlockAst paramBlockAst) => DefaultVisit(paramBlockAst);
    public virtual void VisitNamedBlock(NamedBlockAst namedBlockAst) => DefaultVisit(namedBlockAst);
    public virtual void VisitTypeConstraint(TypeConstraintAst typeConstraintAst) => DefaultVisit(typeConstraintAst);
    public virtual void VisitAttribute(AttributeAst attributeAst) => DefaultVisit(attributeAst);
    public virtual void VisitNamedAttributeArgument(NamedAttributeArgumentAst namedAttributeArgumentAst) => DefaultVisit(namedAttributeArgumentAst);
    public virtual void VisitParameter(ParameterAst parameterAst) => DefaultVisit(parameterAst);
    public virtual void VisitFunctionDefinition(FunctionDefinitionAst functionDefinitionAst) => DefaultVisit(functionDefinitionAst);
    public virtual void VisitStatementBlock(StatementBlockAst statementBlockAst) => DefaultVisit(statementBlockAst);
    public virtual void VisitIfStatement(IfStatementAst ifStmtAst) => DefaultVisit(ifStmtAst);
    public virtual void VisitTrap(TrapStatementAst trapStatementAst) => DefaultVisit(trapStatementAst);
    public virtual void VisitSwitchStatement(SwitchStatementAst switchStatementAst) => DefaultVisit(switchStatementAst);
    public virtual void VisitDataStatement(DataStatementAst dataStatementAst) => DefaultVisit(dataStatementAst);
    public virtual void VisitForEachStatement(ForEachStatementAst forEachStatementAst) => DefaultVisit(forEachStatementAst);
    public virtual void VisitDoWhileStatement(DoWhileStatementAst doWhileStatementAst) => DefaultVisit(doWhileStatementAst);
    public virtual void VisitForStatement(ForStatementAst forStatementAst) => DefaultVisit(forStatementAst);
    public virtual void VisitWhileStatement(WhileStatementAst whileStatementAst) => DefaultVisit(whileStatementAst);
    public virtual void VisitCatchClause(CatchClauseAst catchClauseAst) => DefaultVisit(catchClauseAst);
    public virtual void VisitTryStatement(TryStatementAst tryStatementAst) => DefaultVisit(tryStatementAst);
    public virtual void VisitBreakStatement(BreakStatementAst breakStatementAst) => DefaultVisit(breakStatementAst);
    public virtual void VisitContinueStatement(ContinueStatementAst continueStatementAst) => DefaultVisit(continueStatementAst);
    public virtual void VisitReturnStatement(ReturnStatementAst returnStatementAst) => DefaultVisit(returnStatementAst);
    public virtual void VisitExitStatement(ExitStatementAst exitStatementAst) => DefaultVisit(exitStatementAst);
    public virtual void VisitThrowStatement(ThrowStatementAst throwStatementAst) => DefaultVisit(throwStatementAst);
    public virtual void VisitDoUntilStatement(DoUntilStatementAst doUntilStatementAst) => DefaultVisit(doUntilStatementAst);
    public virtual void VisitAssignmentStatement(AssignmentStatementAst assignmentStatementAst) => DefaultVisit(assignmentStatementAst);
    public virtual void VisitPipeline(PipelineAst pipelineAst) => DefaultVisit(pipelineAst);
    public virtual void VisitCommand(CommandAst commandAst) => DefaultVisit(commandAst);
    public virtual void VisitCommandExpression(CommandExpressionAst commandExpressionAst) => DefaultVisit(commandExpressionAst);
    public virtual void VisitCommandParameter(CommandParameterAst commandParameterAst) => DefaultVisit(commandParameterAst);
    public virtual void VisitFileRedirection(FileRedirectionAst fileRedirectionAst) => DefaultVisit(fileRedirectionAst);
    public virtual void VisitMergingRedirection(MergingRedirectionAst mergingRedirectionAst) => DefaultVisit(mergingRedirectionAst);
    public virtual void VisitBinaryExpression(BinaryExpressionAst binaryExpressionAst) => DefaultVisit(binaryExpressionAst);
    public virtual void VisitUnaryExpression(UnaryExpressionAst unaryExpressionAst) => DefaultVisit(unaryExpressionAst);
    public virtual void VisitConvertExpression(ConvertExpressionAst convertExpressionAst) => DefaultVisit(convertExpressionAst);
    public virtual void VisitConstantExpression(ConstantExpressionAst constantExpressionAst) => DefaultVisit(constantExpressionAst);
    public virtual void VisitStringConstantExpression(StringConstantExpressionAst stringConstantExpressionAst) => DefaultVisit(stringConstantExpressionAst);
    public virtual void VisitSubExpression(SubExpressionAst subExpressionAst) => DefaultVisit(subExpressionAst);
    public virtual void VisitUsingExpression(UsingExpressionAst usingExpressionAst) => DefaultVisit(usingExpressionAst);
    public virtual void VisitVariableExpression(VariableExpressionAst variableExpressionAst) => DefaultVisit(variableExpressionAst);
    public virtual void VisitTypeExpression(TypeExpressionAst typeExpressionAst) => DefaultVisit(typeExpressionAst);
    public virtual void VisitMemberExpression(MemberExpressionAst memberExpressionAst) => DefaultVisit(memberExpressionAst);
    public virtual void VisitInvokeMemberExpression(InvokeMemberExpressionAst invokeMemberExpressionAst) => DefaultVisit(invokeMemberExpressionAst);
    public virtual void VisitArrayExpression(ArrayExpressionAst arrayExpressionAst) => DefaultVisit(arrayExpressionAst);
    public virtual void VisitArrayLiteral(ArrayLiteralAst arrayLiteralAst) => DefaultVisit(arrayLiteralAst);
    public virtual void VisitHashtable(HashtableAst hashtableAst) => DefaultVisit(hashtableAst);
    public virtual void VisitScriptBlockExpression(ScriptBlockExpressionAst scriptBlockExpressionAst) => DefaultVisit(scriptBlockExpressionAst);
    public virtual void VisitParenExpression(ParenExpressionAst parenExpressionAst) => DefaultVisit(parenExpressionAst);
    public virtual void VisitExpandableStringExpression(ExpandableStringExpressionAst expandableStringExpressionAst) => DefaultVisit(expandableStringExpressionAst);
    public virtual void VisitIndexExpression(IndexExpressionAst indexExpressionAst) => DefaultVisit(indexExpressionAst);
    public virtual void VisitAttributedExpression(AttributedExpressionAst attributedExpressionAst) => DefaultVisit(attributedExpressionAst);
    public virtual void VisitBlockStatement(BlockStatementAst blockStatementAst) => DefaultVisit(blockStatementAst);
    public virtual void VisitTypeDefinition(TypeDefinitionAst typeDefinitionAst) => DefaultVisit(typeDefinitionAst);
    public virtual void VisitPropertyMember(PropertyMemberAst propertyMemberAst) => DefaultVisit(propertyMemberAst);
    public virtual void VisitFunctionMember(FunctionMemberAst functionMemberAst) => DefaultVisit(functionMemberAst);
    public virtual void VisitBaseCtorInvokeMemberExpression(BaseCtorInvokeMemberExpressionAst baseCtorInvokeMemberExpressionAst) => DefaultVisit(baseCtorInvokeMemberExpressionAst);
    public virtual void VisitUsingStatement(UsingStatementAst usingStatement) => DefaultVisit(usingStatement);
    public virtual void VisitConfigurationDefinition(ConfigurationDefinitionAst configurationDefinitionAst) => DefaultVisit(configurationDefinitionAst);
    public virtual void VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordAst) => DefaultVisit(dynamicKeywordAst);
    public virtual void VisitTernaryExpression(TernaryExpressionAst ternaryExpressionAst) => DefaultVisit(ternaryExpressionAst);
    public virtual void VisitPipelineChain(PipelineChainAst statementChainAst) => DefaultVisit(statementChainAst);

    #region Explicit Impl
    object? ICustomAstVisitor.DefaultVisit(Ast ast) { DefaultVisit(ast); return null; }
    object? ICustomAstVisitor.VisitErrorStatement(ErrorStatementAst errorStatementAst) { VisitErrorStatement(errorStatementAst); return null; }
    object? ICustomAstVisitor.VisitErrorExpression(ErrorExpressionAst errorExpressionAst) { VisitErrorExpression(errorExpressionAst); return null; }
    object? ICustomAstVisitor.VisitScriptBlock(ScriptBlockAst scriptBlockAst) { VisitScriptBlock(scriptBlockAst); return null; }
    object? ICustomAstVisitor.VisitParamBlock(ParamBlockAst paramBlockAst) { VisitParamBlock(paramBlockAst); return null; }
    object? ICustomAstVisitor.VisitNamedBlock(NamedBlockAst namedBlockAst) { VisitNamedBlock(namedBlockAst); return null; }
    object? ICustomAstVisitor.VisitTypeConstraint(TypeConstraintAst typeConstraintAst) { VisitTypeConstraint(typeConstraintAst); return null; }
    object? ICustomAstVisitor.VisitAttribute(AttributeAst attributeAst) { VisitAttribute(attributeAst); return null; }
    object? ICustomAstVisitor.VisitNamedAttributeArgument(NamedAttributeArgumentAst namedAttributeArgumentAst) { VisitNamedAttributeArgument(namedAttributeArgumentAst); return null; }
    object? ICustomAstVisitor.VisitParameter(ParameterAst parameterAst) { VisitParameter(parameterAst); return null; }
    object? ICustomAstVisitor.VisitFunctionDefinition(FunctionDefinitionAst functionDefinitionAst) { VisitFunctionDefinition(functionDefinitionAst); return null; }
    object? ICustomAstVisitor.VisitStatementBlock(StatementBlockAst statementBlockAst) { VisitStatementBlock(statementBlockAst); return null; }
    object? ICustomAstVisitor.VisitIfStatement(IfStatementAst ifStmtAst) { VisitIfStatement(ifStmtAst); return null; }
    object? ICustomAstVisitor.VisitTrap(TrapStatementAst trapStatementAst) { VisitTrap(trapStatementAst); return null; }
    object? ICustomAstVisitor.VisitSwitchStatement(SwitchStatementAst switchStatementAst) { VisitSwitchStatement(switchStatementAst); return null; }
    object? ICustomAstVisitor.VisitDataStatement(DataStatementAst dataStatementAst) { VisitDataStatement(dataStatementAst); return null; }
    object? ICustomAstVisitor.VisitForEachStatement(ForEachStatementAst forEachStatementAst) { VisitForEachStatement(forEachStatementAst); return null; }
    object? ICustomAstVisitor.VisitDoWhileStatement(DoWhileStatementAst doWhileStatementAst) { VisitDoWhileStatement(doWhileStatementAst); return null; }
    object? ICustomAstVisitor.VisitForStatement(ForStatementAst forStatementAst) { VisitForStatement(forStatementAst); return null; }
    object? ICustomAstVisitor.VisitWhileStatement(WhileStatementAst whileStatementAst) { VisitWhileStatement(whileStatementAst); return null; }
    object? ICustomAstVisitor.VisitCatchClause(CatchClauseAst catchClauseAst) { VisitCatchClause(catchClauseAst); return null; }
    object? ICustomAstVisitor.VisitTryStatement(TryStatementAst tryStatementAst) { VisitTryStatement(tryStatementAst); return null; }
    object? ICustomAstVisitor.VisitBreakStatement(BreakStatementAst breakStatementAst) { VisitBreakStatement(breakStatementAst); return null; }
    object? ICustomAstVisitor.VisitContinueStatement(ContinueStatementAst continueStatementAst) { VisitContinueStatement(continueStatementAst); return null; }
    object? ICustomAstVisitor.VisitReturnStatement(ReturnStatementAst returnStatementAst) { VisitReturnStatement(returnStatementAst); return null; }
    object? ICustomAstVisitor.VisitExitStatement(ExitStatementAst exitStatementAst) { VisitExitStatement(exitStatementAst); return null; }
    object? ICustomAstVisitor.VisitThrowStatement(ThrowStatementAst throwStatementAst) { VisitThrowStatement(throwStatementAst); return null; }
    object? ICustomAstVisitor.VisitDoUntilStatement(DoUntilStatementAst doUntilStatementAst) { VisitDoUntilStatement(doUntilStatementAst); return null; }
    object? ICustomAstVisitor.VisitAssignmentStatement(AssignmentStatementAst assignmentStatementAst) { VisitAssignmentStatement(assignmentStatementAst); return null; }
    object? ICustomAstVisitor.VisitPipeline(PipelineAst pipelineAst) { VisitPipeline(pipelineAst); return null; }
    object? ICustomAstVisitor.VisitCommand(CommandAst commandAst) { VisitCommand(commandAst); return null; }
    object? ICustomAstVisitor.VisitCommandExpression(CommandExpressionAst commandExpressionAst) { VisitCommandExpression(commandExpressionAst); return null; }
    object? ICustomAstVisitor.VisitCommandParameter(CommandParameterAst commandParameterAst) { VisitCommandParameter(commandParameterAst); return null; }
    object? ICustomAstVisitor.VisitFileRedirection(FileRedirectionAst fileRedirectionAst) { VisitFileRedirection(fileRedirectionAst); return null; }
    object? ICustomAstVisitor.VisitMergingRedirection(MergingRedirectionAst mergingRedirectionAst) { VisitMergingRedirection(mergingRedirectionAst); return null; }
    object? ICustomAstVisitor.VisitBinaryExpression(BinaryExpressionAst binaryExpressionAst) { VisitBinaryExpression(binaryExpressionAst); return null; }
    object? ICustomAstVisitor.VisitUnaryExpression(UnaryExpressionAst unaryExpressionAst) { VisitUnaryExpression(unaryExpressionAst); return null; }
    object? ICustomAstVisitor.VisitConvertExpression(ConvertExpressionAst convertExpressionAst) { VisitConvertExpression(convertExpressionAst); return null; }
    object? ICustomAstVisitor.VisitConstantExpression(ConstantExpressionAst constantExpressionAst) { VisitConstantExpression(constantExpressionAst); return null; }
    object? ICustomAstVisitor.VisitStringConstantExpression(StringConstantExpressionAst stringConstantExpressionAst) { VisitStringConstantExpression(stringConstantExpressionAst); return null; }
    object? ICustomAstVisitor.VisitSubExpression(SubExpressionAst subExpressionAst) { VisitSubExpression(subExpressionAst); return null; }
    object? ICustomAstVisitor.VisitUsingExpression(UsingExpressionAst usingExpressionAst) { VisitUsingExpression(usingExpressionAst); return null; }
    object? ICustomAstVisitor.VisitVariableExpression(VariableExpressionAst variableExpressionAst) { VisitVariableExpression(variableExpressionAst); return null; }
    object? ICustomAstVisitor.VisitTypeExpression(TypeExpressionAst typeExpressionAst) { VisitTypeExpression(typeExpressionAst); return null; }
    object? ICustomAstVisitor.VisitMemberExpression(MemberExpressionAst memberExpressionAst) { VisitMemberExpression(memberExpressionAst); return null; }
    object? ICustomAstVisitor.VisitInvokeMemberExpression(InvokeMemberExpressionAst invokeMemberExpressionAst) { VisitInvokeMemberExpression(invokeMemberExpressionAst); return null; }
    object? ICustomAstVisitor.VisitArrayExpression(ArrayExpressionAst arrayExpressionAst) { VisitArrayExpression(arrayExpressionAst); return null; }
    object? ICustomAstVisitor.VisitArrayLiteral(ArrayLiteralAst arrayLiteralAst) { VisitArrayLiteral(arrayLiteralAst); return null; }
    object? ICustomAstVisitor.VisitHashtable(HashtableAst hashtableAst) { VisitHashtable(hashtableAst); return null; }
    object? ICustomAstVisitor.VisitScriptBlockExpression(ScriptBlockExpressionAst scriptBlockExpressionAst) { VisitScriptBlockExpression(scriptBlockExpressionAst); return null; }
    object? ICustomAstVisitor.VisitParenExpression(ParenExpressionAst parenExpressionAst) { VisitParenExpression(parenExpressionAst); return null; }
    object? ICustomAstVisitor.VisitExpandableStringExpression(ExpandableStringExpressionAst expandableStringExpressionAst) { VisitExpandableStringExpression(expandableStringExpressionAst); return null; }
    object? ICustomAstVisitor.VisitIndexExpression(IndexExpressionAst indexExpressionAst) { VisitIndexExpression(indexExpressionAst); return null; }
    object? ICustomAstVisitor.VisitAttributedExpression(AttributedExpressionAst attributedExpressionAst) { VisitAttributedExpression(attributedExpressionAst); return null; }
    object? ICustomAstVisitor.VisitBlockStatement(BlockStatementAst blockStatementAst) { VisitBlockStatement(blockStatementAst); return null; }
    object? ICustomAstVisitor2.VisitTypeDefinition(TypeDefinitionAst typeDefinitionAst) { VisitTypeDefinition(typeDefinitionAst); return null; }
    object? ICustomAstVisitor2.VisitPropertyMember(PropertyMemberAst propertyMemberAst) { VisitPropertyMember(propertyMemberAst); return null; }
    object? ICustomAstVisitor2.VisitFunctionMember(FunctionMemberAst functionMemberAst) { VisitFunctionMember(functionMemberAst); return null; }
    object? ICustomAstVisitor2.VisitBaseCtorInvokeMemberExpression(BaseCtorInvokeMemberExpressionAst baseCtorInvokeMemberExpressionAst) { VisitBaseCtorInvokeMemberExpression(baseCtorInvokeMemberExpressionAst); return null; }
    object? ICustomAstVisitor2.VisitUsingStatement(UsingStatementAst usingStatement) { VisitUsingStatement(usingStatement); return null; }
    object? ICustomAstVisitor2.VisitConfigurationDefinition(ConfigurationDefinitionAst configurationDefinitionAst) { VisitConfigurationDefinition(configurationDefinitionAst); return null; }
    object? ICustomAstVisitor2.VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordAst) { VisitDynamicKeywordStatement(dynamicKeywordAst); return null; }
    object? ICustomAstVisitor2.VisitTernaryExpression(TernaryExpressionAst ternaryExpressionAst) { VisitTernaryExpression(ternaryExpressionAst); return null; }
    object? ICustomAstVisitor2.VisitPipelineChain(PipelineChainAst statementChainAst) { VisitPipelineChain(statementChainAst); return null; }
    #endregion
}

public abstract class TypedVisitor<TResult> : ICustomAstVisitor2
{
    public virtual TResult DefaultVisit(Ast ast) => DefaultVisit(ast);
    public virtual TResult VisitErrorStatement(ErrorStatementAst errorStatementAst) => DefaultVisit(errorStatementAst);
    public virtual TResult VisitErrorExpression(ErrorExpressionAst errorExpressionAst) => DefaultVisit(errorExpressionAst);
    public virtual TResult VisitScriptBlock(ScriptBlockAst scriptBlockAst) => DefaultVisit(scriptBlockAst);
    public virtual TResult VisitParamBlock(ParamBlockAst paramBlockAst) => DefaultVisit(paramBlockAst);
    public virtual TResult VisitNamedBlock(NamedBlockAst namedBlockAst) => DefaultVisit(namedBlockAst);
    public virtual TResult VisitTypeConstraint(TypeConstraintAst typeConstraintAst) => DefaultVisit(typeConstraintAst);
    public virtual TResult VisitAttribute(AttributeAst attributeAst) => DefaultVisit(attributeAst);
    public virtual TResult VisitNamedAttributeArgument(NamedAttributeArgumentAst namedAttributeArgumentAst) => DefaultVisit(namedAttributeArgumentAst);
    public virtual TResult VisitParameter(ParameterAst parameterAst) => DefaultVisit(parameterAst);
    public virtual TResult VisitFunctionDefinition(FunctionDefinitionAst functionDefinitionAst) => DefaultVisit(functionDefinitionAst);
    public virtual TResult VisitStatementBlock(StatementBlockAst statementBlockAst) => DefaultVisit(statementBlockAst);
    public virtual TResult VisitIfStatement(IfStatementAst ifStmtAst) => DefaultVisit(ifStmtAst);
    public virtual TResult VisitTrap(TrapStatementAst trapStatementAst) => DefaultVisit(trapStatementAst);
    public virtual TResult VisitSwitchStatement(SwitchStatementAst switchStatementAst) => DefaultVisit(switchStatementAst);
    public virtual TResult VisitDataStatement(DataStatementAst dataStatementAst) => DefaultVisit(dataStatementAst);
    public virtual TResult VisitForEachStatement(ForEachStatementAst forEachStatementAst) => DefaultVisit(forEachStatementAst);
    public virtual TResult VisitDoWhileStatement(DoWhileStatementAst doWhileStatementAst) => DefaultVisit(doWhileStatementAst);
    public virtual TResult VisitForStatement(ForStatementAst forStatementAst) => DefaultVisit(forStatementAst);
    public virtual TResult VisitWhileStatement(WhileStatementAst whileStatementAst) => DefaultVisit(whileStatementAst);
    public virtual TResult VisitCatchClause(CatchClauseAst catchClauseAst) => DefaultVisit(catchClauseAst);
    public virtual TResult VisitTryStatement(TryStatementAst tryStatementAst) => DefaultVisit(tryStatementAst);
    public virtual TResult VisitBreakStatement(BreakStatementAst breakStatementAst) => DefaultVisit(breakStatementAst);
    public virtual TResult VisitContinueStatement(ContinueStatementAst continueStatementAst) => DefaultVisit(continueStatementAst);
    public virtual TResult VisitReturnStatement(ReturnStatementAst returnStatementAst) => DefaultVisit(returnStatementAst);
    public virtual TResult VisitExitStatement(ExitStatementAst exitStatementAst) => DefaultVisit(exitStatementAst);
    public virtual TResult VisitThrowStatement(ThrowStatementAst throwStatementAst) => DefaultVisit(throwStatementAst);
    public virtual TResult VisitDoUntilStatement(DoUntilStatementAst doUntilStatementAst) => DefaultVisit(doUntilStatementAst);
    public virtual TResult VisitAssignmentStatement(AssignmentStatementAst assignmentStatementAst) => DefaultVisit(assignmentStatementAst);
    public virtual TResult VisitPipeline(PipelineAst pipelineAst) => DefaultVisit(pipelineAst);
    public virtual TResult VisitCommand(CommandAst commandAst) => DefaultVisit(commandAst);
    public virtual TResult VisitCommandExpression(CommandExpressionAst commandExpressionAst) => DefaultVisit(commandExpressionAst);
    public virtual TResult VisitCommandParameter(CommandParameterAst commandParameterAst) => DefaultVisit(commandParameterAst);
    public virtual TResult VisitFileRedirection(FileRedirectionAst fileRedirectionAst) => DefaultVisit(fileRedirectionAst);
    public virtual TResult VisitMergingRedirection(MergingRedirectionAst mergingRedirectionAst) => DefaultVisit(mergingRedirectionAst);
    public virtual TResult VisitBinaryExpression(BinaryExpressionAst binaryExpressionAst) => DefaultVisit(binaryExpressionAst);
    public virtual TResult VisitUnaryExpression(UnaryExpressionAst unaryExpressionAst) => DefaultVisit(unaryExpressionAst);
    public virtual TResult VisitConvertExpression(ConvertExpressionAst convertExpressionAst) => DefaultVisit(convertExpressionAst);
    public virtual TResult VisitConstantExpression(ConstantExpressionAst constantExpressionAst) => DefaultVisit(constantExpressionAst);
    public virtual TResult VisitStringConstantExpression(StringConstantExpressionAst stringConstantExpressionAst) => DefaultVisit(stringConstantExpressionAst);
    public virtual TResult VisitSubExpression(SubExpressionAst subExpressionAst) => DefaultVisit(subExpressionAst);
    public virtual TResult VisitUsingExpression(UsingExpressionAst usingExpressionAst) => DefaultVisit(usingExpressionAst);
    public virtual TResult VisitVariableExpression(VariableExpressionAst variableExpressionAst) => DefaultVisit(variableExpressionAst);
    public virtual TResult VisitTypeExpression(TypeExpressionAst typeExpressionAst) => DefaultVisit(typeExpressionAst);
    public virtual TResult VisitMemberExpression(MemberExpressionAst memberExpressionAst) => DefaultVisit(memberExpressionAst);
    public virtual TResult VisitInvokeMemberExpression(InvokeMemberExpressionAst invokeMemberExpressionAst) => DefaultVisit(invokeMemberExpressionAst);
    public virtual TResult VisitArrayExpression(ArrayExpressionAst arrayExpressionAst) => DefaultVisit(arrayExpressionAst);
    public virtual TResult VisitArrayLiteral(ArrayLiteralAst arrayLiteralAst) => DefaultVisit(arrayLiteralAst);
    public virtual TResult VisitHashtable(HashtableAst hashtableAst) => DefaultVisit(hashtableAst);
    public virtual TResult VisitScriptBlockExpression(ScriptBlockExpressionAst scriptBlockExpressionAst) => DefaultVisit(scriptBlockExpressionAst);
    public virtual TResult VisitParenExpression(ParenExpressionAst parenExpressionAst) => DefaultVisit(parenExpressionAst);
    public virtual TResult VisitExpandableStringExpression(ExpandableStringExpressionAst expandableStringExpressionAst) => DefaultVisit(expandableStringExpressionAst);
    public virtual TResult VisitIndexExpression(IndexExpressionAst indexExpressionAst) => DefaultVisit(indexExpressionAst);
    public virtual TResult VisitAttributedExpression(AttributedExpressionAst attributedExpressionAst) => DefaultVisit(attributedExpressionAst);
    public virtual TResult VisitBlockStatement(BlockStatementAst blockStatementAst) => DefaultVisit(blockStatementAst);
    public virtual TResult VisitTypeDefinition(TypeDefinitionAst typeDefinitionAst) => DefaultVisit(typeDefinitionAst);
    public virtual TResult VisitPropertyMember(PropertyMemberAst propertyMemberAst) => DefaultVisit(propertyMemberAst);
    public virtual TResult VisitFunctionMember(FunctionMemberAst functionMemberAst) => DefaultVisit(functionMemberAst);
    public virtual TResult VisitBaseCtorInvokeMemberExpression(BaseCtorInvokeMemberExpressionAst baseCtorInvokeMemberExpressionAst) => DefaultVisit(baseCtorInvokeMemberExpressionAst);
    public virtual TResult VisitUsingStatement(UsingStatementAst usingStatement) => DefaultVisit(usingStatement);
    public virtual TResult VisitConfigurationDefinition(ConfigurationDefinitionAst configurationDefinitionAst) => DefaultVisit(configurationDefinitionAst);
    public virtual TResult VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordAst) => DefaultVisit(dynamicKeywordAst);
    public virtual TResult VisitTernaryExpression(TernaryExpressionAst ternaryExpressionAst) => DefaultVisit(ternaryExpressionAst);
    public virtual TResult VisitPipelineChain(PipelineChainAst statementChainAst) => DefaultVisit(statementChainAst);

    #region Explicit Impl
    object? ICustomAstVisitor.DefaultVisit(Ast ast) => DefaultVisit(ast);
    object? ICustomAstVisitor.VisitErrorStatement(ErrorStatementAst errorStatementAst) => VisitErrorStatement(errorStatementAst);
    object? ICustomAstVisitor.VisitErrorExpression(ErrorExpressionAst errorExpressionAst) => VisitErrorExpression(errorExpressionAst);
    object? ICustomAstVisitor.VisitScriptBlock(ScriptBlockAst scriptBlockAst) => VisitScriptBlock(scriptBlockAst);
    object? ICustomAstVisitor.VisitParamBlock(ParamBlockAst paramBlockAst) => VisitParamBlock(paramBlockAst);
    object? ICustomAstVisitor.VisitNamedBlock(NamedBlockAst namedBlockAst) => VisitNamedBlock(namedBlockAst);
    object? ICustomAstVisitor.VisitTypeConstraint(TypeConstraintAst typeConstraintAst) => VisitTypeConstraint(typeConstraintAst);
    object? ICustomAstVisitor.VisitAttribute(AttributeAst attributeAst) => VisitAttribute(attributeAst);
    object? ICustomAstVisitor.VisitNamedAttributeArgument(NamedAttributeArgumentAst namedAttributeArgumentAst) => VisitNamedAttributeArgument(namedAttributeArgumentAst);
    object? ICustomAstVisitor.VisitParameter(ParameterAst parameterAst) => VisitParameter(parameterAst);
    object? ICustomAstVisitor.VisitFunctionDefinition(FunctionDefinitionAst functionDefinitionAst) => VisitFunctionDefinition(functionDefinitionAst);
    object? ICustomAstVisitor.VisitStatementBlock(StatementBlockAst statementBlockAst) => VisitStatementBlock(statementBlockAst);
    object? ICustomAstVisitor.VisitIfStatement(IfStatementAst ifStmtAst) => VisitIfStatement(ifStmtAst);
    object? ICustomAstVisitor.VisitTrap(TrapStatementAst trapStatementAst) => VisitTrap(trapStatementAst);
    object? ICustomAstVisitor.VisitSwitchStatement(SwitchStatementAst switchStatementAst) => VisitSwitchStatement(switchStatementAst);
    object? ICustomAstVisitor.VisitDataStatement(DataStatementAst dataStatementAst) => VisitDataStatement(dataStatementAst);
    object? ICustomAstVisitor.VisitForEachStatement(ForEachStatementAst forEachStatementAst) => VisitForEachStatement(forEachStatementAst);
    object? ICustomAstVisitor.VisitDoWhileStatement(DoWhileStatementAst doWhileStatementAst) => VisitDoWhileStatement(doWhileStatementAst);
    object? ICustomAstVisitor.VisitForStatement(ForStatementAst forStatementAst) => VisitForStatement(forStatementAst);
    object? ICustomAstVisitor.VisitWhileStatement(WhileStatementAst whileStatementAst) => VisitWhileStatement(whileStatementAst);
    object? ICustomAstVisitor.VisitCatchClause(CatchClauseAst catchClauseAst) => VisitCatchClause(catchClauseAst);
    object? ICustomAstVisitor.VisitTryStatement(TryStatementAst tryStatementAst) => VisitTryStatement(tryStatementAst);
    object? ICustomAstVisitor.VisitBreakStatement(BreakStatementAst breakStatementAst) => VisitBreakStatement(breakStatementAst);
    object? ICustomAstVisitor.VisitContinueStatement(ContinueStatementAst continueStatementAst) => VisitContinueStatement(continueStatementAst);
    object? ICustomAstVisitor.VisitReturnStatement(ReturnStatementAst returnStatementAst) => VisitReturnStatement(returnStatementAst);
    object? ICustomAstVisitor.VisitExitStatement(ExitStatementAst exitStatementAst) => VisitExitStatement(exitStatementAst);
    object? ICustomAstVisitor.VisitThrowStatement(ThrowStatementAst throwStatementAst) => VisitThrowStatement(throwStatementAst);
    object? ICustomAstVisitor.VisitDoUntilStatement(DoUntilStatementAst doUntilStatementAst) => VisitDoUntilStatement(doUntilStatementAst);
    object? ICustomAstVisitor.VisitAssignmentStatement(AssignmentStatementAst assignmentStatementAst) => VisitAssignmentStatement(assignmentStatementAst);
    object? ICustomAstVisitor.VisitPipeline(PipelineAst pipelineAst) => VisitPipeline(pipelineAst);
    object? ICustomAstVisitor.VisitCommand(CommandAst commandAst) => VisitCommand(commandAst);
    object? ICustomAstVisitor.VisitCommandExpression(CommandExpressionAst commandExpressionAst) => VisitCommandExpression(commandExpressionAst);
    object? ICustomAstVisitor.VisitCommandParameter(CommandParameterAst commandParameterAst) => VisitCommandParameter(commandParameterAst);
    object? ICustomAstVisitor.VisitFileRedirection(FileRedirectionAst fileRedirectionAst) => VisitFileRedirection(fileRedirectionAst);
    object? ICustomAstVisitor.VisitMergingRedirection(MergingRedirectionAst mergingRedirectionAst) => VisitMergingRedirection(mergingRedirectionAst);
    object? ICustomAstVisitor.VisitBinaryExpression(BinaryExpressionAst binaryExpressionAst) => VisitBinaryExpression(binaryExpressionAst);
    object? ICustomAstVisitor.VisitUnaryExpression(UnaryExpressionAst unaryExpressionAst) => VisitUnaryExpression(unaryExpressionAst);
    object? ICustomAstVisitor.VisitConvertExpression(ConvertExpressionAst convertExpressionAst) => VisitConvertExpression(convertExpressionAst);
    object? ICustomAstVisitor.VisitConstantExpression(ConstantExpressionAst constantExpressionAst) => VisitConstantExpression(constantExpressionAst);
    object? ICustomAstVisitor.VisitStringConstantExpression(StringConstantExpressionAst stringConstantExpressionAst) => VisitStringConstantExpression(stringConstantExpressionAst);
    object? ICustomAstVisitor.VisitSubExpression(SubExpressionAst subExpressionAst) => VisitSubExpression(subExpressionAst);
    object? ICustomAstVisitor.VisitUsingExpression(UsingExpressionAst usingExpressionAst) => VisitUsingExpression(usingExpressionAst);
    object? ICustomAstVisitor.VisitVariableExpression(VariableExpressionAst variableExpressionAst) => VisitVariableExpression(variableExpressionAst);
    object? ICustomAstVisitor.VisitTypeExpression(TypeExpressionAst typeExpressionAst) => VisitTypeExpression(typeExpressionAst);
    object? ICustomAstVisitor.VisitMemberExpression(MemberExpressionAst memberExpressionAst) => VisitMemberExpression(memberExpressionAst);
    object? ICustomAstVisitor.VisitInvokeMemberExpression(InvokeMemberExpressionAst invokeMemberExpressionAst) => VisitInvokeMemberExpression(invokeMemberExpressionAst);
    object? ICustomAstVisitor.VisitArrayExpression(ArrayExpressionAst arrayExpressionAst) => VisitArrayExpression(arrayExpressionAst);
    object? ICustomAstVisitor.VisitArrayLiteral(ArrayLiteralAst arrayLiteralAst) => VisitArrayLiteral(arrayLiteralAst);
    object? ICustomAstVisitor.VisitHashtable(HashtableAst hashtableAst) => VisitHashtable(hashtableAst);
    object? ICustomAstVisitor.VisitScriptBlockExpression(ScriptBlockExpressionAst scriptBlockExpressionAst) => VisitScriptBlockExpression(scriptBlockExpressionAst);
    object? ICustomAstVisitor.VisitParenExpression(ParenExpressionAst parenExpressionAst) => VisitParenExpression(parenExpressionAst);
    object? ICustomAstVisitor.VisitExpandableStringExpression(ExpandableStringExpressionAst expandableStringExpressionAst) => VisitExpandableStringExpression(expandableStringExpressionAst);
    object? ICustomAstVisitor.VisitIndexExpression(IndexExpressionAst indexExpressionAst) => VisitIndexExpression(indexExpressionAst);
    object? ICustomAstVisitor.VisitAttributedExpression(AttributedExpressionAst attributedExpressionAst) => VisitAttributedExpression(attributedExpressionAst);
    object? ICustomAstVisitor.VisitBlockStatement(BlockStatementAst blockStatementAst) => VisitBlockStatement(blockStatementAst);
    object? ICustomAstVisitor2.VisitTypeDefinition(TypeDefinitionAst typeDefinitionAst) => VisitTypeDefinition(typeDefinitionAst);
    object? ICustomAstVisitor2.VisitPropertyMember(PropertyMemberAst propertyMemberAst) => VisitPropertyMember(propertyMemberAst);
    object? ICustomAstVisitor2.VisitFunctionMember(FunctionMemberAst functionMemberAst) => VisitFunctionMember(functionMemberAst);
    object? ICustomAstVisitor2.VisitBaseCtorInvokeMemberExpression(BaseCtorInvokeMemberExpressionAst baseCtorInvokeMemberExpressionAst) => VisitBaseCtorInvokeMemberExpression(baseCtorInvokeMemberExpressionAst);
    object? ICustomAstVisitor2.VisitUsingStatement(UsingStatementAst usingStatement) => VisitUsingStatement(usingStatement);
    object? ICustomAstVisitor2.VisitConfigurationDefinition(ConfigurationDefinitionAst configurationDefinitionAst) => VisitConfigurationDefinition(configurationDefinitionAst);
    object? ICustomAstVisitor2.VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordAst) => VisitDynamicKeywordStatement(dynamicKeywordAst);
    object? ICustomAstVisitor2.VisitTernaryExpression(TernaryExpressionAst ternaryExpressionAst) => VisitTernaryExpression(ternaryExpressionAst);
    object? ICustomAstVisitor2.VisitPipelineChain(PipelineChainAst statementChainAst) => VisitPipelineChain(statementChainAst);
    #endregion
}