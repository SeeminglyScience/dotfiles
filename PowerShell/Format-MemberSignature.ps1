using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.Reflection
using namespace System.Runtime.InteropServices
using namespace System.Text

class EscapeChars {
    static [char] $Slash = [char]0x005c

    static [char] $Null = [char]0x0000

    static [char] $Alert = [char]0x0007

    static [char] $Backspace = [char]0x0008

    static [char] $FormFeed = [char]0x000C

    static [char] $NewLine = [char]0x000A

    static [char] $CarriageReturn = [char]0x000D

    static [char] $HorizontalTab = [char]0x0009

    static [char] $VerticalTab = [char]0x000B
}

class SyntaxFormatting {
    static [SyntaxFormatting] $Instance = [SyntaxFormatting]::new()

    hidden [object] $_psrlOptions

    [string] $Reset

    [string] $StringEscape = "$([char]0x1b)[38;2;215;186;125m" #D7BA7D

    hidden SyntaxFormatting() {
        if ($global:PSStyle) {
            $this.Reset = $global:PSStyle.Reset
        } else {
            $this.Reset = "$([char]0x1b)[0m"
        }

        $bindingFlags = [BindingFlags]::Static -bor [BindingFlags]::Public
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Command', [SyntaxFormatting].GetMethod('GetCommand', $bindingFlags), [SyntaxFormatting].GetMethod('SetCommand', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Comment', [SyntaxFormatting].GetMethod('GetComment', $bindingFlags), [SyntaxFormatting].GetMethod('SetComment', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('ContinuationPrompt', [SyntaxFormatting].GetMethod('GetContinuationPrompt', $bindingFlags), [SyntaxFormatting].GetMethod('SetContinuationPrompt', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('DefaultToken', [SyntaxFormatting].GetMethod('GetDefaultToken', $bindingFlags), [SyntaxFormatting].GetMethod('SetDefaultToken', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Emphasis', [SyntaxFormatting].GetMethod('GetEmphasis', $bindingFlags), [SyntaxFormatting].GetMethod('SetEmphasis', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Error', [SyntaxFormatting].GetMethod('GetError', $bindingFlags), [SyntaxFormatting].GetMethod('SetError', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('InlinePrediction', [SyntaxFormatting].GetMethod('GetInlinePrediction', $bindingFlags), [SyntaxFormatting].GetMethod('SetInlinePrediction', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Keyword', [SyntaxFormatting].GetMethod('GetKeyword', $bindingFlags), [SyntaxFormatting].GetMethod('SetKeyword', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('ListPrediction', [SyntaxFormatting].GetMethod('GetListPrediction', $bindingFlags), [SyntaxFormatting].GetMethod('SetListPrediction', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('ListPredictionSelected', [SyntaxFormatting].GetMethod('GetListPredictionSelected', $bindingFlags), [SyntaxFormatting].GetMethod('SetListPredictionSelected', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Member', [SyntaxFormatting].GetMethod('GetMember', $bindingFlags), [SyntaxFormatting].GetMethod('SetMember', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Number', [SyntaxFormatting].GetMethod('GetNumber', $bindingFlags), [SyntaxFormatting].GetMethod('SetNumber', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Operator', [SyntaxFormatting].GetMethod('GetOperator', $bindingFlags), [SyntaxFormatting].GetMethod('SetOperator', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Parameter', [SyntaxFormatting].GetMethod('GetParameter', $bindingFlags), [SyntaxFormatting].GetMethod('SetParameter', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Selection', [SyntaxFormatting].GetMethod('GetSelection', $bindingFlags), [SyntaxFormatting].GetMethod('SetSelection', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('String', [SyntaxFormatting].GetMethod('GetString', $bindingFlags), [SyntaxFormatting].GetMethod('SetString', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Type', [SyntaxFormatting].GetMethod('GetType', $bindingFlags), [SyntaxFormatting].GetMethod('SetType', $bindingFlags)))
        $this.psobject.Properties.Add([System.Management.Automation.PSCodeProperty]::new('Variable', [SyntaxFormatting].GetMethod('GetVariable', $bindingFlags), [SyntaxFormatting].GetMethod('SetVariable', $bindingFlags)))

        $psrlType = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
        if ($psrlType) {
            $this._psrlOptions = $psrlType::GetOptions()
            return
        }

        $e = [char]0x1b
        $this._psrlOptions = [PSCustomObject]@{
            CommandColor = "${e}[93m"
            CommentColor = "${e}[32m"
            ContinuationPromptColor = "${e}[37m"
            DefaultTokenColor = "${e}[37m"
            EmphasisColor = "${e}[96m"
            ErrorColor = "${e}[91m"
            InlinePredictionColor = "${e}[38;5;238m"
            KeywordColor = "${e}[92m"
            ListPredictionColor = "${e}[33m"
            ListPredictionSelectedColor = "${e}[48;5;238m"
            MemberColor = "${e}[97m"
            NumberColor = "${e}[97m"
            OperatorColor = "${e}[90m"
            ParameterColor = "${e}[90m"
            SelectionColor = "${e}[30;47m"
            StringColor = "${e}[36m"
            TypeColor = "${e}[37m"
            VariableColor = "${e}[92m"
        }
    }

    static [SyntaxFormatting] GetSyntax([psobject] $instance) {
        return [SyntaxFormatting]::Instance
    }

    static [string] GetCommand([psobject] $instance) { return $instance._psrlOptions.CommandColor }
    static [void] SetCommand([psobject] $instance, [string] $value) { $instance._psrlOptions.CommandColor = $value }
    static [string] GetComment([psobject] $instance) { return $instance._psrlOptions.CommentColor }
    static [void] SetComment([psobject] $instance, [string] $value) { $instance._psrlOptions.CommentColor = $value }
    static [string] GetContinuationPrompt([psobject] $instance) { return $instance._psrlOptions.ContinuationPromptColor }
    static [void] SetContinuationPrompt([psobject] $instance, [string] $value) { $instance._psrlOptions.ContinuationPromptColor = $value }
    static [string] GetDefaultToken([psobject] $instance) { return $instance._psrlOptions.DefaultTokenColor }
    static [void] SetDefaultToken([psobject] $instance, [string] $value) { $instance._psrlOptions.DefaultTokenColor = $value }
    static [string] GetEmphasis([psobject] $instance) { return $instance._psrlOptions.EmphasisColor }
    static [void] SetEmphasis([psobject] $instance, [string] $value) { $instance._psrlOptions.EmphasisColor = $value }
    static [string] GetError([psobject] $instance) { return $instance._psrlOptions.ErrorColor }
    static [void] SetError([psobject] $instance, [string] $value) { $instance._psrlOptions.ErrorColor = $value }
    static [string] GetInlinePrediction([psobject] $instance) { return $instance._psrlOptions.InlinePredictionColor }
    static [void] SetInlinePrediction([psobject] $instance, [string] $value) { $instance._psrlOptions.InlinePredictionColor = $value }
    static [string] GetKeyword([psobject] $instance) { return $instance._psrlOptions.KeywordColor }
    static [void] SetKeyword([psobject] $instance, [string] $value) { $instance._psrlOptions.KeywordColor = $value }
    static [string] GetListPrediction([psobject] $instance) { return $instance._psrlOptions.ListPredictionColor }
    static [void] SetListPrediction([psobject] $instance, [string] $value) { $instance._psrlOptions.ListPredictionColor = $value }
    static [string] GetListPredictionSelected([psobject] $instance) { return $instance._psrlOptions.ListPredictionSelectedColor }
    static [void] SetListPredictionSelected([psobject] $instance, [string] $value) { $instance._psrlOptions.ListPredictionSelectedColor = $value }
    static [string] GetMember([psobject] $instance) { return $instance._psrlOptions.MemberColor }
    static [void] SetMember([psobject] $instance, [string] $value) { $instance._psrlOptions.MemberColor = $value }
    static [string] GetNumber([psobject] $instance) { return $instance._psrlOptions.NumberColor }
    static [void] SetNumber([psobject] $instance, [string] $value) { $instance._psrlOptions.NumberColor = $value }
    static [string] GetOperator([psobject] $instance) { return $instance._psrlOptions.OperatorColor }
    static [void] SetOperator([psobject] $instance, [string] $value) { $instance._psrlOptions.OperatorColor = $value }
    static [string] GetParameter([psobject] $instance) { return $instance._psrlOptions.ParameterColor }
    static [void] SetParameter([psobject] $instance, [string] $value) { $instance._psrlOptions.ParameterColor = $value }
    static [string] GetSelection([psobject] $instance) { return $instance._psrlOptions.SelectionColor }
    static [void] SetSelection([psobject] $instance, [string] $value) { $instance._psrlOptions.SelectionColor = $value }
    static [string] GetString([psobject] $instance) { return $instance._psrlOptions.StringColor }
    static [void] SetString([psobject] $instance, [string] $value) { $instance._psrlOptions.StringColor = $value }
    static [string] GetType([psobject] $instance) { return $instance._psrlOptions.TypeColor }
    static [void] SetType([psobject] $instance, [string] $value) { $instance._psrlOptions.TypeColor = $value }
    static [string] GetVariable([psobject] $instance) { return $instance._psrlOptions.VariableColor }
    static [void] SetVariable([psobject] $instance, [string] $value) { $instance._psrlOptions.VariableColor = $value }
}

$formatting = [SyntaxFormatting]::new()

if ($PSStyle) {
    $PSStyle.Formatting.psobject.Properties.Add(
        [System.Management.Automation.PSCodeProperty]::new(
            'Syntax',
            [SyntaxFormatting].GetMethod('GetSyntax', [BindingFlags]'Static, Public')))
}

class Formatter {
    [object] $PSStyle

    [bool] $NoColor

    hidden Formatter() {
        $this.PSStyle = $global:PSStyle
        $this.NoColor = $env:NO_COLOR
    }

    hidden [SignatureWriter] GetWriter() {
        return [SignatureWriter]@{ Simple = $true }
    }

    [string] Color([string] $ansi, [string] $value) {
        if ($this.NoColor -or ($this.PSStyle -and $this.PSStyle.OutputRendering.value__ -notin 0, 2)) {
            return $value
        }

        if ([string]::IsNullOrEmpty($value)) {
            return [string]::Empty
        }

        return [string]::Concat(
            $ansi,
            $value,
            [SyntaxFormatting]::Instance.Reset)
    }

    [string] Number([object] $value) {
        if ($null -eq $value) {
            return $this.Color([SyntaxFormatting]::Instance.Number, '0')
        }

        return $this.Color([SyntaxFormatting]::Instance.Number, $value)
    }

    [string] String([string] $value) {
        return $this.Color([SyntaxFormatting]::Instance.String, $value)
    }

    [string] TypeInfo([Type] $value) {
        return $this.GetWriter().TypeInfo($value).ToString()
    }

    [string] TypeInfo([ParameterInfo] $value) {
        return $this.GetWriter().TypeInfo($value).ToString()
    }

    [string] DefaultValue([ParameterInfo] $value) {
        return $this.GetWriter().DefaultValue($value).ToString()
    }

    [string] TypeInfo([string] $value) {
        return $this.Color([SyntaxFormatting]::Instance.Type, $value)
    }

    [string] Keyword([string] $value) {
        return $this.Color([SyntaxFormatting]::Instance.Keyword, $value)
    }

    [string] MemberName([string] $value) {
        return $this.Color([SyntaxFormatting]::Instance.Member, $value)
    }

    [string] Variable([string] $value) {
        return $this.Color([SyntaxFormatting]::Instance.Variable, $value)
    }

    [string] Operator([string] $value) {
        return $this.Color([SyntaxFormatting]::Instance.Operator, $value)
    }
}

$global:PSSyntax = [Formatter]::new()

class TypedArgument {
    [type] $Type

    [object] $Value

    TypedArgument([type] $type, [object] $value) {
        $this.Type = $type
        $this.Value = $value
    }

    static [TypedArgument] op_Implicit([CustomAttributeTypedArgument] $value) {
        return [TypedArgument]::new($value.ArgumentType, $value.Value)
    }

    static [TypedArgument] op_Implicit([CustomAttributeNamedArgument] $value) {
        return [NamedArgument]::new(
            $value.TypedValue.ArgumentType,
            $value.TypedValue.Value,
            $value.MemberName)
    }
}

class NamedArgument : TypedArgument {
    [string] $Name

    NamedArgument([type] $type, [object] $value, [string] $name)
        : base($type, $value)
    {
        $this.Name = $name
    }
}

class TypedArgumentList {
    [List[TypedArgument]] $CtorArgs

    [List[NamedArgument]] $NamedArgs

    TypedArgumentList() {
        $this.CtorArgs = [List[TypedArgument]]::new()
        $this.NamedArgs = [List[NamedArgument]]::new()
    }

    TypedArgumentList([TypedArgument[]] $ctorArgs, [NamedArgument[]] $namedArgs) {
        $this.CtorArgs = $ctorArgs
        $this.NamedArgs = $namedArgs
    }

    TypedArgumentList([List[TypedArgument]] $ctorArgs, [List[NamedArgument]] $namedArgs) {
        $this.CtorArgs = $ctorArgs
        $this.NamedArgs = $namedArgs
    }

    [TypedArgumentList] AddCtorArg([type] $type, [object] $value) {
        $this.CtorArgs.Add([TypedArgument]::new($type, $value))
        return $this
    }

    [TypedArgumentList] AddNamedArg([string] $name, [type] $type, [object] $value) {
        $this.NamedArgs.Add([NamedArgument]::new($type, $value, $name))
        return $this
    }

    static [TypedArgumentList] op_Implicit([object[]] $values) {
        $namedArgList = [List[NamedArgument]]::new()
        $ctorArgList = [List[TypedArgument]]::new()
        foreach ($value in $values) {
            if ($value['Name']) {
                $namedArgList.Add([NamedArgument]::new($value['Type'], $value['Value'], $value['Name']))
                continue
            }

            $ctorArgList.Add([TypedArgument]::new($value['Type'], $value['Value']))
        }

        return [TypedArgumentList]::new($ctorArgList.ToArray(), $namedArgList.ToArray())
    }

    static [TypedArgumentList] Create(
        [IList[CustomAttributeTypedArgument]] $ctorArgs,
        [IList[CustomAttributeNamedArgument]] $namedArgs)
    {
        $newCtorArgs = [TypedArgument[]]::new($ctorArgs.Count)
        $newNamedArgs = [NamedArgument[]]::new($namedArgs.Count)
        for ($i = 0; $i -lt $newCtorArgs.Length; $i++) {
            $old = $ctorArgs[$i]
            $newCtorArgs[$i] = [TypedArgument]::new(
                $old.ArgumentType,
                [TypedArgumentList]::ConvertValue($old.Value))
        }

        for ($i = 0; $i -lt $newNamedArgs.Length; $i++) {
            $old = $namedArgs[$i]
            $newNamedArgs[$i] = [NamedArgument]::new(
                $old.TypedValue.ArgumentType,
                [TypedArgumentList]::ConvertValue($old.TypedValue.Value),
                $old.MemberName)
        }

        return [TypedArgumentList]::new($newCtorArgs, $newNamedArgs)
    }

    hidden static [object] ConvertValue([object] $source) {
        if ($null -eq $source) {
            return $null
        }

        if ($source -isnot [System.Collections.IList]) {
            return $source
        }

        $results = foreach ($item in $source) {
            if ($item -isnot [CustomAttributeTypedArgument]) {
                $item
                continue
            }

            [TypedArgument]::new($item.ArgumentType, $item.Value)
        }

        return $results
    }
}

[Flags()]
enum MemberView {
    Public = 0x1 # 0b0001;
    Family = 0x2 # 0b0010;
    Assembly = 0x4 # 0b0100;
    Private = 0x8 # 0b1000;

    External = 0x1 # 0b0001;

    Internal = 0x5 # 0b0101;

    Child = 0x3 # 0b0011;

    All = 0xF # 0b1111;
}

class SignatureWriter {
    hidden static [string] $RefStructObsoleteMessage =
        'Types with embedded references are not supported in this version of your compiler.'

    hidden static [string] $IsReadOnlyAttribute = 'System.Runtime.CompilerServices.IsReadOnlyAttribute'

    hidden static [string] $IsByRefLikeAttribute = 'System.Runtime.CompilerServices.IsByRefLikeAttribute'

    hidden static [string] $IsVolatile = 'System.Runtime.CompilerServices.IsVolatile'

    hidden static [string] $IsUnmanagedAttribute = 'System.Runtime.CompilerServices.IsUnmanagedAttribute'

    hidden static [string] $IsExternalInit = 'System.Runtime.CompilerServices.IsExternalInit'

    hidden static [SyntaxFormatting] $Formatting

    [int] $Indent

    [int] $IndentSize = 4

    [bool] $Recurse

    [bool] $Force

    [bool] $IncludeSpecial

    [bool] $Simple

    [type] $TargetType

    [MemberView] $View

    hidden [StringBuilder] $sb;

    SignatureWriter() {
        $this.sb = [StringBuilder]::new()
    }

    [void] Clear() {
        $this.sb.Clear()
    }

    [string] ToString() {
        return $this.sb.ToString()
    }

    [SignatureWriter] AccessModifiers([MemberInfo] $member) {
        if (-not ($member -is [FieldInfo] -or $member -is [MethodBase])) {
            throw [System.ArgumentException]::new(
                'Must be of type FieldInfo or MethodBase.',
                'method')
        }

        if ($member.IsPublic) {
            return $this.Keyword('public').Space()
        }

        if ($member.IsPrivate) {
            return $this.Keyword('private').Space()
        }

        if ($member.IsAssembly) {
            return $this.Keyword('internal').Space()
        }

        if ($member.IsFamily) {
            return $this.Keyword('protected').Space()
        }

        if ($member.IsFamilyAndAssembly) {
            return $this.Keyword('private protected').Space()
        }

        if ($member.IsFamilyOrAssembly) {
            return $this.Keyword('internal protected').Space()
        }

        throw
    }

    [SignatureWriter] AccessModifiers([type] $type) {
        if ($type.IsPublic) {
            return $this.Keyword('public').Space()
        }

        if (-not $type.IsNested) {
            return $this.Keyword('internal').Space()
        }

        if ($type.IsNestedAssembly) {
            return $this.Keyword('internal').Space()
        }

        if ($type.IsNestedFamily) {
            return $this.Keyword('protected').Space()
        }

        if ($type.IsNestedPrivate) {
            return $this.Keyword('private').Space()
        }

        if ($type.IsNestedFamANDAssem) {
            return $this.Keyword('private protected').Space()
        }

        if ($type.IsNestedFamORAssem) {
            return $this.Keyword('internal protected').Space()
        }

        if ($type.IsNestedPublic) {
            return $this.Keyword('public').Space()
        }

        throw
    }

    [SignatureWriter] Attributes([MethodBase] $method) {
        foreach ($attribute in $method.CustomAttributes) {
            if ($attribute.AttributeType -eq [DllImportAttribute]) {
                $this.DllImportAttribute($attribute, $method.Name).NewLine()
                continue
            }

            if ($attribute.AttributeType -eq [PreserveSigAttribute] -and -not $method.ReflectedType.IsInterface) {
                continue
            }

            $this.Attribute($attribute).NewLine()
        }

        if ($method -is [ConstructorInfo]) {
            return $this
        }

        foreach ($attribute in $method.ReturnParameter.CustomAttributes) {
            if ($attribute.AttributeType -eq [MarshalAsAttribute]) {
                $this.MarshalAsAttribute($attribute, <# isReturn: #> $true).NewLine()
                continue
            }

            if ($attribute.AttributeType.FullName -eq $this::IsReadOnlyAttribute) {
                continue
            }

            $this.Attribute($attribute, <# isReturn: #> $true).NewLine()
        }

        return $this
    }

    hidden [SignatureWriter] DllImportAttribute([CustomAttributeData] $attribute, [string] $methodName) {
        $defaultValues = @{
            EntryPoint = $methodName
            CharSet = 1
            ExactSpelling = $false
            SetLastError = $false
            PreserveSig = $true
            CallingConvention = 1
            BestFitMapping = $false
            ThrowOnUnmappableChar = $false
        }

        return $this.AttributeIgnoreDefault($attribute, $defaultValues, <# isReturn: #> $false)
    }

    hidden [SignatureWriter] MarshalAsAttribute([CustomAttributeData] $attribute, [bool] $isReturn) {
        $defaultValues = @{
            ArraySubType = 0
            SizeParamIndex = 0s
            SizeConst = 0
            IidParameterIndex = 0
            SafeArraySubType = 0
        }

        return $this.AttributeIgnoreDefault($attribute, $defaultValues, $isReturn)
    }

    hidden [SignatureWriter] AttributeIgnoreDefault(
        [CustomAttributeData] $attribute,
        [hashtable] $defaultValues,
        [bool] $isReturn)
    {
        $argList = [TypedArgumentList]::new()
        foreach ($ctorArg in $attribute.ConstructorArguments) {
            $argList.AddCtorArg($ctorArg.ArgumentType, $argList::ConvertValue($ctorArg.Value))
        }

        foreach ($namedArgument in $attribute.NamedArguments) {
            $skip = $defaultValues.ContainsKey($namedArgument.MemberName) -and
                $defaultValues[$namedArgument.MemberName] -eq $namedArgument.TypedValue.Value

            if ($skip) {
                continue
            }

            $argList.AddNamedArg(
                $namedArgument.MemberName,
                $namedArgument.TypedValue.ArgumentType,
                $argList::ConvertValue($namedArgument.TypedValue.Value))
        }

        return $this.Attribute($attribute.AttributeType, $argList, $isReturn)
    }


    [SignatureWriter] Attribute([CustomAttributeData] $attribute) {
        return $this.Attribute($attribute, <# isReturn: #> $false)
    }

    [SignatureWriter] Attribute([type] $type, [TypedArgumentList] $arguments) {
        return $this.Attribute($type, $arguments, <# isReturn: #> $false)
    }

    [SignatureWriter] Attribute([type] $type, [TypedArgumentList] $arguments, [bool] $isReturn) {
        $this.OpenSquare()
        if ($isReturn) {
            $this.Keyword('return').Colon().Space()
        }

        $this.TypeInfo($type, <# isForAttribute: #> $true)
        $hasCtorArgs = $arguments.CtorArgs.Count -gt 0
        $hasNamedArgs = $arguments.NamedArgs.Count -gt 0

        if (-not ($hasCtorArgs -or $hasNamedArgs)) {
            return $this.CloseSquare()
        }

        $this.OpenParen()

        if ($hasCtorArgs) {
            $this.AttributeArgument($arguments.CtorArgs[0])

            for ($i = 1; $i -lt $arguments.CtorArgs.Count; $i++) {
                $this.
                    Comma().Space().
                    AttributeArgument($arguments.CtorArgs[$i])
            }
        }

        if ($hasNamedArgs) {
            if ($hasCtorArgs) {
                $this.Comma().Space()
            }

            $this.AttributeArgument($arguments.NamedArgs[0])

            for ($i = 1; $i -lt $arguments.NamedArgs.Count; $i++) {
                $this.Comma().Space().
                    AttributeArgument($arguments.NamedArgs[$i])
            }
        }

        return $this.CloseParen().CloseSquare()
    }

    [SignatureWriter] Attribute([StructLayoutAttribute] $layout) {
        $arguments = [TypedArgumentList]::new()
        $arguments.AddCtorArg([LayoutKind], $layout.Value)

        if ($layout.Pack -ne 8) {
            $arguments.AddNamedArg('Pack', [int], $layout.Pack)
        }

        if ($layout.Size -ne 0) {
            $arguments.AddNamedArg('Size', [int], $layout.Size)
        }

        if ($layout.CharSet -ne [CharSet]::Ansi) {
            $arguments.AddNamedArg('CharSet', [CharSet], $layout.CharSet)
        }

        return $this.Attribute([StructLayoutAttribute], $arguments)
    }

    [SignatureWriter] Attribute([CustomAttributeData] $attribute, [bool] $isReturn) {
        return $this.Attribute(
            $attribute.AttributeType,
            [TypedArgumentList]::Create($attribute.ConstructorArguments, $attribute.NamedArguments),
            $isReturn)
    }

    [SignatureWriter] AttributeArgument([NamedArgument] $argument) {
        return $this.AttributeArgument($argument.Name, $argument.Type, $argument.Value)
    }

    [SignatureWriter] AttributeArgument([TypedArgument] $argument) {
        return $this.AttributeArgument($argument.Type, $argument.Value)
    }

    [SignatureWriter] AttributeArgument([string] $name, [type] $type, [object] $value) {
        return $this.MemberName($name).Space().Equal().Space().AttributeArgument($type, $value)
    }

    [SignatureWriter] AttributeArgument([type] $type, [object] $value) {
        if ($type.IsEnum) {
            $rawValue = $value
            if ($rawValue -is [enum]) {
                $rawValue = $rawValue.value__
            }

            foreach ($name in [enum]::GetNames($type)) {
                if ($type::$name.value__ -eq $rawValue) {
                    return $this.TypeInfo($type).Append('.').MemberName($name)
                }
            }

            $default = $type::new()
            $default.value__ = $rawValue
            $parts = $default.ToString() -split ', '
            if ($parts.Length -eq 1 -and $parts[0] -match '^\d+$') {
                return $this.
                    OpenParen().
                    TypeInfo($type).
                    CloseParen().
                    Append($rawValue)
            }

            $this.TypeInfo($type).Append('.').MemberName($parts[0])
            for ($i = 1; $i -lt $parts.Length; $i++) {
                $this.Append(' | ').TypeInfo($type).Dot().MemberName($parts[$i])
            }

            return $this
        }

        if ($type.IsArray) {
            $this.Keyword('new').OpenSquare().CloseSquare().Space().OpenCurly().Space()
            $this.AttributeArgument($value[0])
            for ($i = 1; $i -lt $value.Length; $i++) {
                $this.Comma().Space().AttributeArgument($value[$i])
            }

            return $this.Space().CloseCurly()
        }

        if ($type -eq [string]) {
            return $this.StringLiteral(
                $value,
                <# isForChar: #> $false,
                <# includeQuotes: #> $true)
        }

        if ($type -eq [char]) {
            return $this.StringLiteral(
                $value,
                <# isForChar: #> $true,
                <# includeQuotes: #> $true)
        }

        if ($type -eq [type]) {
            return $this.Keyword('typeof').OpenParen().TypeInfo($value).CloseParen()
        }

        if ($type -eq [int]) {
            return $this.Number($value)
        }

        if ($type -eq [uint32]) {
            return $this.Number($value).Number('u')
        }

        if ($type -eq [int64]) {
            return $this.Number($value).Number('L')
        }

        if ($type -eq [uint64]) {
            return $this.Number($value).Number('uL')
        }

        if ($type -eq [single]) {
            return $this.Number($value).Number('f')
        }

        if ($type -eq [decimal]) {
            return $this.Number($value).Number('m')
        }

        if ($type -eq [double]) {
            return $this.Number($value).Number('d')
        }

        if ($type -eq [bool]) {
            if ($value -eq $true) {
                return $this.Keyword('true')
            }

            return $this.Keyword('false')
        }

        if ($type.IsPrimitive) {
            return $this.Number($value)
        }

        throw [System.BadImageFormatException]::new(
            ('Unexpected custom attribute argument type "{0}". Value: {1}' -f (
                $type.FullName,
                $value)))
    }

    [SignatureWriter] Modifiers([MethodBase] $method) {
        if (-not ($method -is [ConstructorInfo] -and $method.IsStatic)) {
            $this.AccessModifiers($method)
        }

        if ($method.IsStatic) {
            $this.Keyword('static').Space()
        }

        if (-not $method.IsVirtual) {
            return $this
        }

        if ($method.IsAbstract)
        {
            return $this.Keyword("abstract").Space()
        }

        if ($method.Attributes -band [System.Reflection.MethodAttributes]::NewSlot) {
            return $this.Keyword("virtual").Space()
        }

        $this.Keyword("override").Space()

        if ($method.Attributes -band [System.Reflection.MethodAttributes]::Final) {
            return $this.Keyword('sealed').Space()
        }

        return $this
    }

    [SignatureWriter] RefModifier([ParameterInfo] $parameter) {
        $testIsReadOnlyAttribute = {
            $_.AttributeType.FullName -eq $this::IsReadOnlyAttribute
        }

        if ($parameter.Position -eq -1) {
            if (-not $parameter.ParameterType.IsByRef) {
                return $this
            }

            $this.Keyword('ref').Space()

            if ($parameter.CustomAttributes.Where($testIsReadOnlyAttribute, 'First')) {
                return $this.Keyword('readonly').Space()
            }

            return $this
        }

        if ($parameter.IsOut -and $parameter.ParameterType.IsByRef -and -not $parameter.IsIn) {
            return $this.Keyword('out').Space()
        }

        if ($parameter.CustomAttributes.Where($testIsReadOnlyAttribute, 'First')) {
            return $this.Keyword('in').Space()
        }

        if ($parameter.ParameterType.IsByRef) {
            return $this.Keyword('ref').Space()
        }

        return $this
    }

    [SignatureWriter] TypeInfo([ParameterInfo] $parameter) {
        $this.RefModifier($parameter)
        $parameterType = $parameter.ParameterType
        if ($parameterType.IsByRef) {
            $parameterType = $parameterType.GetElementType()
        }

        return $this.TypeInfo($parameterType)
    }

    [SignatureWriter] TypeInfo([type] $type) {
        return $this.TypeInfo(
            $type,
            <# isForAttribute: #> $false,
            <# isForDefinition: #> $false)
    }

    [SignatureWriter] TypeInfo([type] $type, [bool] $isForAttribute) {
        return $this.TypeInfo(
            $type,
            $isForAttribute,
            <# isForDefinition: #> $false)
    }

    [SignatureWriter] TypeInfo([type] $type, [bool] $isForAttribute, [bool] $isForDefinition) {
        if ($isForDefinition -and $type.IsGenericParameter -and -not $this.Simple) {
            foreach ($attribute in $type.CustomAttributes) {
                $this.Attribute($attribute).Space()
            }
        }

        if ($type.Name -eq 'Nullable`1') {
            $this.TypeInfo($type.GetGenericArguments()[0])
            return $this.Question()
        }

        if ($type.IsArray) {
            $this.TypeInfo($type.GetElementType())
            if ($type.IsSZArray) {
                return $this.OpenSquare().CloseSquare()
            }

            $rank = $type.GetArrayRank()
            $this.OpenSquare()
            $this.sb.Append([char]',', $rank - 1)
            $this.CloseSquare()
            return $this
        }

        if ($type.IsPointer) {
            $this.TypeInfo($type.GetElementType())
            $this.Append('*')
            return $this
        }

        $wellKnownType = $this.GetWellKnownTypeName($type)
        if ($wellKnownType) {
            return $this.Keyword($wellKnownType)
        }

        if ($type.IsNested -and -not $type.IsGenericParameter) {
            $this.TypeInfo($type.ReflectedType).Dot()
        }

        if (-not $type.IsGenericType) {
            if ($isForAttribute) {
                return $this.TypeInfo($type.Name -replace 'Attribute$')
            }

            return $this.TypeInfo($type.Name)
        }

        $this.TypeInfo($this.RemoveArity($type.Name)).OpenGeneric()
        $genericArgs = $type.GetGenericArguments()

        $this.TypeInfo($genericArgs[0], <# isForAttribute: #> $false, $isForDefinition)
        for ($i = 1; $i -lt $genericArgs.Length; $i++) {
            $this.Comma().Space().
                TypeInfo($genericArgs[$i], <# isForAttribute: #> $false, $isForDefinition)
        }

        return $this.CloseGeneric()
    }

    [string] GetWellKnownTypeName([type] $type) {
        if ($global:_profiler) {
            $result = switch ($type) {
                ([void]) { 'void' }
                ([string]) { 'string' }
                ([char]) { 'char' }
                ([int]) { 'int' }
                ([uint32]) { 'uint' }
                ([int16]) { 'short' }
                ([uint16]) { 'ushort' }
                ([long]) { 'long' }
                ([uint64]) { 'ulong' }
                ([sbyte]) { 'sbyte' }
                ([byte]) { 'byte' }
                ([double]) { 'double' }
                ([float]) { 'float' }
                ([IntPtr]) { 'nint' }
                ([UIntPtr]) { 'nuint' }
                ([object]) { 'object' }
                ([bool]) { 'bool' }
                ([decimal]) { 'decimal' }
                default { $null }
            }

            return $result
        }

        if ($type.Equals([void])) { return 'void' }
        if ($type.Equals([string])) { return 'string' }
        if ($type.Equals([char])) { return 'char' }
        if ($type.Equals([int])) { return 'int' }
        if ($type.Equals([uint32])) { return 'uint' }
        if ($type.Equals([int16])) { return 'short' }
        if ($type.Equals([uint16])) { return 'ushort' }
        if ($type.Equals([long])) { return 'long' }
        if ($type.Equals([uint64])) { return 'ulong' }
        if ($type.Equals([sbyte])) { return 'sbyte' }
        if ($type.Equals([byte])) { return 'byte' }
        if ($type.Equals([double])) { return 'double' }
        if ($type.Equals([float])) { return 'float' }
        if ($type.Equals([IntPtr])) { return 'nint' }
        if ($type.Equals([UIntPtr])) { return 'nuint' }
        if ($type.Equals([object])) { return 'object' }
        if ($type.Equals([bool])) { return 'bool' }
        if ($type.Equals([decimal])) { return 'decimal' }
        return $null
    }

    [SignatureWriter] TypeInfo([string] $name) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.Type, $name)
    }

    [SignatureWriter] Keyword([string] $value) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.Keyword, $value)
    }

    [SignatureWriter] Operator([string] $value) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.Operator, $value)
    }

    [SignatureWriter] String([string] $value) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.String, $value)
    }

    [SignatureWriter] Number([string] $value) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.Number, $value)
    }

    [SignatureWriter] MemberName([string] $value) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.Member, $value)
    }

    [SignatureWriter] Variable([string] $value) {
        return $this.AppendWithColor([SignatureWriter]::Formatting.Variable, $value)
    }

    [SignatureWriter] AppendWithColor([string] $ansi, [string] $value) {
        $this.sb.Append($ansi).Append($value).Append($global:PSStyle.Reset)
        return $this
    }

    [SignatureWriter] Space() { return $this.Append(' ') }

    [SignatureWriter] Equal() { return $this.Operator('=') }

    [SignatureWriter] Semi() { return $this.Operator(';') }

    [SignatureWriter] Dot() { return $this.Operator('.') }

    [SignatureWriter] OpenSquare() { return $this.Operator('[') }

    [SignatureWriter] Question() { return $this.Operator('?') }

    [SignatureWriter] CloseSquare() { return $this.Operator(']') }

    [SignatureWriter] OpenGeneric() { return $this.Operator('<') }

    [SignatureWriter] CloseGeneric() { return $this.Operator('>') }

    [SignatureWriter] OpenCurly() { return $this.Operator('{') }

    [SignatureWriter] CloseCurly() { return $this.Operator('}') }

    [SignatureWriter] OpenParen() { return $this.Operator('(') }

    [SignatureWriter] CloseParen() { return $this.Operator(')') }

    [SignatureWriter] Comma() { return $this.Operator(',') }

    [SignatureWriter] Colon() { return $this.Operator(':') }

    [SignatureWriter] Append([string] $value) {
        $this.sb.Append($value)
        return $this
    }

    [SignatureWriter] NewLine() {
        $this.sb.AppendLine()
        return $this.AppendIndent()
    }

    [SignatureWriter] NewLineNoIndent() {
        $this.sb.AppendLine()
        return $this
    }

    [SignatureWriter] PushIndent() {
        $this.Indent += 1
        return $this
    }

    [SignatureWriter] PopIndent() {
        $this.Indent = [Math]::Max($this.Indent - 1, 0)
        return $this
    }

    [SignatureWriter] AppendIndent() {
        if ($this.Indent -le 0) {
            return $this
        }

        $this.sb.Append(' '[0], $this.Indent * $this.IndentSize)
        return $this
    }

    [SignatureWriter] CompleteType([type] $type) {
        if (-not $this.Recurse) {
            return $this.Semi();
        }

        $this.NewLine().OpenCurly().PushIndent()

        $staticPublic = [BindingFlags]::Public -bor [BindingFlags]::Static
        $instancePublic = [BindingFlags]::Public -bor [BindingFlags]::Instance
        $staticNonPublic = [BindingFlags]::NonPublic -bor [BindingFlags]::Static
        $instanceNonPublic = [BindingFlags]::NonPublic -bor [BindingFlags]::Instance

        $allModifiers = $staticPublic, $instancePublic, $staticNonPublic, $instanceNonPublic

        $first = [ref]$true
        foreach ($modifier in $allModifiers) {
            foreach ($field in $type.GetFields($modifier)) {
                if (-not $this.ShouldProcess($field)) { continue }
                $this.MaybeNewLine($first).Member($field)
            }
        }

        foreach ($modifier in $allModifiers) {
            foreach ($ctor in $type.GetConstructors($modifier)) {
                if (-not $this.ShouldProcess($ctor)) { continue }
                $this.MaybeNewLine($first).Member($ctor)
            }
        }

        foreach ($modifier in $allModifiers) {
            foreach ($property in $type.GetProperties($modifier)) {
                if (-not $this.ShouldProcess($property)) { continue }
                $this.MaybeNewLine($first).Member($property)
            }
        }

        foreach ($modifier in $allModifiers) {
            foreach ($e in $type.GetEvents($modifier)) {
                if (-not $this.ShouldProcess($e)) { continue }
                $this.MaybeNewLine($first).Member($e)
            }
        }

        foreach ($modifier in $allModifiers) {
            foreach ($method in $type.GetMethods($modifier)) {
                if (-not $this.ShouldProcess($method)) { continue }
                $this.MaybeNewLine($first).Member($method)
            }
        }

        foreach ($modifier in $allModifiers) {
            foreach ($nestedType in $type.GetNestedTypes($modifier)) {
                if (-not $this.ShouldProcess($nestedType)) { continue }
                $this.MaybeNewLine($first).Member($nestedType)
            }
        }

        return $this.PopIndent().NewLine().CloseCurly()
    }

    hidden [bool] ShouldProcess([MemberInfo] $member) {
        if (-not $this.IncludeSpecial -and $member -is [MethodInfo] -and $member.Attributes -band [System.Reflection.MethodAttributes]::SpecialName) {
            return $false
        }

        if (-not $this.DoesMatchView($member)) {
            return $false
        }

        if ($this.IncludeSpecial) {
            return $true
        }

        return -not $member.IsDefined(
            [Runtime.CompilerServices.CompilerGeneratedAttribute],
            <# inherit: #> $true)
    }

    hidden [bool] DoesMatchView([PropertyInfo] $property) {
        $getMethod = $property.GetGetMethod($true)
        if ($getMethod) {
            return $this.DoesMatchViewImpl($getMethod)
        }

        return $this.DoesMatchViewImpl($property.GetSetMethod($true))
    }

    hidden [bool] DoesMatchView([FieldInfo] $field) { return $this.DoesMatchViewImpl($field) }

    hidden [bool] DoesMatchView([MethodBase] $method) { return $this.DoesMatchViewImpl($method) }

    hidden [bool] DoesMatchView([type] $type) {
        if ($type.IsPublic -or $type.IsNestedPublic) {
            return $true
        }

        if ($this.View -eq [MemberView]::All) {
            return $true
        }

        if ($type.IsNestedPrivate) {
            return $false
        }

        if ($type.IsNestedAssembly) {
            return $this.View -band [MemberView]::Assembly
        }

        if ($type.IsNestedFamily) {
            return $this.View -band [MemberView]::Family
        }

        if ($type.IsNestedFamANDAssem) {
            return $this.View -band [MemberView]::Family -and $this.View -band [MemberView]::Assembly
        }

        if ($type.IsNestedFamORAssem) {
            return $this.View -band [MemberView]::Family -or $this.View -band [MemberView]::Assembly
        }

        throw
    }

    hidden [bool] DoesMatchView([EventInfo] $event) {
        $addMethod = $event.GetAddMethod($true)
        if ($addMethod) {
            return $this.DoesMatchViewImpl($addMethod)
        }

        return $this.DoesMatchViewImpl($event.GetAddMethod($true))
    }

    hidden [bool] DoesMatchViewImpl([MemberInfo] $member) {
        if (-not ($member -is [MethodBase] -or $member -is [FieldInfo])) {
            throw 'Unexpected type'
        }

        if ($member.IsPublic) {
            return $true
        }

        if ($this.View -eq [MemberView]::All) {
            return $true
        }

        if ($member.IsPrivate) {
            return $false
        }

        if ($member.IsAssembly) {
            return $this.View -band [MemberView]::Assembly
        }

        if ($member.IsFamily) {
            return $this.View -band [MemberView]::Family
        }

        if ($member.IsFamilyAndAssembly) {
            return $this.View -band [MemberView]::Family -and $this.View -band [MemberView]::Assembly
        }

        if ($member.IsFamilyOrAssembly) {
            return $this.View -band [MemberView]::Family -or $this.View -band [MemberView]::Assembly
        }

        throw
    }

    [SignatureWriter] MaybeNewLine([ref] $isFirst) {
        if ($isFirst.Value) {
            $isFirst.Value = $false
            return $this.NewLine()
        }

        return $this.NewLineNoIndent().NewLine()
    }

    [SignatureWriter] Member([type] $type) {
        if ($type.IsConstructedGenericType) {
            $type = $type.GetGenericTypeDefinition()
        }

        $isByRefLike = $false
        $isReadOnly = $false
        if (-not $this.Simple) {
            foreach ($attribute in $type.CustomAttributes) {
                if ($attribute.AttributeType.FullName -eq $this::IsByRefLikeAttribute) {
                    $isByRefLike = $true
                    continue
                }

                if ($attribute.AttributeType.FullName -eq $this::IsReadOnlyAttribute) {
                    $isReadOnly = $true
                    continue
                }

                $isRefStructObsoleteMessage = $attribute.AttributeType -eq [System.ObsoleteAttribute] -and
                    $attribute.ConstructorArguments[0].Value -eq $this::RefStructObsoleteMessage

                if ($isRefStructObsoleteMessage) {
                    continue
                }

                $this.Attribute($attribute).NewLine()
            }
        }

        $isEnum = $type.BaseType -eq [enum]
        $isStruct = $type.BaseType -eq [ValueType]
        $isDelegate = [System.Delegate].IsAssignableFrom($type)

        $layout = $type.StructLayoutAttribute
        $defaultLayout = [LayoutKind]::Auto
        if ($isStruct) {
            $defaultLayout = [LayoutKind]::Sequential
        }

        $isLayoutDefault = $layout.Value -eq $defaultLayout -and
            $layout.CharSet -eq [CharSet]::Ansi -and
            $layout.Pack -eq 8 -and
            $layout.Size -eq 0

        if (-not $isLayoutDefault -and -not $this.Simple) {
            $this.Attribute($layout).NewLine()
        }

        $this.AccessModifiers($type)

        if ($isDelegate) {
            return $this.Keyword('delegate').Space().
                Member(
                    $type.GetMethod('Invoke'),
                    $this.RemoveArity($type.Name),
                    <# skipToReturnType: #> $true)
        }

        if ($isEnum) {
            $this.Keyword('enum').Space().TypeInfo($type)

            if ($type.GetEnumUnderlyingType() -ne [int]) {
                $this.Space().Colon().Space().
                    TypeInfo($type.GetEnumUnderlyingType())
            }

            return $this.CompleteType($type)
        }

        if ($type.IsAbstract -and $type.IsSealed) {
            $this.Keyword('static').Space()
        }

        if ($isStruct) {
            if ($isReadOnly) {
                $this.Keyword('readonly').Space()
            }

            if ($isByRefLike) {
                $this.Keyword('ref').Space()
            }

            $this.Keyword('struct').Space()
        } else {
            $this.Keyword('class').Space()
        }

        $this.TypeInfo(
            $type,
            <# isForAttribute: #> $false,
            <# isForDefinition: #> $true)

        $hasBaseType = -not $isStruct -and $type.BaseType -ne [object]
        $implementedInterfaces = $this.GetImplementedInterfaces($type)

        if (-not ($hasBaseType -or $implementedInterfaces)) {
            return $this.GenericConstraints($type.GetGenericArguments()).CompleteType($type)
        }

        $this.Space().Colon().Space()
        if ($hasBaseType) {
            $this.TypeInfo($type.BaseType)
        }

        if (-not $implementedInterfaces) {
            return $this.GenericConstraints($type.GetGenericArguments()).CompleteType($type)
        }

        if ($hasBaseType) {
            $this.Comma().Space()
        }

        $this.TypeInfo($implementedInterfaces[0])
        for ($i = 1; $i -lt $implementedInterfaces.Length; $i++) {
            $this.Comma().Space().TypeInfo($implementedInterfaces[$i])
        }

        return $this.GenericConstraints($type.GetGenericArguments()).CompleteType($type)
    }

    [type[]] GetImplementedInterfaces([type] $type) {
        $workingSet = [HashSet[type]]$type.GetInterfaces()

        for ($base = $type.BaseType; $base -ne $null; $base = $base.BaseType) {
            $interfaces = $base.GetInterfaces()
            foreach ($interface in $interfaces) {
                if (-not $workingSet.Contains($interface)) {
                    continue
                }

                $workingSet.Remove($interface)
            }
        }

        $result = [type[]]::new($workingSet.Count)
        $workingSet.CopyTo($result)
        return $result
    }

    [SignatureWriter] Member([FieldInfo] $field) {
        if (-not $this.Simple) {
            foreach ($attribute in $field.CustomAttributes) {
                $this.Attribute($attribute).NewLine()
            }
        }

        $this.AccessModifiers($field)

        $isConst = $field.Attributes -band [FieldAttributes]::Literal
        if ($field.IsStatic -and -not $isConst) {
            $this.Keyword('static').Space()
        }

        $hasVolatileMod = $field.GetRequiredCustomModifiers().FullName -contains $this::IsVolatile

        if ($hasVolatileMod) {
            $this.Keyword('volatile').Space()
        }

        if ($isConst) {
            $this.Keyword('const').Space()
        } elseif ($field.Attributes -band [FieldAttributes]::InitOnly) {
            $this.Keyword('readonly').Space()
        }

        $this.TypeInfo($field.FieldType).Space().MemberName($field.Name)

        if ($isConst) {
            $constType = $field.FieldType
            $constValue = $field.GetRawConstantValue()
            if ($field.DeclaringType.IsEnum) {
                $constType = $constType.GetEnumUnderlyingType()
            }

            return $this.Space().Equal().Space().
                AttributeArgument([TypedArgument]::new($constType, $constValue)).
                Semi()
        }

        return $this.Semi()
    }

    [SignatureWriter] Member([MethodBase] $method) {
        return $this.Member(
            $method,
            <# overrideMethodName: #> $null,
            <# skipToReturnType: #> $false)
    }

    [SignatureWriter] Member([MethodBase] $method, [string] $overrideMethodName, [bool] $skipToReturnType) {
        if ($method.IsConstructedGenericMethod) {
            $method = $method.GetGenericMethodDefinition()
        }

        $isCtor = $method -is [ConstructorInfo]
        $interfaceType = $null
        $methodName = $null
        $isExplicitImplementation = $this.IsExplicitImplementation(
            $method,
            [ref] $interfaceType,
            [ref] $methodName)

        if (-not ($skipToReturnType -or $isExplicitImplementation)) {
            if (-not $this.Simple) {
                $this.Attributes($method)

                $methodImpl = $method.MethodImplementationFlags -band -bnot [MethodImplAttributes]::CodeTypeMask
                $methodImpl = $methodImpl -band -bnot [MethodImplAttributes]::PreserveSig
                if ($methodImpl) {
                    $this.Attribute(
                        [System.Runtime.CompilerServices.MethodImplAttribute],
                        [TypedArgumentList]::new(
                            [TypedArgument]::new(
                                [System.Runtime.CompilerServices.MethodImplOptions],
                                $methodImpl.value__),
                            @()))

                    $this.NewLine()
                }
            }

            $this.Modifiers($method)

            if ($method.Attributes -band [System.Reflection.MethodAttributes]::PinvokeImpl) {
                $this.Keyword('extern').Space()
            }
        }

        if ($isCtor) {
            $this.TypeInfo($method.ReflectedType.Name -replace '`\d+$')
        } else {
            $this.TypeInfo($method.ReturnParameter).Space()

            if ($isExplicitImplementation) {
                $this.TypeInfo($interfaceType).Dot().MemberName($methodName)
            } elseif ($overrideMethodName) {
                $this.TypeInfo($overrideMethodName)
            } else {
                $this.MemberName($method.Name)
            }
        }

        $genericArgs = [type[]]@()
        if (-not $isCtor -and $method.IsGenericMethod) {
            $this.OpenGeneric()
            $genericArgs = $method.GetGenericArguments()

            $this.TypeInfo(
                $genericArgs[0],
                <# isForAttribute: #> $false,
                <# isForDefinition: #> $true)
            for ($i = 1; $i -lt $genericArgs.Length; $i++) {
                $this.Comma().Space()
                $this.TypeInfo(
                    $genericArgs[$i],
                    <# isForAttribute: #> $false,
                    <# isForDefinition: #> $true)
            }

            $this.CloseGeneric()
        }

        $this.OpenParen()
        $parameters = $method.GetParameters()
        if ($parameters.Length -eq 0) {
            return $this.CloseParen().GenericConstraints($genericArgs).Semi()
        }

        $longSig = $parameters.Length -gt 2 -and -not $this.Simple
        if ($longSig) {
            $this.PushIndent().NewLine()
        }

        $this.Parameter($parameters[0])
        for ($i = 1; $i -lt $parameters.Length; $i++) {
            if ($longSig) {
                $this.Comma().NewLine()
            } else {
                $this.Comma().Space()
            }

            $this.Parameter($parameters[$i])
        }

        if ($longSig) {
            $this.PopIndent()
        }

        return $this.CloseParen().GenericConstraints($genericArgs).Semi()
    }

    [bool] IsExplicitImplementation([MethodBase] $method, [ref] $interface, [ref] $name) {
        if ($method -is [ConstructorInfo]) {
            return $false
        }

        $fakeExplicitImplementation = $method.DeclaringType.IsInterface -and (
            ($this.TargetType -and $this.TargetType -ne $method.DeclaringType) -or (
            $method.DeclaringType -ne $method.ReflectedType))

        if ($fakeExplicitImplementation) {
            $interface.Value = $method.DeclaringType
            $name.Value = $method.Name
            return $true
        }

        $lastDotIndex = $method.Name.LastIndexOf([char]'.')
        if ($lastDotIndex -eq -1) {
            return $false
        }

        foreach ($implInterface in $method.DeclaringType.GetInterfaces()) {
            $mapping = $method.DeclaringType.GetInterfaceMap($implInterface)
            for ($i = $mapping.TargetMethods.Length - 1; $i -ge 0; $i--) {
                if ($mapping.TargetMethods[$i] -ne $method) {
                    continue
                }

                $interface.Value = $mapping.InterfaceType
                $name.Value = $mapping.InterfaceMethods[$i].Name
                return $true
            }
        }

        return $false
    }

    [SignatureWriter] DefaultValue([ParameterInfo] $parameter) {
        return $this.DefaultValue($parameter, <# includeEqual: #> $false)
    }

    [SignatureWriter] DefaultValue([ParameterInfo] $parameter, [bool] $includeEqual) {
        # This returns DBNull when there's no default for some reason.
        $default = $parameter.RawDefaultValue
        if ($default -is [DBNull]) {
            return $this
        }

        if ($includeEqual) {
            $this.Space().Equal().Space()
        }

        if ($null -eq $default) {
            if ($parameter.ParameterType.BaseType -eq [ValueType]) {
                return $this.Keyword('default')
            }

            return $this.Keyword('null');
        }

        return $this.AttributeArgument($parameter.ParameterType, $default)
    }

    [SignatureWriter] StringLiteral([string] $value) {
        return $this.StringLiteral(
            $value,
            <# isChar: #> $false,
            <# $includeQuotes: #> $true)
    }

    [SignatureWriter] StringLiteral([string] $value, [bool] $isChar, [bool] $includeQuotes) {
        $quoteChar = '"'[0]
        if ($isChar) {
            $quoteChar = "'"[0]
        }

        $this.Append([SignatureWriter]::Formatting.String)
        if ($includeQuotes) {
            $this.sb.Append($quoteChar)
        }

        $chars = $value.ToCharArray()
        foreach ($char in $value.ToCharArray()) {
            if ($char.Equals([EscapeChars]::Alert)) {
                $this.StringEscape('\a')
                continue
            }

            if ($char.Equals([EscapeChars]::Backspace)) {
                $this.StringEscape('\b')
                continue
            }

            if ($char.Equals([EscapeChars]::CarriageReturn)) {
                $this.StringEscape('\r')
                continue
            }

            if ($char.Equals([EscapeChars]::FormFeed)) {
                $this.StringEscape('\f')
                continue
            }

            if ($char.Equals([EscapeChars]::HorizontalTab)) {
                $this.StringEscape('\t')
                continue
            }

            if ($char.Equals([EscapeChars]::NewLine)) {
                $this.StringEscape('\n')
                continue
            }

            if ($char.Equals([EscapeChars]::Null)) {
                $this.StringEscape('\0')
                continue
            }

            if ($char.Equals([EscapeChars]::VerticalTab)) {
                $this.StringEscape('\v')
                continue
            }

            if ($includeQuotes -and $char.Equals($quoteChar)) {
                $this.StringEscape('\' + $quoteChar)
                continue
            }

            $category = [CharUnicodeInfo]::GetUnicodeCategory($char)
            $needsEscaping = $category.Equals([UnicodeCategory]::Control) -or
                $category.Equals([UnicodeCategory]::OtherNotAssigned) -or
                $category.Equals([UnicodeCategory]::ParagraphSeparator) -or
                $category.Equals([UnicodeCategory]::LineSeparator) -or
                $category.Equals([UnicodeCategory]::Surrogate)

            if (-not $needsEscaping) {
                $this.sb.Append($char)
                continue
            }

            $this.StringEscape('\u' + ([int]$char).ToString('x4'))
        }

        if ($includeQuotes) {
            $this.sb.Append($quoteChar)
        }

        return $this.Append([SyntaxFormatting]::Instance.Reset)
    }

    [SignatureWriter] StringEscape([string] $value) {
        return $this.
            Append([SignatureWriter]::Formatting.StringEscape).
            Append($value).
            Append([SignatureWriter]::Formatting.String)
    }

    [SignatureWriter] Parameter([ParameterInfo] $parameter) {
        $isByRef = $parameter.ParameterType.IsByRef
        $hasOutDecoration = $false
        $hasInDecoration = $false
        $hasReadOnlyDecoration = $false

        foreach ($attribute in $parameter.CustomAttributes) {
            if ($attribute.AttributeType -eq [OutAttribute]) {
                $hasOutDecoration = $true
                continue
            }

            if ($attribute.AttributeType -eq [InAttribute]) {
                $hasInDecoration = $true
                continue
            }

            if ($attribute.AttributeType.FullName -eq $this::IsReadOnlyAttribute) {
                $hasReadOnlyDecoration = $true
                continue
            }
        }

        if (-not $this.Simple) {
            foreach ($attribute in $parameter.CustomAttributes) {
                $skip = $attribute.AttributeType -eq [OptionalAttribute] -or (
                    $attribute.AttributeType.FullName -eq $this::IsReadOnlyAttribute -and $isByRef)

                if ($skip) {
                    continue
                }

                $skip = $attribute.AttributeType -eq [OutAttribute] -and
                    $isByRef -and
                    -not $hasInDecoration

                if ($skip) {
                    continue
                }

                if ($attribute.AttributeType -eq [InAttribute] -and $hasReadOnlyDecoration) {
                    continue
                }

                if ($attribute.AttributeType -eq [MarshalAsAttribute]) {
                    $this.MarshalAsAttribute($attribute, <# isReturn: #> $false).Space()
                    continue
                }

                $this.Attribute($attribute).Space()
            }
        }

        return $this.
            TypeInfo($parameter).
            Space().
            Variable($parameter.Name).
            DefaultValue($parameter, <# includeEqual: #> $true)
    }

    [SignatureWriter] GenericConstraints([type[]] $genericArgs) {
        if ($this.Simple) {
            return $this
        }

        if ($null -eq $genericArgs -or $genericArgs.Length -eq 0) {
            return $this
        }

        foreach ($genericArg in $genericArgs) {
            $this.GenericConstraint($genericArg)
        }

        return $this
    }

    [SignatureWriter] GenericConstraint([type] $genericArg) {
        $isPrepped = [ref]$false
        $attributes = $genericArg.GenericParameterAttributes
        if ($attributes -band [GenericParameterAttributes]::ReferenceTypeConstraint) {
            $this.MaybePrepForGenericConstraint($genericArg, $isPrepped).
                Keyword('class')
        }

        if ($attributes -band [GenericParameterAttributes]::NotNullableValueTypeConstraint) {
            $this.MaybePrepForGenericConstraint($genericArg, $isPrepped)

            $isUnmanaged = $genericArg.GetCustomAttributes($true).TypeId.FullName -eq $this::IsUnmanagedAttribute
            if ($isUnmanaged) {
                $this.Keyword('unmanaged')
            } else {
                $this.Keyword('struct')
            }
        } elseif ($attributes -band [GenericParameterAttributes]::DefaultConstructorConstraint) {
            $this.MaybePrepForGenericConstraint($genericArg, $isPrepped).
                Keyword('new').OpenParen().CloseParen()
        }

        $constraints = $genericArg.GetGenericParameterConstraints()
        foreach ($constraint in $constraints) {
            if ($constraint -eq [ValueType]) {
                continue
            }

            $this.MaybePrepForGenericConstraint($genericArg, $isPrepped)
            $this.TypeInfo($constraint)
        }

        if ($isPrepped.Value) {
            $this.PopIndent()
        }

        return $this
    }

    [SignatureWriter] MaybePrepForGenericConstraint([type] $genericArg, [ref] $alreadyDone) {
        if ($alreadyDone.Value) {
            return $this.Comma().Space()
        }

        $alreadyDone.Value = $true
        return $this.PushIndent().
            NewLine().
            Keyword('where').
            Space().
            TypeInfo($genericArg).
            Space().Colon().Space()
    }

    [SignatureWriter] Member([PropertyInfo] $property) {
        $getMethod = $property.GetGetMethod(<# nonPublic: #> $true)
        $setMethod = $property.GetSetMethod(<# nonPublic: #> $true)

        if ($getMethod) {
            $modifiersMethod = $getMethod
            $propertyParameter = $getMethod.ReturnParameter
            $indexParameter = $getMethod.GetParameters()[0]
        } else {
            $modifiersMethod = $setMethod
            $propertyParameter = $setMethod.GetParameters()[-1]
            $indexParameter = $setMethod.GetParameters()[0]
        }

        $interfaceType = $null
        $name = $null
        $isExplicitImplementation = $this.IsExplicitImplementation(
            $getMethod,
            [ref] $interfaceType,
            [ref] $name)

        if (-not $isExplicitImplementation) {
            $name = $property.Name
            $this.Modifiers($modifiersMethod)
        }

        $this.TypeInfo($propertyParameter).Space()

        if ($isExplicitImplementation) {
            $this.TypeInfo($interfaceType).Dot()
            $name = $name -replace '^get_'
        }

        if ($indexParameter) {
            $this.Keyword('this').
                OpenSquare().
                TypeInfo($indexParameter).
                Space().
                Variable($indexParameter.Name).
                CloseSquare().
                Space()
        } else {
            $this.Variable($name).Space()
        }

        $this.OpenCurly().Space()
        if ($getMethod) {
            $this.Keyword('get').Semi().Space()
        }

        if ($setMethod) {
            $hasIsExternalInit = $setMethod.ReturnParameter.GetRequiredCustomModifiers().FullName -contains
                $this::IsExternalInit

            if ($hasIsExternalInit) {
                return $this.Keyword('init').Space().Keyword('set').Semi().Space().CloseCurly()
            }

            $getMethodAccess = $getMethod.Attributes -band [System.Reflection.MethodAttributes]::MemberAccessMask
            $setMethodAccess = $setMethod.Attributes -band [System.Reflection.MethodAttributes]::MemberAccessMask
            if (-not $getMethod -or $getMethodAccess -eq $setMethodAccess) {
                return $this.Keyword('set').Semi().Space().CloseCurly()
            }

            $this.AccessModifiers($setMethod).Keyword('set').Semi().Space()
        }

        return $this.CloseCurly()
    }

    [SignatureWriter] Member([EventInfo] $event) {
        $addMethod = $event.GetAddMethod(<# nonPublic: #> $true)
        $removeMethod = $event.GetRemoveMethod(<# nonPublic: #> $true)

        if ($addMethod) {
            $modifiersMethod = $addMethod
            $eventParameter = $addMethod.GetParameters()[0]
        } else {
            $modifiersMethod = $removeMethod
            $eventParameter = $removeMethod.GetParameters()[0]
        }

        $this.Modifiers($modifiersMethod).
            Keyword('event').Space().
            TypeInfo($eventParameter).Space()

        $this.MemberName($event.Name).Space()

        $this.OpenCurly().Space()
        if ($addMethod) {
            $this.Keyword('add').Semi().Space()
        }

        if ($removeMethod) {

            $addMethodAccess = $addMethod.Attributes -band [System.Reflection.MethodAttributes]::MemberAccessMask
            $removeMethodAccess = $removeMethod.Attributes -band [System.Reflection.MethodAttributes]::MemberAccessMask
            if (-not $addMethod -or $addMethodAccess -eq $removeMethodAccess) {
                return $this.Keyword('remove').Semi().Space().CloseCurly()
            }

            $this.AccessModifiers($removeMethod).Keyword('remove').Semi().Space()
        }

        return $this.CloseCurly()
    }

    [string] RemoveArity([string] $name) {
        $index = $name.LastIndexOf([char]'`'[0])
        if ($index -eq -1) {
            return $name
        }

        return $name.Substring(0, $index)
    }
}

function Format-MemberSignature {
    [Alias('fms')]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [System.Reflection.MemberInfo[]] $InputObject,

        [Parameter()]
        [ValidateSet('External', 'Child', 'Internal', 'All', 'ChildInternal')]
        [string] $View,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $IncludeSpecial,

        [Parameter()]
        [switch] $Simple,

        [Parameter()]
        [type] $TargetType
    )
    begin {
        if ($Force.IsPresent) {
            $View = 'All'
        }

        $writer = [SignatureWriter]::new()
        $writer.Force = $Force.IsPresent
        $writer.Recurse = $Recurse.IsPresent
        $writer.IncludeSpecial = $IncludeSpecial.IsPresent
        $writer.Simple = $Simple.IsPresent
        $writer.TargetType = $TargetType
        switch ($View) {
            'Internal' { $writer.View = [MemberView]::Internal; break }
            'ChildInternal' { $writer.View = [MemberView]::Child -bor [MemberView]::Internal; break }
            'External' { $writer.View = [MemberView]::External; break }
            'Child' { $writer.View = [MemberView]::Child; break }
            'All' { $writer.View = [MemberView]::All; break }
        }
    }
    process {
        foreach ($member in $InputObject) {
            $writer.Clear()
            $writer.NewLineNoIndent().Member($member).ToString()
        }
    }
}

[SignatureWriter]::Formatting = $formatting
