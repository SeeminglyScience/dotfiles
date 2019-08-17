<#
    DESCRIPTION
        This script sets the current console font. The module WindowsConsoleFont by Jaykul
        could (and probably should) be used here instead. That's not currently published
        anywhere so I put together a minimal version to avoid needing to compile that project
        on every machine I use.
#>
[CmdletBinding()]
param([string] $Family, [int] $Size)
end {
    # If we're not in conhost don't try to set font family.
    if ($env:TERM_PROGRAM -match 'vscode' -or $env:WT_SESSION) {
        return
    }

    $assemblyPath = "$PSScriptRoot\FontSetter.dll"
    if (-not (Test-Path $assemblyPath)) {
        Add-Type -OutputType Library -OutputAssembly $assemblyPath -TypeDefinition '
            using System;
            using System.ComponentModel;
            using System.Management.Automation;
            using System.Runtime.InteropServices;

            namespace ProfileUtility
            {
                [EditorBrowsable(EditorBrowsableState.Never)]
                public static class FontSetter
                {
                    private static IntPtr s_outputHandle;

                    [Hidden, EditorBrowsable(EditorBrowsableState.Never)]
                    public static void SetConsoleFont(string familyName, short size = 0)
                    {
                        var info = new Interop.CONSOLE_FONT_INFOEX();
                        info.FaceName = new char[Interop.LF_FACESIZE];
                        info.cbSize = (uint)Marshal.SizeOf<Interop.CONSOLE_FONT_INFOEX>();
                        int result = Interop.GetCurrentConsoleFontEx(
                            GetOutputHandle(),
                            false,
                            ref info);

                        if (result == 0)
                        {
                            throw new Win32Exception(Marshal.GetLastWin32Error());
                        }

                        Array.Clear(info.FaceName, 0, info.FaceName.Length);
                        familyName.CopyTo(0, info.FaceName, 0, Math.Min(familyName.Length, Interop.LF_FACESIZE));
                        if (size > 0)
                        {
                            info.dwFontSize.Y = size;
                        }

                        result = Interop.SetCurrentConsoleFontEx(
                            GetOutputHandle(),
                            false,
                            ref info);

                        if (result == 0)
                        {
                            throw new Win32Exception(Marshal.GetLastWin32Error());
                        }
                    }

                    private static IntPtr GetOutputHandle()
                    {
                        if (s_outputHandle != Interop.INVALID_HANDLE_VALUE && s_outputHandle != IntPtr.Zero)
                        {
                            return s_outputHandle;
                        }

                        IntPtr outputHandle = Interop.GetStdHandle(Interop.STD_OUTPUT_HANDLE);
                        if (outputHandle == Interop.INVALID_HANDLE_VALUE)
                        {
                            throw new Win32Exception(Marshal.GetLastWin32Error());
                        }

                        return s_outputHandle = outputHandle;
                    }

                    private static class Interop
                    {
                        public const int LF_FACESIZE = 32;

                        public const int STD_OUTPUT_HANDLE = -11;

                        public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

                        private const string Kernel32DllName = "kernel32";

                        [DllImport(Kernel32DllName, SetLastError = true)]
                        public static extern IntPtr GetStdHandle(int nStdHandle);


                        [DllImport(Kernel32DllName, SetLastError = true, CharSet = CharSet.Unicode)]
                        public static extern int GetCurrentConsoleFontEx(
                            IntPtr hConsoleOutput,
                            bool bMaximumWindow,
                            ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);

                        [DllImport(Kernel32DllName, SetLastError = true, CharSet = CharSet.Unicode)]
                        public static extern int SetCurrentConsoleFontEx(
                            IntPtr hConsoleOutput,
                            bool bMaximumWindow,
                            ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);

                        [StructLayout(LayoutKind.Sequential)]
                        public struct COORD
                        {
                            public short X;

                            public short Y;
                        }

                        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
                        public struct CONSOLE_FONT_INFOEX
                        {
                            public uint cbSize;

                            public int nFont;

                            public COORD dwFontSize;

                            public uint FontFamily;

                            public uint FontWeight;

                            [MarshalAs(UnmanagedType.ByValArray, SizeConst = LF_FACESIZE)]
                            public char[] FaceName;
                        }
                    }
                }
            }'
    }

    Add-Type -Path $assemblyPath -ErrorAction Stop
    [ProfileUtility.FontSetter]::SetConsoleFont($Family, $Size)
}
