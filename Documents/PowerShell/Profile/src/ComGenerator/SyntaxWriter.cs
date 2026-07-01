using System.Collections.Immutable;
using System.Security.Cryptography.X509Certificates;
using System.Text;

namespace ComGenerator;

internal enum MemberAccess
{
    Public,
    Private,
    Internal,
    Protected,
    PrivateProtected,
    InternalProtected,
    File,
}

public record struct TypeRef(
    string? Namespace,
    string Name,
    params ImmutableArray<TypeRef> GenericArguments);

internal abstract class SyntaxWriterBase<TSelf> where TSelf : SyntaxWriterBase<TSelf>
{
    internal static string[] s_indents =
    [
        "",
        "    ",
        "        ",
        "            ",
        "                ",
    ];

    protected virtual TSelf This => (TSelf)this;

    protected readonly StringBuilder _sb = new();

    private int _indent;

    private bool _shouldIndent;

    public override string ToString()
    {
        return _sb.ToString();
    }

    public TSelf PushIndent()
    {
        _indent++;
        return This;
    }

    public TSelf PopIndent()
    {
        _indent--;
        return This;
    }

    public virtual TSelf OpenNamespace(string name)
    {
        return AppendNamespace(name).AppendLine().OpenBlock();
    }

    protected abstract TSelf AppendNamespace(string name);

    public TSelf OpenBlock()
    {
        return AppendLine("{").PushIndent();
    }

    public TSelf CloseBlock()
    {
        return PopIndent().AppendLine("}");
    }
    public abstract TSelf AppendStructDecl(
        string name,
        string[]? interfaces = null,
        string[]? genericParams = null,
        bool isPartial = false,
        bool isReadOnly = false,
        bool isUnsafe = false,
        bool isRef = false,
        MemberAccess access = MemberAccess.Public);

    public TSelf Append(string value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(char value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(bool value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(sbyte value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(byte value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(short value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(ushort value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(int value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(uint value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(long value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(ulong value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(float value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(double value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(object value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(char[] value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(StringBuilder value) { MaybeIndent(); _sb.Append(value); return This; }
    public TSelf Append(string value, int startIndex, int count) { MaybeIndent(); _sb.Append(value, startIndex, count); return This; }
    public TSelf Append(char[] value, int startIndex, int count) { MaybeIndent(); _sb.Append(value, startIndex, count); return This; }
    public TSelf AppendFormat(string format, object? arg0) { MaybeIndent(); _sb.AppendFormat(format, arg0); return This; }
    public TSelf AppendFormat(string format, object? arg0, object? arg1) { MaybeIndent(); _sb.AppendFormat(format, arg0, arg1); return This; }
    public TSelf AppendFormat(string format, object? arg0, object? arg1, object? arg2) { MaybeIndent(); _sb.AppendFormat(format, arg0, arg1, arg2); return This; }
    public TSelf AppendFormat(string format, params object?[]? args) { MaybeIndent(); _sb.AppendFormat(format, args); return This; }
    public TSelf AppendLine()
    {
        _shouldIndent = true;
        _sb.AppendLine();
        return This;
    }

    public TSelf AppendLine(string value)
    {
        Append(value);
        _shouldIndent = true;
        _sb.AppendLine();
        return This;
    }

    private void MaybeIndent()
    {
        if (_indent < 1 || !_shouldIndent)
        {
            return;
        }

        if (_indent < s_indents.Length)
        {
            _sb.Append(s_indents[_indent]);
            _shouldIndent = false;
            return;
        }

        _sb.Append(' ', _indent * 4);
        _shouldIndent = false;
    }
}

internal class SyntaxWriter
{
    internal static string[] s_indents =
    [
        "",
        "    ",
        "        ",
        "            ",
        "                ",
    ];

    private readonly StringBuilder _sb = new();

    private int _indent;

    private bool _shouldIndent;

    public override string ToString()
    {
        return _sb.ToString();
    }

    public SyntaxWriter PushIndent()
    {
        _indent++;
        return this;
    }

    public SyntaxWriter PopIndent()
    {
        _indent--;
        return this;
    }

    public SyntaxWriter OpenNamespaceBlock(string name)
    {
        return Append("namespace ").Append(name).AppendLine()
            .AppendLine("{")
            .PushIndent();
    }

    public SyntaxWriter AppendStructDecl(
        string name,
        string[]? interfaces = null,
        string[]? genericParams = null,
        bool isPartial = false,
        bool isReadOnly = false,
        bool isUnsafe = false,
        bool isRef = false,
        bool isPublic = false,
        bool isInternal = false,
        bool isPrivate = false)
    {
        string access = 0 switch
        {
            _ when isPublic => "public",
            _ when isInternal => "internal",
            _ when isPrivate => "private",
            _ => "public",
        };

        Append(access).Append(' ');
        if (isReadOnly)
        {
            Append("readonly ");
        }

        if (isRef)
        {
            Append("ref ");
        }

        if (isUnsafe)
        {
            Append("unsafe ");
        }

        if (isPartial)
        {
            Append("partial ");
        }

        Append("struct ").Append(name);
        if (genericParams is { Length: > 0 })
        {
            Append('<').Append(genericParams[0]);
            for (int i = 1; i < genericParams.Length; i++)
            {
                Append(", ").Append(genericParams[i]);
            }

            Append('>');
        }

        if (interfaces is { Length: > 0 })
        {
            Append(" : ").Append(interfaces[0]);
            for (int i = 1; i < interfaces.Length; i++)
            {
                Append(", ").Append(interfaces[i]);
            }
        }

        return AppendLine();
    }

    public SyntaxWriter OpenBlock()
    {
        return AppendLine("{").PushIndent();
    }

    public SyntaxWriter CloseBlock()
    {
        return PopIndent().AppendLine("}");
    }

    public SyntaxWriter StartMethod(
        string name,
        string returnType,
        (string parameterType, string parameterName)[]? parameters = null,
        string[]? genericParameters = null,
        bool isPublic = false,
        bool isInternal = false,
        bool isPrivate = false,
        bool isFamily = false,
        bool isFamilyOrAssembly = false,
        bool isFamilyAndAssembly = false,
        bool isPartial = false,
        bool isStatic = false,
        bool skipAccess = false,
        bool isAbstract = false,
        bool isVirtual = false,
        bool isOverride = false,
        bool isNew = false,
        bool isExtern = false,
        bool isWithoutBody = false)
    {
        AppendAccess(isPublic, isInternal, isPrivate, isFamily, isFamilyOrAssembly, isFamilyAndAssembly, skipAccess);
        MaybeAppend(isStatic, "static ");
        MaybeAppend(isNew, "new ");
        MaybeAppend(isOverride, "override ");
        MaybeAppend(isVirtual, "virtual ");
        MaybeAppend(isAbstract, "abstract ");
        MaybeAppend(isPartial, "partial ");
        MaybeAppend(isExtern, "extern ");

        Append(returnType).Append(' ').Append(name);
        if (genericParameters is { Length: > 0 })
        {
            Append('<').Append(genericParameters[0]);
            for (int i = 1; i < genericParameters.Length; i++)
            {
                Append(", ").Append(genericParameters[i]);
            }

            Append('>');
        }

        if (parameters is not { Length: > 0 })
        {
            Append("()");
            return MaybeAppend(isWithoutBody, ";").AppendLine();
        }

        Append('(').Append(parameters[0].parameterType).Append(' ').Append(parameters[0].parameterName);
        for (int i = 1; i < parameters.Length; i++)
        {
            Append(", ").Append(parameters[i].parameterType).Append(' ').Append(parameters[i].parameterName);
        }

        Append(')');
        return MaybeAppend(isWithoutBody, ";").AppendLine();
    }

    public SyntaxWriter MaybeAppend(bool condition, string value)
    {
        if (!condition)
        {
            return this;
        }

        return Append(value);
    }

    private SyntaxWriter AppendAccess(
        bool isPublic = false,
        bool isInternal = false,
        bool isPrivate = false,
        bool isFamily = false,
        bool isFamilyOrAssembly = false,
        bool isFamilyAndAssembly = false,
        bool skipAccess = false,
        string defaultValue = "public")
    {
        if (skipAccess)
        {
            return this;
        }

        return Append(
            0 switch
            {
                _ when isPublic => "public",
                _ when isInternal => "internal",
                _ when isPrivate => "private",
                _ when isFamily => "protected",
                _ when isFamilyOrAssembly => "internal protected",
                _ when isFamilyAndAssembly => "private protected",
                _ => defaultValue,
            })
            .Append(' ');
    }

    public SyntaxWriter Append(string value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(char value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(bool value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(sbyte value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(byte value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(short value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(ushort value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(int value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(uint value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(long value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(ulong value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(float value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(double value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(object value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(char[] value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(StringBuilder value) { MaybeIndent(); _sb.Append(value); return this; }
    public SyntaxWriter Append(string value, int startIndex, int count) { MaybeIndent(); _sb.Append(value, startIndex, count); return this; }
    public SyntaxWriter Append(char[] value, int startIndex, int count) { MaybeIndent(); _sb.Append(value, startIndex, count); return this; }
    public SyntaxWriter AppendFormat(string format, object? arg0) { MaybeIndent(); _sb.AppendFormat(format, arg0); return this; }
    public SyntaxWriter AppendFormat(string format, object? arg0, object? arg1) { MaybeIndent(); _sb.AppendFormat(format, arg0, arg1); return this; }
    public SyntaxWriter AppendFormat(string format, object? arg0, object? arg1, object? arg2) { MaybeIndent(); _sb.AppendFormat(format, arg0, arg1, arg2); return this; }
    public SyntaxWriter AppendFormat(string format, params object?[]? args) { MaybeIndent(); _sb.AppendFormat(format, args); return this; }
    public SyntaxWriter AppendLine()
    {
        _shouldIndent = true;
        _sb.AppendLine();
        return this;
    }

    public SyntaxWriter AppendLine(string value)
    {
        Append(value);
        _shouldIndent = true;
        _sb.AppendLine();
        return this;
    }

    private void MaybeIndent()
    {
        if (_indent < 1 || !_shouldIndent)
        {
            return;
        }

        if (_indent < s_indents.Length)
        {
            _sb.Append(s_indents[_indent]);
            _shouldIndent = false;
            return;
        }

        _sb.Append(' ', _indent * 4);
        _shouldIndent = false;
    }
}
