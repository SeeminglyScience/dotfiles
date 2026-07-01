using System.Diagnostics.CodeAnalysis;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Runtime.CompilerServices;

using SMAL = System.Management.Automation.Language;

namespace Profile.ObjectPaths;

public class SyntaxRewriter : TypedVisitor<Ast>
{
    [DoesNotReturn, MethodImpl(MethodImplOptions.NoInlining)]
    public void ThrowParseException(Any<Ast, Token, IScriptExtent> extent, string id, string message)
    {
        IScriptExtent resolvedExtent = extent switch
        {
            _ when extent.Some(out Ast t) => t.Extent,
            _ when extent.Some(out Token t) => t.Extent,
            _ when extent.Some(out IScriptExtent t) => t,
            _ => Throw.Unreachable<IScriptExtent>(),
        };

        throw new ParseException([new ParseError(resolvedExtent, id, message)]);
    }

    public override Ast DefaultVisit(Ast ast)
    {
        return base.DefaultVisit(ast);
    }

    public override Ast VisitErrorStatement(ErrorStatementAst errorStatementAst)
    {
        ConstructorInfo? ctor = typeof(ErrorStatementAst).GetConstructor(
            BindTo.Instance.Any,
            [
                typeof(IScriptExtent),
                typeof(Token),
                typeof(IEnumerable<KeyValuePair<string, Tuple<Token, Ast>>>),
                typeof(IEnumerable<Ast>),
                typeof(IEnumerable<Ast>),
            ]);

        if (ctor is null)
        {
            return errorStatementAst.Copy();
        }

        IScriptExtent extent = errorStatementAst.Extent;
        Token? kind = errorStatementAst.Kind;
        IEnumerable<KeyValuePair<string, Tuple<Token, Ast?>>>? flags = errorStatementAst.Flags
            ?.Select(kvp => new KeyValuePair<string, Tuple<Token, Ast?>>(
                kvp.Key,
                new(kvp.Value.Item1, kvp.Value.Item2?.Rewrite(this))));
        IEnumerable<Ast>? conditions = errorStatementAst.Conditions.RewriteAll(this);
        IEnumerable<Ast>? bodies = errorStatementAst.Bodies.RewriteAll(this);

        AlterErrorStatement(ref extent, ref kind, ref flags, ref conditions, ref bodies);

        return (Ast)ctor.Invoke([ extent, kind, flags, conditions, bodies ]);
    }

    public virtual void AlterErrorStatement(
        ref IScriptExtent extent,
        ref Token? kind,
        ref IEnumerable<KeyValuePair<string, Tuple<Token, Ast?>>>? flags,
        ref IEnumerable<Ast>? conditions,
        ref IEnumerable<Ast>? bodies)
    {
    }

    public override Ast VisitErrorExpression(ErrorExpressionAst errorExpressionAst)
    {
        ConstructorInfo? ctor = typeof(ErrorExpressionAst).GetConstructor(
            BindTo.Instance.Any,
            [
                typeof(IScriptExtent),
                typeof(IEnumerable<Ast>),
            ]);

        if (ctor is null)
        {
            return errorExpressionAst.Copy();
        }

        IScriptExtent extent = errorExpressionAst.Extent;
        IEnumerable<Ast>? nestedAst = errorExpressionAst.NestedAst.RewriteAll(this);

        AlterErrorExpression(ref extent, ref nestedAst);

        return (Ast)ctor.Invoke([ extent, nestedAst ]);
    }

    public virtual void AlterErrorExpression(
        ref IScriptExtent extent,
        ref IEnumerable<Ast>? nestedAst)
    {
    }

    public override Ast VisitTypeDefinition(TypeDefinitionAst typeDefinitionAst)
    {
        IScriptExtent extent = typeDefinitionAst.Extent;
        string name = typeDefinitionAst.Name;
        IEnumerable<AttributeAst> attributes = typeDefinitionAst.Attributes.RewriteAll(this);
        IEnumerable<MemberAst> members = typeDefinitionAst.Members.RewriteAll(this);
        SMAL.TypeAttributes typeAttributes = typeDefinitionAst.TypeAttributes;
        IEnumerable<TypeConstraintAst> baseTypes = typeDefinitionAst.BaseTypes.RewriteAll(this);
        AlterTypeDefinitionAst(ref extent, ref name, ref attributes, ref members, ref typeAttributes, ref baseTypes);
        return new TypeDefinitionAst(extent, name, attributes, members, typeAttributes, baseTypes);
    }

    public virtual void AlterTypeDefinitionAst(
        ref IScriptExtent extent,
        ref string name,
        ref IEnumerable<AttributeAst> attributes,
        ref IEnumerable<MemberAst> members,
        ref SMAL.TypeAttributes typeAttributes,
        ref IEnumerable<TypeConstraintAst> baseTypes)
    {
    }

    public override Ast VisitPropertyMember(PropertyMemberAst propertyMemberAst)
    {
        IScriptExtent extent = propertyMemberAst.Extent;
        string name = propertyMemberAst.Name;
        TypeConstraintAst propertyType = propertyMemberAst.PropertyType.Rewrite(this);
        IEnumerable<AttributeAst> attributes = propertyMemberAst.Attributes.RewriteAll(this);
        SMAL.PropertyAttributes propertyAttributes = propertyMemberAst.PropertyAttributes;
        ExpressionAst initialValue = propertyMemberAst.InitialValue.Rewrite(this);
        AlterPropertyMemberAst(ref extent, ref name, ref propertyType, ref attributes, ref propertyAttributes, ref initialValue);
        return new PropertyMemberAst(extent, name, propertyType, attributes, propertyAttributes, initialValue);
    }

    public virtual void AlterPropertyMemberAst(
        ref IScriptExtent extent,
        ref string name,
        ref TypeConstraintAst propertyType,
        ref IEnumerable<AttributeAst> attributes,
        ref SMAL.PropertyAttributes propertyAttributes,
        ref ExpressionAst initialValue)
    {
    }

    public override Ast VisitFunctionMember(FunctionMemberAst functionMemberAst)
    {
        IScriptExtent extent = functionMemberAst.Extent;
        FunctionDefinitionAst functionDefinitionAst = (typeof(FunctionMemberAst).GetField("_functionDefinitionAst", BindTo.Instance.Any)
            ?.GetValue(functionMemberAst)
            as FunctionDefinitionAst)?.Rewrite(this)
            ?? Throw.Unreachable<FunctionDefinitionAst>();

        TypeConstraintAst returnType = functionMemberAst.ReturnType.Rewrite(this);
        IEnumerable<AttributeAst> attributes = functionMemberAst.Attributes.RewriteAll(this);
        SMAL.MethodAttributes methodAttributes = functionMemberAst.MethodAttributes;
        AlterFunctionMemberAst(ref extent, ref functionDefinitionAst, ref returnType, ref attributes, ref methodAttributes);
        return new FunctionMemberAst(extent, functionDefinitionAst, returnType, attributes, methodAttributes);
    }

    public virtual void AlterFunctionMemberAst(
        ref IScriptExtent extent,
        ref FunctionDefinitionAst functionDefinitionAst,
        ref TypeConstraintAst returnType,
        ref IEnumerable<AttributeAst> attributes,
        ref SMAL.MethodAttributes methodAttributes)
    {
    }

    public override Ast VisitBaseCtorInvokeMemberExpression(BaseCtorInvokeMemberExpressionAst baseCtorInvokeMemberExpressionAst)
    {
        IScriptExtent baseKeywordExtent = baseCtorInvokeMemberExpressionAst.Expression.Extent;
        IScriptExtent baseCallExtent = baseCtorInvokeMemberExpressionAst.Extent;
        IEnumerable<ExpressionAst> arguments = baseCtorInvokeMemberExpressionAst.Arguments.RewriteAll(this);
        AlterBaseCtorInvokeMemberExpressionAst(ref baseKeywordExtent, ref baseCallExtent, ref arguments);
        return new BaseCtorInvokeMemberExpressionAst(baseKeywordExtent, baseCallExtent, arguments);
    }

    public virtual void AlterBaseCtorInvokeMemberExpressionAst(
        ref IScriptExtent baseKeywordExtent,
        ref IScriptExtent baseCallExtent,
        ref IEnumerable<ExpressionAst> arguments)
    {
    }

    public override Ast VisitUsingStatement(UsingStatementAst usingStatement)
    {
        IScriptExtent extent = usingStatement.Extent;
        UsingStatementKind kind = usingStatement.UsingStatementKind;
        HashtableAst? moduleSpecification = null;
        StringConstantExpressionAst? name = null;
        StringConstantExpressionAst? aliasTarget = null;
        AlterUsingStatementAst(ref extent, ref kind, ref name, ref aliasTarget, ref moduleSpecification);
        return kind switch
        {
            UsingStatementKind.Assembly => new UsingStatementAst(extent, kind, name),
            UsingStatementKind.Module => (moduleSpecification, name) switch
            {
                (HashtableAst, null) => new UsingStatementAst(extent, moduleSpecification),
                (null, StringConstantExpressionAst) => new UsingStatementAst(extent, kind, name),
                (null, null) => new UsingStatementAst(extent, kind, name),
                (HashtableAst, StringConstantExpressionAst) => new UsingStatementAst(extent, name, moduleSpecification),
            },
            UsingStatementKind.Namespace => new UsingStatementAst(extent, kind, name),
            UsingStatementKind.Command => new UsingStatementAst(extent, kind, name, aliasTarget),
            UsingStatementKind.Type => new UsingStatementAst(extent, kind, name, aliasTarget),
            _ => throw new ArgumentOutOfRangeException(nameof(kind)),
        };
    }

    public virtual void AlterUsingStatementAst(
        ref IScriptExtent extent,
        ref UsingStatementKind kind,
        ref StringConstantExpressionAst? name,
        ref StringConstantExpressionAst? aliasTarget,
        ref HashtableAst? moduleSpecification)
    {
    }

    public override Ast VisitConfigurationDefinition(ConfigurationDefinitionAst configurationDefinitionAst)
    {
        IScriptExtent extent = configurationDefinitionAst.Extent;
        ScriptBlockExpressionAst body = configurationDefinitionAst.Body.Rewrite(this);
        ConfigurationType type = configurationDefinitionAst.ConfigurationType;
        ExpressionAst instanceName = configurationDefinitionAst.InstanceName.Rewrite(this);
        AlterConfigurationDefinitionAst(ref extent, ref body, ref type, ref instanceName);
        return new ConfigurationDefinitionAst(extent, body, type, instanceName);
    }

    public virtual void AlterConfigurationDefinitionAst(
        ref IScriptExtent extent,
        ref ScriptBlockExpressionAst body,
        ref ConfigurationType type,
        ref ExpressionAst instanceName)
    {
    }

    public override Ast VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordAst)
    {
        IScriptExtent extent = dynamicKeywordAst.Extent;
        IEnumerable<CommandElementAst> commandElements = dynamicKeywordAst.CommandElements.RewriteAll(this);
        AlterDynamicKeywordStatementAst(ref extent, ref commandElements);
        return new DynamicKeywordStatementAst(extent, commandElements);
    }

    public virtual void AlterDynamicKeywordStatementAst(
        ref IScriptExtent extent,
        ref IEnumerable<CommandElementAst> commandElements)
    {
    }

    public override Ast VisitTernaryExpression(TernaryExpressionAst ternaryExpressionAst)
    {
        IScriptExtent extent = ternaryExpressionAst.Extent;
        ExpressionAst condition = ternaryExpressionAst.Condition.Rewrite(this);
        ExpressionAst ifTrue = ternaryExpressionAst.IfTrue.Rewrite(this);
        ExpressionAst ifFalse = ternaryExpressionAst.IfFalse.Rewrite(this);
        AlterTernaryExpressionAst(ref extent, ref condition, ref ifTrue, ref ifFalse);
        return new TernaryExpressionAst(extent, condition, ifTrue, ifFalse);
    }

    public virtual void AlterTernaryExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst condition,
        ref ExpressionAst ifTrue,
        ref ExpressionAst ifFalse)
    {
    }

    public override Ast VisitPipelineChain(PipelineChainAst statementChainAst)
    {
        IScriptExtent extent = statementChainAst.Extent;
        ChainableAst lhsChain = statementChainAst.LhsPipelineChain.Rewrite(this);
        PipelineAst rhsPipeline = statementChainAst.RhsPipeline.Rewrite(this);
        TokenKind chainOperator = statementChainAst.Operator;
        bool background = statementChainAst.Background;
        AlterPipelineChainAst(ref extent, ref lhsChain, ref rhsPipeline, ref chainOperator, ref background);
        return new PipelineChainAst(extent, lhsChain, rhsPipeline, chainOperator, background);
    }

    public virtual void AlterPipelineChainAst(
        ref IScriptExtent extent,
        ref ChainableAst lhsChain,
        ref PipelineAst rhsPipeline,
        ref TokenKind chainOperator,
        ref bool background)
    {
    }

    public override Ast VisitScriptBlock(ScriptBlockAst scriptBlockAst)
    {
        IScriptExtent extent = scriptBlockAst.Extent;
        IEnumerable<UsingStatementAst> usingStatements = scriptBlockAst.UsingStatements.RewriteAll(this);
        IEnumerable<AttributeAst> attributes = scriptBlockAst.Attributes.RewriteAll(this);
        ParamBlockAst? paramBlock = scriptBlockAst.ParamBlock?.Rewrite(this);
        NamedBlockAst? beginBlock = scriptBlockAst.BeginBlock?.Rewrite(this);
        NamedBlockAst? processBlock = scriptBlockAst.ProcessBlock?.Rewrite(this);
        NamedBlockAst? endBlock = scriptBlockAst.EndBlock?.Rewrite(this);
        NamedBlockAst? cleanBlock = scriptBlockAst.CleanBlock?.Rewrite(this);
        NamedBlockAst? dynamicParamBlock = scriptBlockAst.DynamicParamBlock?.Rewrite(this);
        AlterScriptBlockAst(ref extent, ref usingStatements, ref attributes, ref paramBlock, ref beginBlock, ref processBlock, ref endBlock, ref cleanBlock, ref dynamicParamBlock);
        return new ScriptBlockAst(extent, usingStatements, attributes, paramBlock, beginBlock, processBlock, endBlock, cleanBlock, dynamicParamBlock);
    }

    public virtual void AlterScriptBlockAst(
        ref IScriptExtent extent,
        ref IEnumerable<UsingStatementAst> usingStatements,
        ref IEnumerable<AttributeAst> attributes,
        ref ParamBlockAst? paramBlock,
        ref NamedBlockAst? beginBlock,
        ref NamedBlockAst? processBlock,
        ref NamedBlockAst? endBlock,
        ref NamedBlockAst? cleanBlock,
        ref NamedBlockAst? dynamicParamBlock)
    {
    }

    public override Ast VisitParamBlock(ParamBlockAst paramBlockAst)
    {
        IScriptExtent extent = paramBlockAst.Extent;
        IEnumerable<AttributeAst> attributes = paramBlockAst.Attributes.RewriteAll(this);
        IEnumerable<ParameterAst> parameters = paramBlockAst.Parameters.RewriteAll(this);
        AlterParamBlockAst(ref extent, ref attributes, ref parameters);
        return new ParamBlockAst(extent, attributes, parameters);
    }

    public virtual void AlterParamBlockAst(
        ref IScriptExtent extent,
        ref IEnumerable<AttributeAst> attributes,
        ref IEnumerable<ParameterAst> parameters)
    {
    }

    public override Ast VisitNamedBlock(NamedBlockAst namedBlockAst)
    {
        IScriptExtent extent = namedBlockAst.Extent;
        TokenKind blockName = namedBlockAst.BlockKind;
        IEnumerable<StatementAst> statements = namedBlockAst.Statements.RewriteAll(this);
        IEnumerable<TrapStatementAst> traps = namedBlockAst.Traps.RewriteAll(this);
        bool unnamed = namedBlockAst.Unnamed;
        AlterNamedBlockAst(ref extent, ref blockName, ref statements, ref traps, ref unnamed);
        return new NamedBlockAst(extent, blockName, new StatementBlockAst(extent, statements, traps), unnamed);
    }

    public virtual void AlterNamedBlockAst(
        ref IScriptExtent extent,
        ref TokenKind blockName,
        ref IEnumerable<StatementAst> statements,
        ref IEnumerable<TrapStatementAst> traps,
        ref bool unnamed)
    {
    }

    public override Ast VisitTypeConstraint(TypeConstraintAst typeConstraintAst)
    {
        IScriptExtent extent = typeConstraintAst.Extent;
        ITypeName typeName = typeConstraintAst.TypeName;
        AlterTypeConstraintAst(ref extent, ref typeName);
        return new TypeConstraintAst(extent, typeName);
    }

    public virtual void AlterTypeConstraintAst(
        ref IScriptExtent extent,
        ref ITypeName typeName)
    {
    }

    public override Ast VisitAttribute(AttributeAst attributeAst)
    {
        IScriptExtent extent = attributeAst.Extent;
        ITypeName typeName = attributeAst.TypeName;
        IEnumerable<ExpressionAst> positionalArguments = attributeAst.PositionalArguments.RewriteAll(this);
        IEnumerable<NamedAttributeArgumentAst> namedArguments = attributeAst.NamedArguments.RewriteAll(this);
        AlterAttributeAst(ref extent, ref typeName, ref positionalArguments, ref namedArguments);
        return new AttributeAst(extent, typeName, positionalArguments, namedArguments);
    }

    public virtual void AlterAttributeAst(
        ref IScriptExtent extent,
        ref ITypeName typeName,
        ref IEnumerable<ExpressionAst> positionalArguments,
        ref IEnumerable<NamedAttributeArgumentAst> namedArguments)
    {
    }

    public override Ast VisitNamedAttributeArgument(NamedAttributeArgumentAst namedAttributeArgumentAst)
    {
        IScriptExtent extent = namedAttributeArgumentAst.Extent;
        string argumentName = namedAttributeArgumentAst.ArgumentName;
        ExpressionAst? argument = namedAttributeArgumentAst.Argument?.Rewrite(this);
        bool expressionOmitted = namedAttributeArgumentAst.ExpressionOmitted;
        AlterNamedAttributeArgumentAst(ref extent, ref argumentName, ref argument, ref expressionOmitted);
        return new NamedAttributeArgumentAst(extent, argumentName, argument, expressionOmitted);
    }

    public virtual void AlterNamedAttributeArgumentAst(
        ref IScriptExtent extent,
        ref string argumentName,
        ref ExpressionAst? argument,
        ref bool expressionOmitted)
    {
    }

    public override Ast VisitParameter(ParameterAst parameterAst)
    {
        IScriptExtent extent = parameterAst.Extent;
        VariableExpressionAst name = parameterAst.Name.Rewrite(this);
        IEnumerable<AttributeBaseAst> attributes = parameterAst.Attributes.RewriteAll(this);
        ExpressionAst? defaultValue = parameterAst.DefaultValue?.Rewrite(this);
        AlterParameterAst(ref extent, ref name, ref attributes, ref defaultValue);
        return new ParameterAst(extent, name, attributes, defaultValue);
    }

    public virtual void AlterParameterAst(
        ref IScriptExtent extent,
        ref VariableExpressionAst name,
        ref IEnumerable<AttributeBaseAst> attributes,
        ref ExpressionAst? defaultValue)
    {
    }

    public override Ast VisitFunctionDefinition(FunctionDefinitionAst functionDefinitionAst)
    {
        IScriptExtent extent = functionDefinitionAst.Extent;
        bool isFilter = functionDefinitionAst.IsFilter;
        bool isWorkflow = functionDefinitionAst.IsWorkflow;
        string name = functionDefinitionAst.Name;
        IEnumerable<ParameterAst> parameters = functionDefinitionAst.Parameters.RewriteAll(this);
        ScriptBlockAst body = functionDefinitionAst.Body.Rewrite(this);
        AlterFunctionDefinitionAst(ref extent, ref isFilter, ref isWorkflow, ref name, ref parameters, ref body);
        return new FunctionDefinitionAst(extent, isFilter, isWorkflow, name, parameters, body);
    }

    public virtual void AlterFunctionDefinitionAst(
        ref IScriptExtent extent,
        ref bool isFilter,
        ref bool isWorkflow,
        ref string name,
        ref IEnumerable<ParameterAst> parameters,
        ref ScriptBlockAst body)
    {
    }

    public override Ast VisitStatementBlock(StatementBlockAst statementBlockAst)
    {
        IScriptExtent extent = statementBlockAst.Extent;
        IEnumerable<StatementAst> statements = statementBlockAst.Statements.RewriteAll(this);
        IEnumerable<TrapStatementAst> traps = statementBlockAst.Traps.RewriteAll(this);
        AlterStatementBlockAst(ref extent, ref statements, ref traps);
        return new StatementBlockAst(extent, statements, traps);
    }

    public virtual void AlterStatementBlockAst(
        ref IScriptExtent extent,
        ref IEnumerable<StatementAst> statements,
        ref IEnumerable<TrapStatementAst> traps)
    {
    }

    public override Ast VisitIfStatement(IfStatementAst ifStmtAst)
    {
        IScriptExtent extent = ifStmtAst.Extent;
        IEnumerable<Tuple<PipelineBaseAst, StatementBlockAst>> clauses = ifStmtAst.Clauses.RewriteAll(this);
        StatementBlockAst? elseClause = ifStmtAst.ElseClause?.Rewrite(this);
        AlterIfStatementAst(ref extent, ref clauses, ref elseClause);
        return new IfStatementAst(extent, clauses, elseClause);
    }

    public virtual void AlterIfStatementAst(
        ref IScriptExtent extent,
        ref IEnumerable<Tuple<PipelineBaseAst, StatementBlockAst>> clauses,
        ref StatementBlockAst? elseClause)
    {
    }

    public override Ast VisitTrap(TrapStatementAst trapStatementAst)
    {
        IScriptExtent extent = trapStatementAst.Extent;
        TypeConstraintAst trapType = trapStatementAst.TrapType.Rewrite(this);
        StatementBlockAst body = trapStatementAst.Body.Rewrite(this);
        AlterTrapStatementAst(ref extent, ref trapType, ref body);
        return new TrapStatementAst(extent, trapType, body);
    }

    public virtual void AlterTrapStatementAst(
        ref IScriptExtent extent,
        ref TypeConstraintAst trapType,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitSwitchStatement(SwitchStatementAst switchStatementAst)
    {
        IScriptExtent extent = switchStatementAst.Extent;
        string label = switchStatementAst.Label;
        PipelineBaseAst condition = switchStatementAst.Condition.Rewrite(this);
        SwitchFlags flags = switchStatementAst.Flags;
        IEnumerable<Tuple<ExpressionAst, StatementBlockAst>> clauses = switchStatementAst.Clauses.RewriteAll(this);
        StatementBlockAst? @default = switchStatementAst.Default?.Rewrite(this);
        AlterSwitchStatementAst(ref extent, ref label, ref condition, ref flags, ref clauses, ref @default);
        return new SwitchStatementAst(extent, label, condition, flags, clauses, @default);
    }

    public virtual void AlterSwitchStatementAst(
        ref IScriptExtent extent,
        ref string label,
        ref PipelineBaseAst condition,
        ref SwitchFlags flags,
        ref IEnumerable<Tuple<ExpressionAst, StatementBlockAst>> clauses,
        ref StatementBlockAst? @default)
    {
    }

    public override Ast VisitDataStatement(DataStatementAst dataStatementAst)
    {
        IScriptExtent extent = dataStatementAst.Extent;
        string variableName = dataStatementAst.Variable;
        IEnumerable<ExpressionAst> commandsAllowed = dataStatementAst.CommandsAllowed.RewriteAll(this);
        StatementBlockAst body = dataStatementAst.Body.Rewrite(this);
        AlterDataStatementAst(ref extent, ref variableName, ref commandsAllowed, ref body);
        return new DataStatementAst(extent, variableName, commandsAllowed, body);
    }

    public virtual void AlterDataStatementAst(
        ref IScriptExtent extent,
        ref string variableName,
        ref IEnumerable<ExpressionAst> commandsAllowed,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitForEachStatement(ForEachStatementAst forEachStatementAst)
    {
        IScriptExtent extent = forEachStatementAst.Extent;
        string? label = forEachStatementAst.Label;
        ForEachFlags flags = forEachStatementAst.Flags;
        ExpressionAst? throttleLimit = forEachStatementAst.ThrottleLimit?.Rewrite(this);
        VariableExpressionAst variable = forEachStatementAst.Variable.Rewrite(this);
        PipelineBaseAst expression = forEachStatementAst.Condition.Rewrite(this);
        StatementBlockAst body = forEachStatementAst.Body.Rewrite(this);
        AlterForEachStatementAst(ref extent, ref label, ref flags, ref throttleLimit, ref variable, ref expression, ref body);
        return new ForEachStatementAst(extent, label, flags, throttleLimit, variable, expression, body);
    }

    public virtual void AlterForEachStatementAst(
        ref IScriptExtent extent,
        ref string? label,
        ref ForEachFlags flags,
        ref ExpressionAst? throttleLimit,
        ref VariableExpressionAst variable,
        ref PipelineBaseAst expression,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitDoWhileStatement(DoWhileStatementAst doWhileStatementAst)
    {
        IScriptExtent extent = doWhileStatementAst.Extent;
        string? label = doWhileStatementAst.Label;
        PipelineBaseAst condition = doWhileStatementAst.Condition.Rewrite(this);
        StatementBlockAst body = doWhileStatementAst.Body.Rewrite(this);
        AlterDoWhileStatementAst(ref extent, ref label, ref condition, ref body);
        return new DoWhileStatementAst(extent, label, condition, body);
    }

    public virtual void AlterDoWhileStatementAst(
        ref IScriptExtent extent,
        ref string? label,
        ref PipelineBaseAst condition,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitForStatement(ForStatementAst forStatementAst)
    {
        IScriptExtent extent = forStatementAst.Extent;
        string? label = forStatementAst.Label;
        PipelineBaseAst? initializer = forStatementAst.Initializer?.Rewrite(this);
        PipelineBaseAst? condition = forStatementAst.Condition?.Rewrite(this);
        PipelineBaseAst? iterator = forStatementAst.Iterator?.Rewrite(this);
        StatementBlockAst body = forStatementAst.Body.Rewrite(this);
        AlterForStatementAst(ref extent, ref label, ref initializer, ref condition, ref iterator, ref body);
        return new ForStatementAst(extent, label, initializer, condition, iterator, body);
    }

    public virtual void AlterForStatementAst(
        ref IScriptExtent extent,
        ref string? label,
        ref PipelineBaseAst? initializer,
        ref PipelineBaseAst? condition,
        ref PipelineBaseAst? iterator,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitWhileStatement(WhileStatementAst whileStatementAst)
    {
        IScriptExtent extent = whileStatementAst.Extent;
        string? label = whileStatementAst.Label;
        PipelineBaseAst condition = whileStatementAst.Condition.Rewrite(this);
        StatementBlockAst body = whileStatementAst.Body.Rewrite(this);
        AlterWhileStatementAst(ref extent, ref label, ref condition, ref body);
        return new WhileStatementAst(extent, label, condition, body);
    }

    public virtual void AlterWhileStatementAst(
        ref IScriptExtent extent,
        ref string? label,
        ref PipelineBaseAst condition,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitCatchClause(CatchClauseAst catchClauseAst)
    {
        IScriptExtent extent = catchClauseAst.Extent;
        IEnumerable<TypeConstraintAst> catchTypes = catchClauseAst.CatchTypes.RewriteAll(this);
        StatementBlockAst body = catchClauseAst.Body.Rewrite(this);
        AlterCatchClauseAst(ref extent, ref catchTypes, ref body);
        return new CatchClauseAst(extent, catchTypes, body);
    }

    public virtual void AlterCatchClauseAst(
        ref IScriptExtent extent,
        ref IEnumerable<TypeConstraintAst> catchTypes,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitTryStatement(TryStatementAst tryStatementAst)
    {
        IScriptExtent extent = tryStatementAst.Extent;
        StatementBlockAst body = tryStatementAst.Body.Rewrite(this);
        IEnumerable<CatchClauseAst> catchClauses = tryStatementAst.CatchClauses.RewriteAll(this);
        StatementBlockAst? @finally = tryStatementAst.Finally?.Rewrite(this);
        AlterTryStatementAst(ref extent, ref body, ref catchClauses, ref @finally);
        return new TryStatementAst(extent, body, catchClauses, @finally);
    }

    public virtual void AlterTryStatementAst(
        ref IScriptExtent extent,
        ref StatementBlockAst body,
        ref IEnumerable<CatchClauseAst> catchClauses,
        ref StatementBlockAst? @finally)
    {
    }

    public override Ast VisitBreakStatement(BreakStatementAst breakStatementAst)
    {
        IScriptExtent extent = breakStatementAst.Extent;
        ExpressionAst? label = breakStatementAst.Label?.Rewrite(this);
        AlterBreakStatementAst(ref extent, ref label);
        return new BreakStatementAst(extent, label);
    }

    public virtual void AlterBreakStatementAst(
        ref IScriptExtent extent,
        ref ExpressionAst? label)
    {
    }

    public override Ast VisitContinueStatement(ContinueStatementAst continueStatementAst)
    {
        IScriptExtent extent = continueStatementAst.Extent;
        ExpressionAst? label = continueStatementAst.Label?.Rewrite(this);
        AlterContinueStatementAst(ref extent, ref label);
        return new ContinueStatementAst(extent, label);
    }

    public virtual void AlterContinueStatementAst(
        ref IScriptExtent extent,
        ref ExpressionAst? label)
    {
    }

    public override Ast VisitReturnStatement(ReturnStatementAst returnStatementAst)
    {
        IScriptExtent extent = returnStatementAst.Extent;
        PipelineBaseAst? pipeline = returnStatementAst.Pipeline?.Rewrite(this);
        AlterReturnStatementAst(ref extent, ref pipeline);
        return new ReturnStatementAst(extent, pipeline);
    }

    public virtual void AlterReturnStatementAst(
        ref IScriptExtent extent,
        ref PipelineBaseAst? pipeline)
    {
    }

    public override Ast VisitExitStatement(ExitStatementAst exitStatementAst)
    {
        IScriptExtent extent = exitStatementAst.Extent;
        PipelineBaseAst? pipeline = exitStatementAst.Pipeline?.Rewrite(this);
        AlterExitStatementAst(ref extent, ref pipeline);
        return new ExitStatementAst(extent, pipeline);
    }

    public virtual void AlterExitStatementAst(
        ref IScriptExtent extent,
        ref PipelineBaseAst? pipeline)
    {
    }

    public override Ast VisitThrowStatement(ThrowStatementAst throwStatementAst)
    {
        IScriptExtent extent = throwStatementAst.Extent;
        PipelineBaseAst? pipeline = throwStatementAst.Pipeline?.Rewrite(this);
        AlterThrowStatementAst(ref extent, ref pipeline);
        return new ThrowStatementAst(extent, pipeline);
    }

    public virtual void AlterThrowStatementAst(
        ref IScriptExtent extent,
        ref PipelineBaseAst? pipeline)
    {
    }

    public override Ast VisitDoUntilStatement(DoUntilStatementAst doUntilStatementAst)
    {
        IScriptExtent extent = doUntilStatementAst.Extent;
        string? label = doUntilStatementAst.Label;
        PipelineBaseAst condition = doUntilStatementAst.Condition.Rewrite(this);
        StatementBlockAst body = doUntilStatementAst.Body.Rewrite(this);
        AlterDoUntilStatementAst(ref extent, ref label, ref condition, ref body);
        return new DoUntilStatementAst(extent, label, condition, body);
    }

    public virtual void AlterDoUntilStatementAst(
        ref IScriptExtent extent,
        ref string? label,
        ref PipelineBaseAst condition,
        ref StatementBlockAst body)
    {
    }

    public override Ast VisitAssignmentStatement(AssignmentStatementAst assignmentStatementAst)
    {
        IScriptExtent extent = assignmentStatementAst.Extent;
        ExpressionAst left = assignmentStatementAst.Left.Rewrite(this);
        TokenKind @operator = assignmentStatementAst.Operator;
        StatementAst right = assignmentStatementAst.Right.Rewrite(this);
        IScriptExtent errorPosition = assignmentStatementAst.ErrorPosition;
        AlterAssignmentStatementAst(ref extent, ref left, ref @operator, ref right, ref errorPosition);
        return new AssignmentStatementAst(extent, left, @operator, right, errorPosition);
    }

    public virtual void AlterAssignmentStatementAst(
        ref IScriptExtent extent,
        ref ExpressionAst left,
        ref TokenKind @operator,
        ref StatementAst right,
        ref IScriptExtent errorPosition)
    {
    }

    public override Ast VisitPipeline(PipelineAst pipelineAst)
    {
        IScriptExtent extent = pipelineAst.Extent;
        IEnumerable<CommandBaseAst> pipelineElements = pipelineAst.PipelineElements.RewriteAll(this);
        bool background = pipelineAst.Background;
        AlterPipelineAst(ref extent, ref pipelineElements, ref background);
        return new PipelineAst(extent, pipelineElements, background);
    }

    public virtual void AlterPipelineAst(
        ref IScriptExtent extent,
        ref IEnumerable<CommandBaseAst> pipelineElements,
        ref bool background)
    {
    }

    public override Ast VisitCommand(CommandAst commandAst)
    {
        IScriptExtent extent = commandAst.Extent;
        IEnumerable<CommandElementAst> commandElements = commandAst.CommandElements.RewriteAll(this);
        TokenKind invocationOperator = commandAst.InvocationOperator;
        IEnumerable<RedirectionAst> redirections = commandAst.Redirections.RewriteAll(this);
        AlterCommandAst(ref extent, ref commandElements, ref invocationOperator, ref redirections);
        return new CommandAst(extent, commandElements, invocationOperator, redirections);
    }

    public virtual void AlterCommandAst(
        ref IScriptExtent extent,
        ref IEnumerable<CommandElementAst> commandElements,
        ref TokenKind invocationOperator,
        ref IEnumerable<RedirectionAst> redirections)
    {
    }

    public override Ast VisitCommandExpression(CommandExpressionAst commandExpressionAst)
    {
        IScriptExtent extent = commandExpressionAst.Extent;
        ExpressionAst expression = commandExpressionAst.Expression.Rewrite(this);
        IEnumerable<RedirectionAst> redirections = commandExpressionAst.Redirections.RewriteAll(this);
        AlterCommandExpressionAst(ref extent, ref expression, ref redirections);
        return new CommandExpressionAst(extent, expression, redirections);
    }

    public virtual void AlterCommandExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst expression,
        ref IEnumerable<RedirectionAst> redirections)
    {
    }

    public override Ast VisitCommandParameter(CommandParameterAst commandParameterAst)
    {
        IScriptExtent extent = commandParameterAst.Extent;
        string parameterName = commandParameterAst.ParameterName;
        ExpressionAst? argument = commandParameterAst.Argument?.Rewrite(this);
        IScriptExtent errorPosition = commandParameterAst.ErrorPosition;
        AlterCommandParameterAst(ref extent, ref parameterName, ref argument, ref errorPosition);
        return new CommandParameterAst(extent, parameterName, argument, errorPosition);
    }

    public virtual void AlterCommandParameterAst(
        ref IScriptExtent extent,
        ref string parameterName,
        ref ExpressionAst? argument,
        ref IScriptExtent errorPosition)
    {
    }

    public override Ast VisitFileRedirection(FileRedirectionAst fileRedirectionAst)
    {
        IScriptExtent extent = fileRedirectionAst.Extent;
        RedirectionStream stream = fileRedirectionAst.FromStream;
        ExpressionAst file = fileRedirectionAst.Location.Rewrite(this);
        bool append = fileRedirectionAst.Append;
        AlterFileRedirectionAst(ref extent, ref stream, ref file, ref append);
        return new FileRedirectionAst(extent, stream, file, append);
    }

    public virtual void AlterFileRedirectionAst(
        ref IScriptExtent extent,
        ref RedirectionStream stream,
        ref ExpressionAst file,
        ref bool append)
    {
    }

    public override Ast VisitMergingRedirection(MergingRedirectionAst mergingRedirectionAst)
    {
        IScriptExtent extent = mergingRedirectionAst.Extent;
        RedirectionStream from = mergingRedirectionAst.FromStream;
        RedirectionStream to = mergingRedirectionAst.ToStream;
        AlterMergingRedirectionAst(ref extent, ref from, ref to);
        return new MergingRedirectionAst(extent, from, to);
    }

    public virtual void AlterMergingRedirectionAst(
        ref IScriptExtent extent,
        ref RedirectionStream from,
        ref RedirectionStream to)
    {
    }

    public override Ast VisitBinaryExpression(BinaryExpressionAst binaryExpressionAst)
    {
        IScriptExtent extent = binaryExpressionAst.Extent;
        ExpressionAst left = binaryExpressionAst.Left.Rewrite(this);
        TokenKind @operator = binaryExpressionAst.Operator;
        ExpressionAst right = binaryExpressionAst.Right.Rewrite(this);
        IScriptExtent errorPosition = binaryExpressionAst.ErrorPosition;
        AlterBinaryExpressionAst(ref extent, ref left, ref @operator, ref right, ref errorPosition);
        return new BinaryExpressionAst(extent, left, @operator, right, errorPosition);
    }

    public virtual void AlterBinaryExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst left,
        ref TokenKind @operator,
        ref ExpressionAst right,
        ref IScriptExtent errorPosition)
    {
    }

    public override Ast VisitUnaryExpression(UnaryExpressionAst unaryExpressionAst)
    {
        IScriptExtent extent = unaryExpressionAst.Extent;
        TokenKind tokenKind = unaryExpressionAst.TokenKind;
        ExpressionAst child = unaryExpressionAst.Child.Rewrite(this);
        AlterUnaryExpressionAst(ref extent, ref tokenKind, ref child);
        return new UnaryExpressionAst(extent, tokenKind, child);
    }

    public virtual void AlterUnaryExpressionAst(
        ref IScriptExtent extent,
        ref TokenKind tokenKind,
        ref ExpressionAst child)
    {
    }

    public override Ast VisitConvertExpression(ConvertExpressionAst convertExpressionAst)
    {
        IScriptExtent extent = convertExpressionAst.Extent;
        TypeConstraintAst typeConstraint = convertExpressionAst.Type.Rewrite(this);
        ExpressionAst child = convertExpressionAst.Child.Rewrite(this);
        AlterConvertExpressionAst(ref extent, ref typeConstraint, ref child);
        return new ConvertExpressionAst(extent, typeConstraint, child);
    }

    public virtual void AlterConvertExpressionAst(
        ref IScriptExtent extent,
        ref TypeConstraintAst typeConstraint,
        ref ExpressionAst child)
    {
    }

    public override Ast VisitConstantExpression(ConstantExpressionAst constantExpressionAst)
    {
        IScriptExtent extent = constantExpressionAst.Extent;
        object value = constantExpressionAst.Value;
        AlterConstantExpressionAst(ref extent, ref value);
        return new ConstantExpressionAst(extent, value);
    }

    public virtual void AlterConstantExpressionAst(
        ref IScriptExtent extent,
        ref object value)
    {
    }

    public override Ast VisitStringConstantExpression(StringConstantExpressionAst stringConstantExpressionAst)
    {
        IScriptExtent extent = stringConstantExpressionAst.Extent;
        string value = stringConstantExpressionAst.Value;
        StringConstantType stringConstantType = stringConstantExpressionAst.StringConstantType;
        AlterStringConstantExpressionAst(ref extent, ref value, ref stringConstantType);
        return new StringConstantExpressionAst(extent, value, stringConstantType);
    }

    public virtual void AlterStringConstantExpressionAst(
        ref IScriptExtent extent,
        ref string value,
        ref StringConstantType stringConstantType)
    {
    }

    public override Ast VisitSubExpression(SubExpressionAst subExpressionAst)
    {
        IScriptExtent extent = subExpressionAst.Extent;
        StatementBlockAst statementBlock = subExpressionAst.SubExpression.Rewrite(this);
        AlterSubExpressionAst(ref extent, ref statementBlock);
        return new SubExpressionAst(extent, statementBlock);
    }

    public virtual void AlterSubExpressionAst(
        ref IScriptExtent extent,
        ref StatementBlockAst statementBlock)
    {
    }

    public override Ast VisitUsingExpression(UsingExpressionAst usingExpressionAst)
    {
        IScriptExtent extent = usingExpressionAst.Extent;
        ExpressionAst expressionAst = usingExpressionAst.SubExpression.Rewrite(this);
        AlterUsingExpressionAst(ref extent, ref expressionAst);
        return new UsingExpressionAst(extent, expressionAst);
    }

    public virtual void AlterUsingExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst expressionAst)
    {
    }

    public override Ast VisitVariableExpression(VariableExpressionAst variableExpressionAst)
    {
        IScriptExtent extent = variableExpressionAst.Extent;
        VariablePath variablePath = variableExpressionAst.VariablePath;
        bool splatted = variableExpressionAst.Splatted;
        AlterVariableExpressionAst(ref extent, ref variablePath, ref splatted);
        return new VariableExpressionAst(extent, variablePath, splatted);
    }

    public virtual void AlterVariableExpressionAst(
        ref IScriptExtent extent,
        ref VariablePath variablePath,
        ref bool splatted)
    {
    }

    public override Ast VisitTypeExpression(TypeExpressionAst typeExpressionAst)
    {
        IScriptExtent extent = typeExpressionAst.Extent;
        ITypeName typeName = typeExpressionAst.TypeName;
        AlterTypeExpressionAst(ref extent, ref typeName);
        return new TypeExpressionAst(extent, typeName);
    }

    public virtual void AlterTypeExpressionAst(
        ref IScriptExtent extent,
        ref ITypeName typeName)
    {
    }

    public override Ast VisitMemberExpression(MemberExpressionAst memberExpressionAst)
    {
        IScriptExtent extent = memberExpressionAst.Extent;
        ExpressionAst expression = memberExpressionAst.Expression.Rewrite(this);
        CommandElementAst member = memberExpressionAst.Member.Rewrite(this);
        bool @static = memberExpressionAst.Static;
        bool nullConditional = memberExpressionAst.NullConditional;
        AlterMemberExpressionAst(ref extent, ref expression, ref member, ref @static, ref nullConditional);
        return new MemberExpressionAst(extent, expression, member, @static, nullConditional);
    }

    public virtual void AlterMemberExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst expression,
        ref CommandElementAst member,
        ref bool @static,
        ref bool nullConditional)
    {
    }

    public override Ast VisitInvokeMemberExpression(InvokeMemberExpressionAst invokeMemberExpressionAst)
    {
        IScriptExtent extent = invokeMemberExpressionAst.Extent;
        ExpressionAst expression = invokeMemberExpressionAst.Expression.Rewrite(this);
        CommandElementAst method = invokeMemberExpressionAst.Member.Rewrite(this);
        IEnumerable<ExpressionAst> arguments = invokeMemberExpressionAst.Arguments.RewriteAll(this);
        bool @static = invokeMemberExpressionAst.Static;
        bool nullConditional = invokeMemberExpressionAst.NullConditional;
        IList<ITypeName> genericTypes = invokeMemberExpressionAst.GenericTypeArguments;
        AlterInvokeMemberExpressionAst(ref extent, ref expression, ref method, ref arguments, ref @static, ref nullConditional, ref genericTypes);
        return new InvokeMemberExpressionAst(extent, expression, method, arguments, @static, nullConditional, genericTypes);
    }

    public virtual void AlterInvokeMemberExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst expression,
        ref CommandElementAst method,
        ref IEnumerable<ExpressionAst> arguments,
        ref bool @static,
        ref bool nullConditional,
        ref IList<ITypeName> genericTypes)
    {
    }

    public override Ast VisitArrayExpression(ArrayExpressionAst arrayExpressionAst)
    {
        IScriptExtent extent = arrayExpressionAst.Extent;
        StatementBlockAst statementBlock = arrayExpressionAst.SubExpression.Rewrite(this);
        AlterArrayExpressionAst(ref extent, ref statementBlock);
        return new ArrayExpressionAst(extent, statementBlock);
    }

    public virtual void AlterArrayExpressionAst(
        ref IScriptExtent extent,
        ref StatementBlockAst statementBlock)
    {
    }

    public override Ast VisitArrayLiteral(ArrayLiteralAst arrayLiteralAst)
    {
        IScriptExtent extent = arrayLiteralAst.Extent;
        IList<ExpressionAst> elements = arrayLiteralAst.Elements.RewriteAll(this).ToArray();
        AlterArrayLiteralAst(ref extent, ref elements);
        return new ArrayLiteralAst(extent, elements);
    }

    public virtual void AlterArrayLiteralAst(
        ref IScriptExtent extent,
        ref IList<ExpressionAst> elements)
    {
    }

    public override Ast VisitHashtable(HashtableAst hashtableAst)
    {
        IScriptExtent extent = hashtableAst.Extent;
        IEnumerable<Tuple<ExpressionAst, StatementAst>> keyValuePairs = hashtableAst.KeyValuePairs.RewriteAll(this);
        AlterHashtableAst(ref extent, ref keyValuePairs);
        return new HashtableAst(extent, keyValuePairs);
    }

    public virtual void AlterHashtableAst(
        ref IScriptExtent extent,
        ref IEnumerable<Tuple<ExpressionAst, StatementAst>> keyValuePairs)
    {
    }

    public override Ast VisitScriptBlockExpression(ScriptBlockExpressionAst scriptBlockExpressionAst)
    {
        IScriptExtent extent = scriptBlockExpressionAst.Extent;
        ScriptBlockAst scriptBlock = scriptBlockExpressionAst.ScriptBlock.Rewrite(this);
        AlterScriptBlockExpressionAst(ref extent, ref scriptBlock);
        return new ScriptBlockExpressionAst(extent, scriptBlock);
    }

    public virtual void AlterScriptBlockExpressionAst(
        ref IScriptExtent extent,
        ref ScriptBlockAst scriptBlock)
    {
    }

    public override Ast VisitParenExpression(ParenExpressionAst parenExpressionAst)
    {
        IScriptExtent extent = parenExpressionAst.Extent;
        PipelineBaseAst pipeline = parenExpressionAst.Pipeline.Rewrite(this);
        AlterParenExpressionAst(ref extent, ref pipeline);
        return new ParenExpressionAst(extent, pipeline);
    }

    public virtual void AlterParenExpressionAst(
        ref IScriptExtent extent,
        ref PipelineBaseAst pipeline)
    {
    }

    public override Ast VisitExpandableStringExpression(ExpandableStringExpressionAst expandableStringExpressionAst)
    {
        IScriptExtent extent = expandableStringExpressionAst.Extent;
        string value = expandableStringExpressionAst.Value;
        string formatString = (string?)typeof(ExpandableStringExpressionAst)
            .GetProperty("FormatExpression", BindTo.Instance.Any)
            ?.GetValue(expandableStringExpressionAst)
            ?? value;
        StringConstantType type = expandableStringExpressionAst.StringConstantType;
        IEnumerable<ExpressionAst> nestedExpressions = expandableStringExpressionAst.NestedExpressions.RewriteAll(this);
        AlterExpandableStringExpressionAst(ref extent, ref value, ref formatString, ref type, ref nestedExpressions);
        return new ExpandableStringExpressionAst(extent, value, type);
    }

    public virtual void AlterExpandableStringExpressionAst(
        ref IScriptExtent extent,
        ref string value,
        ref string formatString,
        ref StringConstantType type,
        ref IEnumerable<ExpressionAst> nestedExpressions)
    {
    }

    public override Ast VisitIndexExpression(IndexExpressionAst indexExpressionAst)
    {
        IScriptExtent extent = indexExpressionAst.Extent;
        ExpressionAst target = indexExpressionAst.Target.Rewrite(this);
        ExpressionAst index = indexExpressionAst.Index.Rewrite(this);
        bool nullConditional = indexExpressionAst.NullConditional;
        AlterIndexExpressionAst(ref extent, ref target, ref index, ref nullConditional);
        return new IndexExpressionAst(extent, target, index, nullConditional);
    }

    public virtual void AlterIndexExpressionAst(
        ref IScriptExtent extent,
        ref ExpressionAst target,
        ref ExpressionAst index,
        ref bool nullConditional)
    {
    }

    public override Ast VisitAttributedExpression(AttributedExpressionAst attributedExpressionAst)
    {
        IScriptExtent extent = attributedExpressionAst.Extent;
        AttributeBaseAst attribute = attributedExpressionAst.Attribute.Rewrite(this);
        ExpressionAst child = attributedExpressionAst.Child.Rewrite(this);
        AlterAttributedExpressionAst(ref extent, ref attribute, ref child);
        return new AttributedExpressionAst(extent, attribute, child);
    }

    public virtual void AlterAttributedExpressionAst(
        ref IScriptExtent extent,
        ref AttributeBaseAst attribute,
        ref ExpressionAst child)
    {
    }

    public override Ast VisitBlockStatement(BlockStatementAst blockStatementAst)
    {
        IScriptExtent extent = blockStatementAst.Extent;
        Token kind = blockStatementAst.Kind;
        StatementBlockAst body = blockStatementAst.Body.Rewrite(this);
        AlterBlockStatementAst(ref extent, ref kind, ref body);
        return new BlockStatementAst(extent, kind, body);
    }

    public virtual void AlterBlockStatementAst(
        ref IScriptExtent extent,
        ref Token kind,
        ref StatementBlockAst body)
    {
    }
}