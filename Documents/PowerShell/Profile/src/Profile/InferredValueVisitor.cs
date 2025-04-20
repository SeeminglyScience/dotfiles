using System.Collections;
using System.Management.Automation;
using System.Management.Automation.Internal;
using System.Management.Automation.Language;
using System.Runtime;
using System.Runtime.CompilerServices;

namespace Profile;

internal sealed class CannotInfer : PSObject
{
    public static CannotInfer Value = new();
}

internal abstract class PsuedoPipeBase
{
    public bool TryGetRawValue(out object? rawValue)
    {
        rawValue = GetRawValue();
        if (rawValue == AutomationNull.Value)
        {
            rawValue = null;
            return false;
        }

        return true;
    }

    public abstract void Write(object? value);

    public abstract object? GetRawValue();

    public abstract void Clear();

    public virtual void WriteTo(PsuedoPipeBase pipe)
    {
        object? rawValue = GetRawValue();
        if (rawValue == AutomationNull.Value)
        {
            return;
        }

        pipe.Write(rawValue);
    }
}

internal class PsuedoPipe : PsuedoPipeBase
{
    private List<object?>? _list;

    public override object? GetRawValue()
    {
        if (_list is null)
        {
            return AutomationNull.Value;
        }

        if (_list is [var singleItem])
        {
            return singleItem;
        }

        return _list.ToArray();
    }

    public override void Write(object? value)
    {
        if (value == AutomationNull.Value)
        {
            return;
        }

        if (value == CannotInfer.Value)
        {
            (_list ??= new()).Add(value);
            return;
        }

        if (value is null)
        {
            _list ??= new();
            _list.Add(null);
            return;
        }

        IEnumerator? enumerator = null;
        try
        {
            enumerator = LanguagePrimitives.GetEnumerator(value);
            if (enumerator is not null)
            {
                while (enumerator.MoveNext())
                {
                    object? current = enumerator.Current;
                    if (current == AutomationNull.Value)
                    {
                        continue;
                    }

                    _list ??= new();
                    _list.Add(current);
                }

                return;
            }
        }
        catch (Exception e) when (e is FlowControlException or PipelineStoppedException or TerminateException)
        {
            throw;
        }
        catch
        {
            // ignore
        }
        finally
        {
            if (enumerator is IDisposable disposable)
            {
                try
                {
                    disposable.Dispose();
                }
                catch
                {
                    // ignore
                }
            }
        }

        _list ??= new();
        _list.Add(value);
    }

    public override void WriteTo(PsuedoPipeBase pipe)
    {
        if (_list is null)
        {
            return;
        }

        if (_list is [var singleItem])
        {
            pipe.Write(singleItem);
            return;
        }

        if (pipe is PsuedoPipe pipe2)
        {
            (pipe2._list ??= new()).AddRange(_list);
            return;
        }

        pipe.Write(GetRawValue());
    }

    public override void Clear()
    {
        // _list
    }
}

// internal sealed class DirectPsuedoPipe : PsuedoPipeBase
// {
//     private object? _rawValue = AutomationNull.Value;

//     public override object? GetRawValue() => _rawValue;

//     public override void Write(object? value)
//     {
//         _rawValue = value;
//     }
// }

// public class InferredValueVisitor : ICustomAstVisitor2
// {
//     private CallSite<Func<CallSite, object?, bool>>? _truthyCallSite;

//     private PsuedoPipeBase _pipe = new PsuedoPipe();

//     private bool IsTruthy(object? value)
//     {
//         CallSite<Func<CallSite, object?, bool>> cs =
//             _truthyCallSite ??= CallSite<Func<CallSite, object?, bool>>.Create(
//                 ReflectionCache.PSConvertBinder.Get(typeof(bool)));

//         return cs.Target(cs, value);
//     }

//     public virtual object? DefaultVisit(Ast ast)
//     {
//         return DefaultVisit(ast);
//     }
//     public virtual object? VisitErrorStatement(ErrorStatementAst errorStatementAst)
//     {
//         return DefaultVisit(errorStatementAst);
//     }
//     public virtual object? VisitErrorExpression(ErrorExpressionAst errorExpressionAst)
//     {
//         return DefaultVisit(errorExpressionAst);
//     }
//     public virtual object? VisitScriptBlock(ScriptBlockAst scriptBlockAst)
//     {
//         return DefaultVisit(scriptBlockAst);
//     }
//     public virtual object? VisitParamBlock(ParamBlockAst paramBlockAst)
//     {
//         return DefaultVisit(paramBlockAst);
//     }
//     public virtual object? VisitNamedBlock(NamedBlockAst namedBlockAst)
//     {
//         return DefaultVisit(namedBlockAst);
//     }
//     public virtual object? VisitTypeConstraint(TypeConstraintAst typeConstraintAst)
//     {
//         return DefaultVisit(typeConstraintAst);
//     }
//     public virtual object? VisitAttribute(AttributeAst attributeAst)
//     {
//         return DefaultVisit(attributeAst);
//     }
//     public virtual object? VisitNamedAttributeArgument(NamedAttributeArgumentAst namedAttributeArgumentAst)
//     {
//         return DefaultVisit(namedAttributeArgumentAst);
//     }
//     public virtual object? VisitParameter(ParameterAst parameterAst)
//     {
//         return DefaultVisit(parameterAst);
//     }
//     public virtual object? VisitFunctionDefinition(FunctionDefinitionAst functionDefinitionAst)
//     {
//         return DefaultVisit(functionDefinitionAst);
//     }
//     public virtual object? VisitStatementBlock(StatementBlockAst statementBlockAst)
//     {
//         return DefaultVisit(statementBlockAst);
//     }
//     public virtual object? VisitIfStatement(IfStatementAst ifStmtAst)
//     {
//         foreach ((PipelineBaseAst condition, StatementBlockAst body) in ifStmtAst.Clauses)
//         {

//         }
//     }
//     public virtual object? VisitTrap(TrapStatementAst trapStatementAst)
//     {
//         return DefaultVisit(trapStatementAst);
//     }
//     public virtual object? VisitSwitchStatement(SwitchStatementAst switchStatementAst)
//     {
//         return DefaultVisit(switchStatementAst);
//     }
//     public virtual object? VisitDataStatement(DataStatementAst dataStatementAst)
//     {
//         return DefaultVisit(dataStatementAst);
//     }
//     public virtual object? VisitForEachStatement(ForEachStatementAst forEachStatementAst)
//     {
//         return DefaultVisit(forEachStatementAst);
//     }
//     public virtual object? VisitDoWhileStatement(DoWhileStatementAst doWhileStatementAst)
//     {
//         return DefaultVisit(doWhileStatementAst);
//     }
//     public virtual object? VisitForStatement(ForStatementAst forStatementAst)
//     {
//         return DefaultVisit(forStatementAst);
//     }
//     public virtual object? VisitWhileStatement(WhileStatementAst whileStatementAst)
//     {
//         return DefaultVisit(whileStatementAst);
//     }
//     public virtual object? VisitCatchClause(CatchClauseAst catchClauseAst)
//     {
//         return DefaultVisit(catchClauseAst);
//     }
//     public virtual object? VisitTryStatement(TryStatementAst tryStatementAst)
//     {
//         return DefaultVisit(tryStatementAst);
//     }
//     public virtual object? VisitBreakStatement(BreakStatementAst breakStatementAst)
//     {
//         return DefaultVisit(breakStatementAst);
//     }
//     public virtual object? VisitContinueStatement(ContinueStatementAst continueStatementAst)
//     {
//         return DefaultVisit(continueStatementAst);
//     }
//     public virtual object? VisitReturnStatement(ReturnStatementAst returnStatementAst)
//     {
//         return DefaultVisit(returnStatementAst);
//     }
//     public virtual object? VisitExitStatement(ExitStatementAst exitStatementAst)
//     {
//         return DefaultVisit(exitStatementAst);
//     }
//     public virtual object? VisitThrowStatement(ThrowStatementAst throwStatementAst)
//     {
//         return DefaultVisit(throwStatementAst);
//     }
//     public virtual object? VisitDoUntilStatement(DoUntilStatementAst doUntilStatementAst)
//     {
//         return DefaultVisit(doUntilStatementAst);
//     }
//     public virtual object? VisitAssignmentStatement(AssignmentStatementAst assignmentStatementAst)
//     {
//         return DefaultVisit(assignmentStatementAst);
//     }
//     public virtual object? VisitPipeline(PipelineAst pipelineAst)
//     {
//         return DefaultVisit(pipelineAst);
//     }
//     public virtual object? VisitCommand(CommandAst commandAst)
//     {
//         return DefaultVisit(commandAst);
//     }
//     public virtual object? VisitCommandExpression(CommandExpressionAst commandExpressionAst)
//     {
//         return DefaultVisit(commandExpressionAst);
//     }
//     public virtual object? VisitCommandParameter(CommandParameterAst commandParameterAst)
//     {
//         return DefaultVisit(commandParameterAst);
//     }
//     public virtual object? VisitFileRedirection(FileRedirectionAst fileRedirectionAst)
//     {
//         return DefaultVisit(fileRedirectionAst);
//     }
//     public virtual object? VisitMergingRedirection(MergingRedirectionAst mergingRedirectionAst)
//     {
//         return DefaultVisit(mergingRedirectionAst);
//     }
//     public virtual object? VisitBinaryExpression(BinaryExpressionAst binaryExpressionAst)
//     {
//         return DefaultVisit(binaryExpressionAst);
//     }
//     public virtual object? VisitUnaryExpression(UnaryExpressionAst unaryExpressionAst)
//     {
//         return DefaultVisit(unaryExpressionAst);
//     }
//     public virtual object? VisitConvertExpression(ConvertExpressionAst convertExpressionAst)
//     {
//         return DefaultVisit(convertExpressionAst);
//     }
//     public virtual object? VisitConstantExpression(ConstantExpressionAst constantExpressionAst)
//     {
//         return DefaultVisit(constantExpressionAst);
//     }
//     public virtual object? VisitStringConstantExpression(StringConstantExpressionAst stringConstantExpressionAst)
//     {
//         return DefaultVisit(stringConstantExpressionAst);
//     }
//     public virtual object? VisitSubExpression(SubExpressionAst subExpressionAst)
//     {
//         return DefaultVisit(subExpressionAst);
//     }
//     public virtual object? VisitUsingExpression(UsingExpressionAst usingExpressionAst)
//     {
//         return DefaultVisit(usingExpressionAst);
//     }
//     public virtual object? VisitVariableExpression(VariableExpressionAst variableExpressionAst)
//     {
//         return DefaultVisit(variableExpressionAst);
//     }
//     public virtual object? VisitTypeExpression(TypeExpressionAst typeExpressionAst)
//     {
//         return DefaultVisit(typeExpressionAst);
//     }
//     public virtual object? VisitMemberExpression(MemberExpressionAst memberExpressionAst)
//     {
//         return DefaultVisit(memberExpressionAst);
//     }
//     public virtual object? VisitInvokeMemberExpression(InvokeMemberExpressionAst invokeMemberExpressionAst)
//     {
//         return DefaultVisit(invokeMemberExpressionAst);
//     }
//     public virtual object? VisitArrayExpression(ArrayExpressionAst arrayExpressionAst)
//     {
//         return DefaultVisit(arrayExpressionAst);
//     }
//     public virtual object? VisitArrayLiteral(ArrayLiteralAst arrayLiteralAst)
//     {
//         return DefaultVisit(arrayLiteralAst);
//     }
//     public virtual object? VisitHashtable(HashtableAst hashtableAst)
//     {
//         return DefaultVisit(hashtableAst);
//     }
//     public virtual object? VisitScriptBlockExpression(ScriptBlockExpressionAst scriptBlockExpressionAst)
//     {
//         return DefaultVisit(scriptBlockExpressionAst);
//     }
//     public virtual object? VisitParenExpression(ParenExpressionAst parenExpressionAst)
//     {
//         return DefaultVisit(parenExpressionAst);
//     }
//     public virtual object? VisitExpandableStringExpression(ExpandableStringExpressionAst expandableStringExpressionAst)
//     {
//         return DefaultVisit(expandableStringExpressionAst);
//     }
//     public virtual object? VisitIndexExpression(IndexExpressionAst indexExpressionAst)
//     {
//         return DefaultVisit(indexExpressionAst);
//     }
//     public virtual object? VisitAttributedExpression(AttributedExpressionAst attributedExpressionAst)
//     {
//         return DefaultVisit(attributedExpressionAst);
//     }
//     public virtual object? VisitBlockStatement(BlockStatementAst blockStatementAst)
//     {
//         return DefaultVisit(blockStatementAst);
//     }
//     public virtual object? VisitTypeDefinition(TypeDefinitionAst typeDefinitionAst)
//     {
//         return DefaultVisit(typeDefinitionAst);
//     }
//     public virtual object? VisitPropertyMember(PropertyMemberAst propertyMemberAst)
//     {
//         return DefaultVisit(propertyMemberAst);
//     }
//     public virtual object? VisitFunctionMember(FunctionMemberAst functionMemberAst)
//     {
//         return DefaultVisit(functionMemberAst);
//     }
//     public virtual object? VisitBaseCtorInvokeMemberExpression(BaseCtorInvokeMemberExpressionAst baseCtorInvokeMemberExpressionAst)
//     {
//         return DefaultVisit(baseCtorInvokeMemberExpressionAst);
//     }
//     public virtual object? VisitUsingStatement(UsingStatementAst usingStatement)
//     {
//         return DefaultVisit(usingStatement);
//     }
//     public virtual object? VisitConfigurationDefinition(ConfigurationDefinitionAst configurationDefinitionAst)
//     {
//         return DefaultVisit(configurationDefinitionAst);
//     }
//     public virtual object? VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordAst)
//     {
//         return DefaultVisit(dynamicKeywordAst);
//     }
//     public virtual object? VisitTernaryExpression(TernaryExpressionAst ternaryExpressionAst)
//     {
//         return DefaultVisit(ternaryExpressionAst);
//     }
//     public virtual object? VisitPipelineChain(PipelineChainAst statementChainAst)
//     {
//         return DefaultVisit(statementChainAst);
//     }
// }