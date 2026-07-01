using System.CodeDom;
using System.Management.Automation.Language;

namespace Profile.ObjectPaths;

internal static class RewriterExtensions
{
    extension<TAst>(TAst ast) where TAst : Ast
    {
        public TAst Rewrite(SyntaxRewriter self)
        {
            return (TAst)ast.Visit(self);
        }
    }

    extension<TAst0, TAst1>(Tuple<TAst0, TAst1> asts)
        where TAst0 : Ast
        where TAst1 : Ast
    {
        public Tuple<TAst0, TAst1> Rewrite(SyntaxRewriter self)
        {
            return Tuple.Create(asts.Item1.Rewrite(self), asts.Item2.Rewrite(self));
        }
    }

    extension<TAst0, TAst1>(IEnumerable<Tuple<TAst0, TAst1>> asts)
        where TAst0 : Ast
        where TAst1 : Ast
    {
        public IEnumerable<Tuple<TAst0, TAst1>> RewriteAll(SyntaxRewriter self)
        {
            if (asts is null)
            {
                return Enumerable.Empty<Tuple<TAst0, TAst1>>();
            }

            return ColdPath(asts, self);

            static IEnumerable<Tuple<TAst0, TAst1>> ColdPath(IEnumerable<Tuple<TAst0, TAst1>> asts, SyntaxRewriter self)
            {
                foreach (Tuple<TAst0, TAst1> ast in asts)
                {
                    yield return ast.Rewrite(self);
                }
            }
        }
    }

    extension<TAst>(IEnumerable<TAst> asts) where TAst : Ast
    {
        public IEnumerable<TAst> RewriteAll(SyntaxRewriter self)
        {
            if (asts is null)
            {
                return Enumerable.Empty<TAst>();
            }

            return ColdPath(asts, self);

            static IEnumerable<TAst> ColdPath(IEnumerable<TAst> asts, SyntaxRewriter self)
            {
                foreach (TAst ast in asts)
                {
                    yield return ast.Rewrite(self);
                }
            }
        }
    }

    extension(Ast ast)
    {
        public Ast RewriteAst(SyntaxRewriter self)
        {
            return (Ast)ast.Visit(self);
        }

        public ExpressionAst RewriteExpr(SyntaxRewriter self) => ast.RewriteTo<ExpressionAst>(self);
        public TAst RewriteTo<TAst>(SyntaxRewriter self) where TAst : Ast
        {
            Ast result = (Ast)ast.Visit(self);
            if (result is TAst tAst)
            {
                return tAst;
            }

            self.ThrowParseException(
                ast,
                "ExpectedSpecificAstType",
                $"Expected '{typeof(TAst).Name}' but got '{result?.GetType().Name}' from the syntax rewriter.");

            return Throw.Unreachable<TAst>();
        }
    }
}
