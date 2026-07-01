using System.Reflection.Metadata.Ecma335;
using System.Collections.Immutable;
using System.Reflection.Metadata;
using System.Reflection;

namespace Profile;

public class GenericContext
{
    public Type[] TypeArguments = Array.Empty<Type>();

    public Type[] MethodArguments = Array.Empty<Type>();
}

public class TypeSigDecoder(Module module) : ISignatureTypeProvider<Type, GenericContext>
{
    public unsafe static MethodSignature<Type> ParseSignature(byte[] signature, Module module, GenericContext context)
    {
        SignatureDecoder<Type, GenericContext> decoder = new(
            new TypeSigDecoder(module),
            null!,
            context);

        fixed (byte* ptr = signature)
        {
            BlobReader reader = new(ptr, signature.Length);
            return decoder.DecodeMethodSignature(ref reader);
        }
    }

    private readonly Module _module = module;

    public Type GetArrayType(Type elementType, ArrayShape shape)
    {
        if (shape.Rank is 1)
        {
            return elementType.MakeArrayType();
        }

        return elementType.MakeArrayType(shape.Rank);
    }

    public Type GetByReferenceType(Type elementType)
    {
        return elementType.MakeByRefType();
    }

    public Type GetFunctionPointerType(MethodSignature<Type> signature)
    {
        throw new NotImplementedException();
    }

    public Type GetGenericInstantiation(Type genericType, ImmutableArray<Type> typeArguments)
    {
        return genericType.MakeGenericType(typeArguments.ToArray());
    }

    public Type GetGenericMethodParameter(GenericContext genericContext, int index)
    {
        return genericContext.MethodArguments[index];
    }

    public Type GetGenericTypeParameter(GenericContext genericContext, int index)
    {
        return genericContext.TypeArguments[index];
    }

    public Type GetModifiedType(Type modifier, Type unmodifiedType, bool isRequired)
    {
        return unmodifiedType;
    }

    public Type GetPinnedType(Type elementType)
    {
        return elementType;
    }

    public Type GetPointerType(Type elementType)
    {
        return elementType.MakePointerType();
    }

    public Type GetPrimitiveType(PrimitiveTypeCode typeCode)
    {
        return typeCode switch
        {
            PrimitiveTypeCode.Boolean => typeof(bool),
            PrimitiveTypeCode.Byte => typeof(byte),
            PrimitiveTypeCode.Char => typeof(char),
            PrimitiveTypeCode.Double => typeof(double),
            PrimitiveTypeCode.Int16 => typeof(short),
            PrimitiveTypeCode.Int32 => typeof(int),
            PrimitiveTypeCode.Int64 => typeof(long),
            PrimitiveTypeCode.IntPtr => typeof(nint),
            PrimitiveTypeCode.Object => typeof(object),
            PrimitiveTypeCode.SByte => typeof(sbyte),
            PrimitiveTypeCode.Single => typeof(float),
            PrimitiveTypeCode.String => typeof(string),
            PrimitiveTypeCode.TypedReference => typeof(TypedReference),
            PrimitiveTypeCode.UInt16 => typeof(ushort),
            PrimitiveTypeCode.UInt32 => typeof(uint),
            PrimitiveTypeCode.UInt64 => typeof(ulong),
            PrimitiveTypeCode.UIntPtr => typeof(nuint),
            PrimitiveTypeCode.Void => typeof(void),
            _ => throw new ArgumentOutOfRangeException(nameof(typeCode)),
        };
    }

    public Type GetSZArrayType(Type elementType)
    {
        return elementType.MakeArrayType();
    }

    public Type GetTypeFromDefinition(MetadataReader reader, TypeDefinitionHandle handle, byte rawTypeKind)
    {
        return _module.ResolveType(MetadataTokens.GetToken(handle));
    }

    public Type GetTypeFromReference(MetadataReader reader, TypeReferenceHandle handle, byte rawTypeKind)
    {
        return _module.ResolveType(MetadataTokens.GetToken(handle));
    }

    public Type GetTypeFromSpecification(MetadataReader reader, GenericContext genericContext, TypeSpecificationHandle handle, byte rawTypeKind)
    {
        throw new NotImplementedException();
    }
}