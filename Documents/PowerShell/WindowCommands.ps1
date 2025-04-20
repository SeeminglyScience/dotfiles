# using namespace System
# using namespace System.Collections.Generic
# using namespace System.ComponentModel
# using namespace System.Runtime.InteropServices

# $user32 = lib user32

# [Flags()]
# enum WindowStationAccessRights {
#     # Required to delete the object.
#     Delete = 0x00010000

#     # Required to read information in the security descriptor for the object, not including the information in the SACL.
#     ReadControl = 0x00020000

#     # Not supported for window station objects.
#     Synchronize = 0x00100000

#     # Required to modify the DACL in the security descriptor for the object.
#     WriteDac = 0x00040000

#     # Required to change the owner in the security descriptor for the object.
#     WriteOwner = 0x00080000

#     # All possible access rights for the window station.
#     AllAccess = 0x37F

#     # Required to use the clipboard.
#     AccessClipboard = 0x0004

#     # Required to manipulate global atoms.
#     AccessGlobalAtoms = 0x0020

#     # Required to create new desktop objects on the window station.
#     CreateDesktop = 0x0008

#     # Required to enumerate existing desktop objects.
#     EnumDesktops = 0x0001

#     # Required for the window station to be enumerated.
#     Enumerate = 0x0100

#     # Required to successfully call the ExitWindows or ExitWindowsEx function.
#     ExitWindows = 0x0040

#     # Required to read the attributes of a window station object.
#     ReadAttributes = 0x0002

#     # Required to access screen contents.
#     ReadScreen = 0x0200

#     # Required to modify the attributes of a window station object.
#     WriteAttributes = 0x0010
# }

# class WindowStationHandle : IDisposable {
#     hidden [bool] $_isDisposed

#     hidden [bool] $_ownsHandle

#     [IntPtr] $Value

#     hidden WindowStationHandle([IntPtr] $value) {
#         $this.Value = $value
#         $this._ownsHandle = $true
#     }

#     hidden WindowStationHandle([IntPtr] $value, [bool] $ownsHandle) {
#         $this.Value = $value
#         $this._ownsHandle = $false
#     }

#     static [WindowStationHandle] GetNull() {
#         return [WindowStationHandle]::new([IntPtr]::Zero, $false)
#     }

#     static [WindowStationHandle] GetCurrent() {
#         $user32 = $script:user32
#         $result = $user32.SetLastError().GetProcessWindowStation[IntPtr]()
#         if ($result -eq [IntPtr]::Zero) {
#             throw [Win32Exception]::new($user32.LastError)
#         }

#         return [WindowStationHandle]::new($result, $false)
#     }

#     static [WindowStationHandle] Open([string] $winsta) {
#         return [WindowStationHandle]::Open(
#             $winsta,
#             $true,
#             [WindowStationAccessRights]::EnumDesktops -bor 'Enumerate' -bor 'ReadAttributes' -bor 'ReadScreen')
#     }

#     static [WindowStationHandle] Open([string] $winsta, [bool] $inherit, [int] $desiredAccess) {
#         $user32 = $script:user32
#         $result = $user32.SetLastError().OpenWindowStationW[IntPtr](
#             $user32.MarshalAs($winsta, [UnmanagedType]::LPWStr),
#             $inherit,
#             $desiredAccess)

#         if ($result -eq [IntPtr]::Zero) {
#             throw [Win32Exception]::new($user32.LastError)
#         }

#         return [WindowStationHandle]::new($result)
#     }

#     [void] Dispose() {
#         if ($this._isDisposed) {
#             return
#         }

#         if ($this._ownsHandle) {
#             $user32 = $script:user32
#             if ($user32.SetLastError().CloseWindowStation($this.Value) -eq 0) {
#                 throw [Win32Exception]::new($user32.LastError)
#             }
#         }

#         $this._isDisposed = $true
#     }
# }

# class ItemHandle : IDisposable {
#     [bool] $_isDisposed

#     [GCHandle] $Handle

#     [IntPtr] $Value

#     hidden ItemHandle([GCHandle] $handle) {
#         $this.Handle = $handle
#         $this.Value = [GCHandle]::ToIntPtr($handle)
#     }

#     static [ItemHandle] Alloc([object] $value) {
#         return [ItemHandle]::new([GCHandle]::Alloc($value))
#     }

#     [void] Dispose() {
#         if ($this._isDisposed) {
#             return
#         }

#         $this.Handle.Free()
#         $this.Value = [IntPtr]::Zero
#         $this._isDisposed = $true
#     }
# }

# class DisposalTarget : IDisposable {

#     [IDisposable] $Value

#     DisposalTarget() {
#     }

#     DisposalTarget([IDisposable] $value) {
#         $this.Value = $value
#     }

#     [void] Dispose() {
#         $this.Value?.Dispose()
#     }
# }

# function Get-WindowStation {
#     [CmdletBinding()]
#     param()
#     end {
#         $users = [List[string]]::new()
#         $pUsers = $null
#         try {
#             $pUsers = [GCHandle]::Alloc($users)
#             $success = $user32.SetLastError().EnumWindowStationsW[int](
#                 {
#                     [OutputType([int])]
#                     param(
#                         [MarshalAs([UnmanagedType]::LPWStr)]
#                         [string] $lpszWindowStation,

#                         [intptr] $lParam
#                     )

#                     [GCHandle]::FromIntPtr($lParam).Target.Add($lpszWindowStation)
#                     return 1
#                 },
#                 [GCHandle]::ToIntPtr($pUsers))
#         } finally {
#             if ($pUsers -is [GCHandle]) {
#                 $pUsers.Free()
#             }
#         }

#         if ($success -ne 1) {
#             throw [Win32Exception]::new($user.LastError)
#         }

#         return $users
#     }
# }

# function Get-WindowDesktop {
#     [CmdletBinding()]
#     param(
#         [Parameter(ValueFromPipeline)]
#         [string] $WindowStation
#     )
#     process {
#         if ($MyInvocation.ExpectingInput -and -not $WindowStation) {
#             return
#         }

#         $desktops = [List[string]]::new()
#         use { $winsta = [DisposalTarget]::new() } {
#         use { $pList = [ItemHandle]::Alloc($desktops) } {

#             $winsta.Value = $WindowStation ? [WindowStationHandle]::Open($WindowStation) : [WindowStationHandle]::GetCurrent()
#             $user32 = $script:user32
#             $success = $user32.SetLastError().EnumDesktopsW(
#                 $winsta.Value.Value,
#                 {
#                     [OutputType([int])]
#                     param(
#                         [MarshalAs([UnmanagedType]::LPTStr)]
#                         [string] $lpszDesktop,

#                         [IntPtr] $lParam
#                     )
#                     end {
#                         [GCHandle]::FromIntPtr($lParam).Target.Add($lpszDesktop)
#                         return 1
#                     }
#                 },
#                 $pList.Value)

#             if ($success -eq 0) {
#                 throw [Win32Exception]::new($user32.LastError)
#             }

#             return $desktops
#         }}
#     }
# }

# [Flags()]
# enum WindowStyle : uint {
#     Tiled = 0u
#     Overlapped = 0u
#     MaximizeBox = 1u -shl 16
#     TabStop = 1u -shl 16
#     Group = 1u -shl 17
#     MinimizeBox = 1u -shl 17
#     SizeBox = 1u -shl 18
#     ThickFrame = 1u -shl 18
#     SysMenu = 1u -shl 19
#     HScroll = 1u -shl 20
#     VScroll = 1u -shl 21
#     DlgFrame = 1u -shl 22
#     Border = 1u -shl 23
#     Caption = (1u -shl 22) -bor (1u -shl 23)
#     TiledWindow = 0u -bor (1u -shl 17) -bor (1u -shl 17) -bor (1u -shl 18) -bor (1u -shl 19) -bor ((1u -shl 22) -bor (1u -shl 23))
#     OverlappedWindow = 0u -bor (1u -shl 16) -bor (1u -shl 17) -bor (1u -shl 18) -bor (1u -shl 19) -bor ((1u -shl 22) -bor (1u -shl 23))
#     Maximize = 1u -shl 24
#     ClipChildren = 1u -shl 25
#     ClipSiblings = 1u -shl 26
#     Disabled = 1u -shl 27
#     Visible = 1u -shl 28
#     Minimize = 1u -shl 29
#     Iconic = 1u -shl 29
#     Child = 1u -shl 30
#     ChildWindow = 1u -shl 30
#     Popup = 1u -shl 31
#     PopupWindow = (1u -shl 19) -bor (1u -shl 23) -bor (1u -shl 31)
# }

# [Flags()]
# enum WindowStyleEx : uint {
#     Left = 0u
#     LtrReading = 0u
#     DialogModalFrame = 1u -shl 0
#     Unused1 = 1u -shl 1
#     NoParentNotify = 1u -shl 2
#     TopMost = 1u -shl 3
#     AcceptFiles = 1u -shl 4
#     Transparent = 1u -shl 5
#     MdiChild = 1u -shl 6
#     ToolWindow = 1u -shl 7
#     WindowEdge = 1u -shl 8
#     PaletteWindow = (1u -shl 3) -bor (1u -shl 7) -bor (1u -shl 8)
#     OverlappedWindow = (1u -shl 8) -bor (1u -shl 9)
#     ClientEdge = 1u -shl 9
#     ContextHelp = 1u -shl 10
#     MakeVisibleWhenUnghosted = 1u -shl 11
#     Right = 1u -shl 12
#     RtlReading = 1u -shl 13
#     LeftScrollBar = 1u -shl 14
#     Unused2 = 1u -shl 15
#     ControlParent = 1u -shl 16
#     StaticEdge = 1u -shl 17
#     AppWindow = 1u -shl 18
#     Layered = 1u -shl 19
#     NoInheritLayout = 1u -shl 20
#     NoRedirectionBitmap = 1u -shl 21
#     LayoutRtl = 1u -shl 22
#     NoPaddedBorder = 1u -shl 23
#     Unused4 = 1u -shl 24
#     Composited = 1u -shl 25
#     UIStateActive = 1u -shl 26
#     NoActivate = 1u -shl 27
#     CompositedCompositing = 1u -shl 28
#     Redirected = 1u -shl 29
#     UIStateKbdAccelHidden = 1u -shl 30
#     UIStateFocusRectHidden = 1u -shl 31
# }

# struct RECT {
#     [int] $left
#     [int] $top
#     [int] $right
#     [int] $bottom
# }

# struct WINDOWINFO {
#     [uint] $cbSize

#     [RECT] $rcWindow

#     [RECT] $rcClient

#     [WindowStyle] $dwStyle

#     [WindowStyleEx] $dwExStyle

#     [uint] $dwWindowStatus

#     [uint] $cxWindowBorders

#     [uint] $cyWindowBorders

#     [ushort] $atomWindowType

#     [ushort] $wCreatorVersion
# }

# function Get-Window {
#     [CmdletBinding()]
#     param()
#     end {
#         $user32 = $script:user32
#         $windows = [List[ptr]]::new()
#         use { $pList = [ItemHandle]::Alloc($windows) } {
#             $user32 = $script:user32
#             $success = $user32.SetLastError().EnumWindows(
#                 {
#                     [OutputType([int])]
#                     param([ptr] $hwnd, [ptr] $lParam)
#                     end {
#                         [GCHandle]::FromIntPtr($lParam).Target.Add($hwnd)
#                         return 1
#                     }
#                 },
#                 $pList.Value)

#             if ($success -eq 0) {
#                 throw [Win32Exception]::new($user32.LastError)
#             }
#         }

#         foreach ($window in $windows) {
#             $info = [ptr]::AllocZeroed[WINDOWINFO](1)
#             $temp = $info[0]
#             $temp.cbSize = size WINDOWINFO
#             $info[0] = $temp

#             $success = $user32.SetLastError().GetWindowInfo[int]($window, $info)
#             if ($success -eq 0) {
#                 throw [Win32Exception]::new($user32.LastError)
#             }

#             $length = $user32.SetLastError().GetWindowTextLengthW($window)
#             if ($length -eq 0 -and $user32.LastError -ne 0) {
#                 throw [Win32Exception]::new($user32.LastError)
#             }

#             $windowText = $null
#             if ($length -gt 0) {
#                 $text = [ptr]::Alloc[char]($length + 1)
#                 $null = $user32.SetLastError().GetWindowTextW(
#                     $window,
#                     $text,
#                     $length + 1)

#                 $windowText = $text.ToString($length)
#             } else {
#                 $windowText = ''
#             }

#             $processId = 0u
#             if ($user32.SetLastError().GetWindowThreadProcessId($window, [ref] $processId) -eq 0) {
#                 throw [Win32Exception]::new($user32.LastError)
#             }

#             [pscustomobject]@{
#                 Process = Get-Process -Id $processId | Add-Member -Force -PassThru -MemberType ScriptMethod -Name ToString -Value {
#                     $this.MainModule.FileName | Split-Path -Leaf
#                 }
#                 Info = $info
#                 Title = $windowText
#             }
#         }
#     }
# }