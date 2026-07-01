namespace Profile.Clipboard;

[Flags]
public enum DataPackageOperation : uint
{
    None = 0,
    Copy = 0x1,
    Move = 0x2,
    Link = 0x4,
}
