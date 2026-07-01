namespace Profile.Clipboard;

[Flags]
public enum InputStreamOptions
{
    None = 0,
    Partial = 0x1,
    ReadAhead = 0x2,
}
