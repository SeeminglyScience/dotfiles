namespace Profile.Links;

[Flags]
public enum GpfIdlFlags
{
    /// <summary>
    /// Win32 file names, servers, and root drives are included.
    /// </summary>
    Default = 0x0000,
    /// <summary>
    /// Uses short file names.
    /// </summary>
    AltName = 0x0001,
    /// <summary>
    /// Include UNC printer names items.
    /// </summary>
    UncPrinter = 0x0002,
}
