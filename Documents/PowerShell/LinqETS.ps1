using namespace System
using namespace System.Linq
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Reflection

Update-TypeData -Force -TypeName scriptblock -MemberType ScriptMethod -MemberName ConvertFromLambdaSyntax -Value {
    return [DelegateSyntaxRebuilder]::ConvertFromLambda($this)
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName _AsEnumerable -Value {
    if ($null -eq $this) {
        return ,@()
    }

    if ($this -isnot [IEnumerable]) {
        return ,@($this)
    }

    if ($this -isnot [IEnumerable[object]]) {
        return ,[Enumerable]::Cast[object]($this)
    }

    return ,$this
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ToDictionary -Value {
    if ($args.Count -eq 3) {
        return [Enumerable]::ToDictionary[object, object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
            [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
            [IEqualityComparer[object]] $args[2])
    }

    if ($args.Count -eq 2) {
        if ($args[1] -is [scriptblock]) {
            return [Enumerable]::ToDictionary[object, object, object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
                [Func[object, object]]$args[1].ConvertFromLambdaSyntax())
        }

        return [Enumerable]::ToDictionary[object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
            [IEqualityComparer[object]]$args[1])
    }

    return [Enumerable]::ToDictionary[object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName _Aggregate -Value {
    if ($args.Length -eq 3) {
        return ,[Enumerable]::Aggregate[object, object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [object] $args[0],
            [Func[object, object, object]]$args[1].ConvertFromLambdaSyntax(),
            [Func[object, object]]$args[2].ConvertFromLambdaSyntax())
    }

    if ($args.Length -eq 2) {
        return ,[Enumerable]::Aggregate[object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [object] $args[0],
            [Func[object, object, object]]$args[1].ConvertFromLambdaSyntax())
    }

    return ,[Enumerable]::Aggregate[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Reverse -Value {
    # If you see thise while checking for overloads, do `$obj.psbase.Reverse` instead
    if ($existing = $this.psbase.psobject.Methods['Reverse']) {
        return ,$existing.Invoke($args)
    }

    return ,[Enumerable]::Reverse[object]([IEnumerable[object]]$this._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName All -Value {
    return [Enumerable]::All[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, bool]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Append -Value {
    # If you see thise while checking for overloads, do `$obj.psbase.Append` instead
    if ($existing = $this.psbase.psobject.Methods['Append']) {
        return ,$existing.Invoke($args)
    }

    return ,[Enumerable]::Append[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [object]$args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Prepend -Value {
    return ,[Enumerable]::Prepend[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [object]$args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName GetAverage -Value {
    if ($args.Length -eq 0) {
        if ($this -is [IEnumerable[int]]) {
            return [Enumerable]::Average([IEnumerable[int]]$this)
        }

        if ($this -is [IEnumerable[long]]) {
            return [Enumerable]::Average([IEnumerable[long]]$this)
        }

        if ($this -is [IEnumerable[float]]) {
            return [Enumerable]::Average([IEnumerable[float]]$this)
        }

        if ($this -is [IEnumerable[double]]) {
            return [Enumerable]::Average([IEnumerable[double]]$this)
        }

        if ($this -is [IEnumerable[decimal]]) {
            return [Enumerable]::Average([IEnumerable[decimal]]$this)
        }

        return [Enumerable]::Average([IEnumerable[long]]$this.ForEach([long]))
    }

    return [Enumerable]::Average[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, long]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Any -Value {
    if ($args.Length -eq 0) {
        return [Enumerable]::Any[object]([IEnumerable[object]]$this._AsEnumerable())
    }

    return [Enumerable]::Any[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName OrderBy -Value {
    return ,[Enumerable]::OrderBy[object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName OrderByDescending -Value {
    return ,[Enumerable]::OrderByDescending[object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ThenBy -Value {
    if ($this -isnot [IOrderedEnumerable[object]]) {
        throw [ArgumentException]::new('Must use OrderBy* before ThenBy*', 'source')
    }

    return ,[Enumerable]::ThenBy[object, object](
        [IOrderedEnumerable[object]]$this,
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ThenByDescending -Value {
    if ($this -isnot [IOrderedEnumerable[object]]) {
        throw [ArgumentException]::new('Must use OrderBy* before ThenBy*', 'source')
    }

    return ,[Enumerable]::ThenByDescending[object, object](
        [IOrderedEnumerable[object]]$this,
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ToArray -Value {
    # If you see thise while checking for overloads, do `$obj.psbase.ToArray` instead
    if ($existing = $this.psbase.psobject.Methods['ToArray']) {
        return ,$existing.Invoke()
    }

    return ,[Enumerable]::ToArray[object]([IEnumerable[object]]$this._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ToList -Value {
    return ,[Enumerable]::ToList[object]([IEnumerable[object]]$this._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ToHashSet -Value {
    if ($args.Length -ne 0) {
        if ($args[0] -is [scriptblock]) {
            return ,[Enumerable]::ToHashSet[object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [ScriptBlockEqualityComparer]::Create($args[0]))
        }

        return ,[Enumerable]::ToHashSet[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [IEqualityComparer[object]]$args[0])
    }

    return ,[Enumerable]::ToHashSet[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [PSEqualityComparer]::Instance)
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Select -Value {
    return ,[Enumerable]::Select[object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, int, object]]$args[0].ConvertFromLambdaSyntax())
}

class SelectManyDelegate {
    hidden [scriptblock] $_sb

    static [Func[object, int, IEnumerable[object]]] Create([scriptblock] $sb) {
        $delegate = [SelectManyDelegate]::new()
        $delegate._sb = $sb.ConvertFromLambdaSyntax()
        return [Func[object, int, IEnumerable[object]]]$delegate.psobject.BaseObject.SelectMany
    }

    [IEnumerable[object]] SelectMany([object] $item, [int] $index) {
        $result = & $this._sb $item $index
        if ($null -eq $result) {
            return @()
        }

        return $result._AsEnumerable()
    }
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName SelectMany -Value {
    return ,[Enumerable]::SelectMany[object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [SelectManyDelegate]::Create($args[0]))
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName GetChunks -Value {
    return ,[Enumerable]::Chunk[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [int] $args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Concat -Value {
    # If you see thise while checking for overloads, do `$obj.psbase.Concat` instead
    if ($existing = $this.psbase.psobject.Methods['Concat']) {
        return ,$existing.Invoke($args)
    }

    return ,[Enumerable]::Concat[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [IEnumerable[object]]$args[0]._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName GetCount -Value {
    if ($args.Length -eq 0) {
        return [Enumerable]::Count[object]([IEnumerable[object]]$this._AsEnumerable())
    }

    return ,[Enumerable]::Count[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, bool]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName DefaultIfEmpty -Value {
    if ($args.Length -eq 0) {
        return ,[Enumerable]::DefaultIfEmpty[object]([IEnumerable[object]]$this._AsEnumerable())
    }

    return ,[Enumerable]::DefaultIfEmpty[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [object]$args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName GetDistinct -Value {
    if ($args.Length -eq 1) {
        if ($args[0] -is [scriptblock]) {
            return ,[Enumerable]::Distinct[object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [ScriptBlockEqualityComparer]::Create($args[0]))
        }

        return ,[Enumerable]::Distinct[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [IEqualityComparer[object]]$args[0])
    }

    return ,[Enumerable]::Distinct[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [PSEqualityComparer]::Instance)
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName ElementAt -Value {
    return ,[Enumerable]::ElementAtOrDefault[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [int] $args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Except -Value {
    if ($args.Length -eq 2) {
        if ($args[1] -is [scriptblock]) {
            return ,[Enumerable]::Except[object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [IEnumerable[object]]$args[0]._AsEnumerable(),
                [ScriptBlockEqualityComparer]::Create($args[1]))
        }

        return ,[Enumerable]::Except[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [IEnumerable[object]]$args[0]._AsEnumerable(),
            [IEqualityComparer[object]]$args[1])
    }

    return ,[Enumerable]::Except[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [IEnumerable[object]]$args[0]._AsEnumerable(),
        [PSEqualityComparer]::Instance)
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName First -Value {
    if ($args.Length -eq 1) {
        return ,[Enumerable]::FirstOrDefault[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, bool]]$args[0].ConvertFromLambdaSyntax())
    }

    return ,[Enumerable]::FirstOrDefault[object]([IEnumerable[object]]$this._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Single -Value {
    if ($args.Length -eq 1) {
        return ,[Enumerable]::SingleOrDefault[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, bool]]$args[0].ConvertFromLambdaSyntax())
    }

    return ,[Enumerable]::SingleOrDefault[object]([IEnumerable[object]]$this._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Last -Value {
    if ($args.Length -eq 1) {
        return ,[Enumerable]::LastOrDefault[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, bool]]$args[0].ConvertFromLambdaSyntax())
    }

    return ,[Enumerable]::LastOrDefault[object]([IEnumerable[object]]$this._AsEnumerable())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Take -Value {
    return ,[Enumerable]::Take[object]([IEnumerable[object]]$this._AsEnumerable(), $args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName TakeLast -Value {
    return ,[Enumerable]::TakeLast[object]([IEnumerable[object]]$this._AsEnumerable(), [int]$args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName TakeWhile -Value {
    return ,[Enumerable]::TakeWhile[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, int, bool]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Skip -Value {
    return ,[Enumerable]::Skip[object]([IEnumerable[object]]$this._AsEnumerable(), [int]$args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName SkipLast -Value {
    return ,[Enumerable]::SkipLast[object]([IEnumerable[object]]$this._AsEnumerable(), [int]$args[0])
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName SkipWhile -Value {
    return ,[Enumerable]::SkipWhile[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, int, bool]]$args[0].ConvertFromLambdaSyntax())
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName PSGroupBy -Value {
    if ($args.Length -eq 1) {
        return ,[Enumerable]::GroupBy[object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
            [PSEqualityComparer]::Instance)
    }

    if ($args.Length -eq 2) {
        return ,[Enumerable]::GroupBy[object, object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
            [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
            [PSEqualityComparer]::Instance)
    }

    if ($args.Length -eq 3) {
        return ,[Enumerable]::GroupBy[object, object, object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
            [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
            [Func[object, IEnumerable[object], object]]$args[2].ConvertFromLambdaSyntax(),
            [PSEqualityComparer]::Instance)
    }

    return ,[Enumerable]::GroupBy[object, object, object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [Func[object, object]]$args[0].ConvertFromLambdaSyntax(),
        [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
        [Func[object, IEnumerable[object], object]]$args[2].ConvertFromLambdaSyntax(),
        [ScriptBlockEqualityComparer]::Create($args[3]))
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName GroupJoin -Value {
    if ($args.Length -eq 5) {
        if ($args[4] -is [scriptblock]) {
            return ,[Enumerable]::GroupJoin[object, object, object, object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [IEnumerable[object]]$args[0]._AsEnumerable(),
                [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
                [Func[object, object]]$args[2].ConvertFromLambdaSyntax(),
                [Func[object, IEnumerable[object], object]]$args[3].ConvertFromLambdaSyntax(),
                [ScriptBlockEqualityComparer]::Create($args[4]))
        }

        return ,[Enumerable]::GroupJoin[object, object, object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [IEnumerable[object]]$args[0]._AsEnumerable(),
            [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
            [Func[object, object]]$args[2].ConvertFromLambdaSyntax(),
            [Func[object, IEnumerable[object], object]]$args[3].ConvertFromLambdaSyntax(),
            [IEqualityComparer[object]]$args[4])
    }

    return ,[Enumerable]::GroupJoin[object, object, object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [IEnumerable[object]]$args[0]._AsEnumerable(),
        [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
        [Func[object, object]]$args[2].ConvertFromLambdaSyntax(),
        [Func[object, IEnumerable[object], object]]$args[3].ConvertFromLambdaSyntax(),
        [PSEqualityComparer]::Instance)
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Intersect -Value {
    if ($args.Length -eq 2) {
        if ($args[1] -is [scriptblock]) {
            return ,[Enumerable]::Intersect[object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [IEnumerable[object]]$args[0]._AsEnumerable(),
                [ScriptBlockEqualityComparer]::Create($args[1]))
        }

        return ,[Enumerable]::Intersect[object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [IEnumerable[object]]$args[0]._AsEnumerable(),
            [IEqualityComparer[object]]$args[1])
    }

    return ,[Enumerable]::Intersect[object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [IEnumerable[object]]$args[0]._AsEnumerable(),
        [PSEqualityComparer]::Instance)
}

Update-TypeData -Force -TypeName System.Object -MemberType ScriptMethod -MemberName Join -Value {
    # If you see thise while checking for overloads, do `$obj.psbase.Join` instead
    if ($existing = $this.psbase.psobject.Methods['Join']) {
        return ,$existing.Invoke($args)
    }

    if ($args.Length -eq 5) {
        if ($args[4] -is [scriptblock]) {
            return ,[Enumerable]::Join[object, object, object, object](
                [IEnumerable[object]]$this._AsEnumerable(),
                [IEnumerable[object]]$args[0]._AsEnumerable(),
                [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
                [Func[object, object]]$args[2].ConvertFromLambdaSyntax(),
                [Func[object, object, object]]$args[3].ConvertFromLambdaSyntax(),
                [ScriptBlockEqualityComparer]::Create($args[4]))
        }

        return ,[Enumerable]::Join[object, object, object, object](
            [IEnumerable[object]]$this._AsEnumerable(),
            [IEnumerable[object]]$args[0]._AsEnumerable(),
            [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
            [Func[object, object]]$args[2].ConvertFromLambdaSyntax(),
            [Func[object, object, object]]$args[3].ConvertFromLambdaSyntax(),
            [IEqualityComparer[object]]$args[4])
    }

    return ,[Enumerable]::Join[object, object, object, object](
        [IEnumerable[object]]$this._AsEnumerable(),
        [IEnumerable[object]]$args[0]._AsEnumerable(),
        [Func[object, object]]$args[1].ConvertFromLambdaSyntax(),
        [Func[object, object]]$args[2].ConvertFromLambdaSyntax(),
        [Func[object, object, object]]$args[3].ConvertFromLambdaSyntax(),
        [PSEqualityComparer]::Instance)
}

class ScriptBlockEqualityComparer : IEqualityComparer[object] {
    hidden [scriptblock] $_sb

    ScriptBlockEqualityComparer([scriptblock] $sb) {
        $this._sb = $sb
    }

    static [ScriptBlockEqualityComparer] Create([scriptblock] $sb) {
        return [ScriptBlockEqualityComparer]::new($sb.ConvertFromLambdaSyntax())
    }

    [bool] Equals([Object] $x, [Object] $y) {
        return & $this._sb $x $y
    }

    [int] GetHashCode([Object] $obj) {
        return ($obj)?.GetHashCode() ?? 0
    }
}

class PSEqualityComparer : IEqualityComparer[object] {
    static [PSEqualityComparer] $Instance = [PSEqualityComparer]::new()

    [bool] Equals([Object] $x, [Object] $y) {
        return $x -eq $y
    }

    [int] GetHashCode([Object] $obj) {
        return ($obj)?.GetHashCode() ?? 0
    }
}

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

class DelegateSyntaxRebuilder : AstRebuilder {
    hidden static [Reflection.MethodInfo] $s_getSessionStateInternal

    hidden static [Reflection.MethodInfo] $s_setSessionStateInternal

    hidden [bool] $_alreadyDone

    [bool] $IsNotLambda

    static DelegateSyntaxRebuilder() {
        $property = [scriptblock].GetProperty('SessionStateInternal', [Reflection.BindingFlags]::Instance -bor 'NonPublic')

        [DelegateSyntaxRebuilder]::s_getSessionStateInternal = $property.GetGetMethod($true)
        [DelegateSyntaxRebuilder]::s_setSessionStateInternal = $property.GetSetMethod($true)
    }

    static [scriptblock] ConvertFromLambda([scriptblock] $source) {
        $visitor = [DelegateSyntaxRebuilder]::new()
        $result = $source.Ast.Visit($visitor)
        if ($visitor.IsNotLambda) {
            return $source
        }

        $result = $result.GetScriptBlock()

        [DelegateSyntaxRebuilder]::s_setSessionStateInternal.Invoke(
            $result,
            @([DelegateSyntaxRebuilder]::s_getSessionStateInternal.Invoke($source, @())))

        return $result
    }

    [object] VisitScriptBlock([ScriptBlockAst] $scriptBlockAst) {
        if ($this._alreadyDone) {
            return ([AstRebuilder]$this).VisitScriptBlock($scriptBlockAst)
        }

        $this._alreadyDone = $true

        $this.IsNotLambda = $scriptBlockAst.ParamBlock -or
            $scriptBlockAst.EndBlock.Statements[0] -isnot [AssignmentStatementAst] -or
            $scriptBlockAst.EndBlock.Statements[0].Right -isnot [PipelineAst] -or
            $scriptBlockAst.EndBlock.Statements[0].Right.PipelineElements[0] -isnot [CommandAst] -or
            $scriptBlockAst.EndBlock.Statements[0].Right.PipelineElements[0].CommandElements[0].Value -ne '>'

        if ($this.IsNotLambda) {
            return $scriptBlockAst
        }

        $params = $scriptBlockAst.EndBlock.Statements[0].Left
        if ($params -is [ParenExpressionAst]) {
            $params = $params.Pipeline.PipelineElements[0].Expression
        }

        if ($params -is [ArrayLiteralAst]) {
            $params = $params.Elements
        }

        $params = foreach ($param in $params) {
            [ParameterAst]::new(
                $param.Extent,
                $this.Visit($param),
                [AttributeBaseAst[]]@(),
                $null)
        }

        $paramBlock = [ParamBlockAst]::new(
            $scriptBlockAst.EndBlock.Statements[0].Left.Extent,
            [AttributeAst[]]@(),
            [ParameterAst[]]$params)

        for ($parent = $scriptBlockAst; $null -ne $parent; $parent = $parent.Parent) { }

        $commandElements = $scriptBlockAst.EndBlock.Statements[0].Right.PipelineElements[0].CommandElements
        if ($commandElements.Count -gt 2 -or $commandElements[1].StringConstantType -eq 'BareWord') {
            throw [ParseException]::new(
                [ParseError]::new(
                    $commandElements[$commandElements.Count -gt 2 ? 2 : 1].Extent,
                    'UnexpectedElementInLambda',
                    'Expressions more complex than a member expression or variable expression must be wrapped in a scriptblock. e.g. $x, $y => { $x + $y }'))
        }

        $firstCommandElement = $this.Visit($scriptBlockAst.EndBlock.Statements[0].Right.PipelineElements[0].CommandElements[1])
        $newEndBlock = $null
        if ($firstCommandElement.ScriptBlock) {
            $newEndBlock = $this.Visit($firstCommandElement.ScriptBlock.EndBlock)
        } else {
            $newEndBlock = [NamedBlockAst]::new(
                $firstCommandElement.Extent,
                [TokenKind]::End,
                [StatementBlockAst]::new(
                    $firstCommandElement.Extent,
                    [StatementAst[]](
                        [PipelineAst]::new(
                            $firstCommandElement.Extent,
                            [CommandExpressionAst]::new(
                                $firstCommandElement.Extent,
                                $this.Visit($firstCommandElement),
                                [RedirectionAst[]]@()))),
                    [TrapStatementAst[]]@()),
                <# unnamed: #> $true)
        }

        return [ScriptBlockAst]::new(
            $scriptBlockAst.Extent,
            [UsingStatementAst[]]$this.VisitAll($parent.UsingStatements),
            $paramBlock,
            $null,
            $null,
            $newEndBlock,
            $null)
    }
}
