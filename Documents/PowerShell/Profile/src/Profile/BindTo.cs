using System.Reflection;

namespace Profile;

internal static class BindTo
{
    public static class Instance
    {
        public const BindingFlags Public = BindingFlags.Instance | BindingFlags.Public;

        public const BindingFlags NonPublic = BindingFlags.Instance | BindingFlags.NonPublic;

        public const BindingFlags Any = BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public;
    }

    public static class Static
    {
        public const BindingFlags Public = BindingFlags.Static | BindingFlags.Public;

        public const BindingFlags NonPublic = BindingFlags.Static | BindingFlags.NonPublic;

        public const BindingFlags Any = BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public;
    }
}