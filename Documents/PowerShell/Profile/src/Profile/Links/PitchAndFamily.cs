namespace Profile.Links;

[Flags]
public enum PitchAndFamily : uint
{
    None = 0,
    FixedPitch = 1 << 0,
    Vector = 1 << 1,
    TrueType = 1 << 2,
    Device = 1 << 3,
}
