using System.Text.Json;

namespace Profile;

public readonly record struct ErrorCodeInfo(int Code, string Name, string Description, string Source)
{
    private static readonly Lazy<Dictionary<int, ErrorCodeInfo[]>> s_errorCodes = new(() =>
    {
        string file = Path.Combine(ProfileInfo.ProfileBase, "win32-error.jsonc");
        if (!File.Exists(file))
        {
            return [];
        }

        using FileStream stream = new FileStream(
            file,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);

        return JsonSerializer.Deserialize<Dictionary<int, ErrorCodeInfo[]>>(
            JsonDocument.Parse(
                stream,
                new JsonDocumentOptions()
                {
                    CommentHandling = JsonCommentHandling.Skip,
                    AllowTrailingCommas = true,
                })) ?? [];
    });

    public static ErrorCodeInfo[] GetInfo(uint code) => GetInfo((int)code);

    public static ErrorCodeInfo[] GetInfo(int code) => s_errorCodes.Value.TryGetValue(code, out ErrorCodeInfo[]? eci)
        ? eci
        : [];

    public override string ToString() => Name;
}