using System.Collections.ObjectModel;
using System.Management.Automation.Language;

namespace Profile.ObjectPaths;

public sealed class IopMemberAccessRewriter : SyntaxRewriter
{
    private readonly CommandAst _target;

    private ExpressionAst? _result;

    private readonly HashSet<string> _targetCommands = new(StringComparer.OrdinalIgnoreCase)
    {
        "iop",
        "Invoke-ObjectPath",
    };

    private IopMemberAccessRewriter(CommandAst target)
    {
        _target = target;
    }

    public static ExpressionAst? AsMemberAccess(CommandAst command)
    {
        Ast root;
        for (root = command.Parent; root.Parent is not null; root = root.Parent)
        {
        }

        IopMemberAccessRewriter visitor = new(command);
        root.Visit(visitor);
        return visitor._result;
    }

    public override Ast VisitPipeline(PipelineAst pipelineAst)
    {
        int last = 0;
        CommandBaseAst? combined = null;
        for (int i = 1; i < pipelineAst.PipelineElements.Count; i++)
        {
            CommandBaseAst element = pipelineAst.PipelineElements[i];
            if (element is CommandAst command && command.GetCommandName() is string commandName and not "")
            {
                if (!_targetCommands.Contains(commandName))
                {
                    continue;
                }

                combined = UnwrapIop(combined, pipelineAst.PipelineElements, last, i - 1, command);
                last = i + 1;
            }
        }

        if (combined is null)
        {
            return base.VisitPipeline(pipelineAst);
        }

        if (last == pipelineAst.PipelineElements.Count)
        {
            return new PipelineAst(combined.Extent, combined);
        }

        return new PipelineAst(
            ExtentUtils.Combine(combined.Extent, pipelineAst.PipelineElements[^1].Extent),
            Enumerable.Range(last, pipelineAst.PipelineElements.Count - 1)
                .Select(i => pipelineAst.PipelineElements[i])
                .RewriteAll(this)
                .Prefix(combined));
    }

    private CommandBaseAst UnwrapIop(CommandBaseAst? prefix, ReadOnlyCollection<CommandBaseAst> elements, int start, int end, CommandAst iop)
    {
        StaticBindingResult binding = StaticParameterBinder.BindCommand(iop, resolve: true);
        StringConstantExpressionAst pathExpr = (StringConstantExpressionAst)binding.BoundParameters["Path"].Value;

        PipelineBaseAst expr = CombineElements(prefix, elements, start, end);
        ParenExpressionAst paren = new(expr.Extent, expr);

        ExpressionAst currentExpr = paren;
        foreach ((ObjectPath.Entry Entry, int Start, int End) e in ObjectPath.Parse(pathExpr.Value, throwOnIncomplete: false))
        {
            IScriptExtent accessorExtent = pathExpr.Extent.CloneWithNewOffsets(
                pathExpr.Extent.StartOffset + e.Start,
                pathExpr.Extent.EndOffset + e.End);

            if (e.Entry.IsIndex)
            {
                currentExpr = new IndexExpressionAst(
                    ExtentUtils.Combine(currentExpr.Extent, accessorExtent),
                    currentExpr,
                    e.Entry.Value.Some(out int numericIndex)
                        ? new ConstantExpressionAst(accessorExtent, numericIndex)
                        : new StringConstantExpressionAst(accessorExtent, e.Entry.Value.UnsafeGetRef<string>(), StringConstantType.SingleQuoted));

                continue;
            }

            currentExpr = new MemberExpressionAst(
                ExtentUtils.Combine(currentExpr.Extent, accessorExtent),
                currentExpr,
                new StringConstantExpressionAst(accessorExtent, e.Entry.Value.UnsafeGetRef<string>(), StringConstantType.BareWord),
                @static: false);
        }

        return new CommandExpressionAst(currentExpr.Extent, currentExpr, []);
    }

    private PipelineBaseAst CombineElements(CommandBaseAst? prefix, ReadOnlyCollection<CommandBaseAst> elements, int start, int end)
    {
        if (start == end)
        {
            return new PipelineAst(
                elements[start].Extent,
                elements[start].Rewrite(this));
        }

        return new PipelineAst(
            ExtentUtils.Combine(prefix is null ? elements[start].Extent : prefix.Extent, elements[end].Extent),
            Enumerable.Range(start, end)
                .Select(i => elements[i])
                .RewriteAll(this)
                .MaybePrefix(prefix));
    }
}

internal static class EnumerableExtensions
{
    extension<T>(IEnumerable<T> source)
    {
        public IEnumerable<T> MaybePrefix(T? item)
        {
            if (item is null)
            {
                return source;
            }

            return source.Prefix(item);
        }

        public IEnumerable<T> Prefix(T item)
        {
            yield return item;
            foreach (T sourceItem in source)
            {
                yield return sourceItem;
            }
        }
    }
}