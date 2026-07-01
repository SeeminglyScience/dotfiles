namespace Profile;

public static class ProfileInfo
{
    public static string ProfileBase
    {
        get => field ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments, Environment.SpecialFolderOption.DoNotVerify),
            "PowerShell");
        set => field = value;
    }
}