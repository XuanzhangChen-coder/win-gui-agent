param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 8765,
    [string]$RunRoot = "C:\GuiAgent\runs"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class NativeWinGui {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr SetActiveWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const int SW_RESTORE = 9;
    public const int SW_MAXIMIZE = 3;
    public const uint WM_CLOSE = 0x0010;
    public const int INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public int type;
        public INPUTUNION u;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION {
        [FieldOffset(0)]
        public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    public class NativeWindowInfo {
        public long Hwnd { get; set; }
        public string Title { get; set; }
        public string ClassName { get; set; }
        public bool Visible { get; set; }
        public RECT Rect { get; set; }
    }

    private static string GetWindowTitleInternal(IntPtr hWnd) {
        int len = GetWindowTextLength(hWnd);
        if (len <= 0) {
            return "";
        }
        StringBuilder sb = new StringBuilder(len + 1);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    private static string GetWindowClassNameInternal(IntPtr hWnd) {
        StringBuilder sb = new StringBuilder(256);
        GetClassName(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static NativeWindowInfo[] EnumerateTopLevelWindows(bool includeUntitled) {
        List<NativeWindowInfo> windows = new List<NativeWindowInfo>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (!IsWindowVisible(hWnd)) {
                return true;
            }
            string title = GetWindowTitleInternal(hWnd);
            if (!includeUntitled && String.IsNullOrWhiteSpace(title)) {
                return true;
            }
            RECT rect;
            GetWindowRect(hWnd, out rect);
            windows.Add(new NativeWindowInfo {
                Hwnd = hWnd.ToInt64(),
                Title = title,
                ClassName = GetWindowClassNameInternal(hWnd),
                Visible = true,
                Rect = rect
            });
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }

    public static uint SendVirtualKey(ushort vk, bool keyUp) {
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki.wVk = vk;
        inputs[0].u.ki.wScan = 0;
        inputs[0].u.ki.dwFlags = keyUp ? KEYEVENTF_KEYUP : 0;
        inputs[0].u.ki.time = 0;
        inputs[0].u.ki.dwExtraInfo = IntPtr.Zero;
        return SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void KeybdEventVirtualKey(ushort vk, bool keyUp) {
        keybd_event((byte)vk, 0, keyUp ? KEYEVENTF_KEYUP : 0, UIntPtr.Zero);
    }
}
"@

function New-RunDirectory {
    if (!(Test-Path $RunRoot)) {
        New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $runDir = Join-Path $RunRoot $stamp
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    return $runDir
}

$Script:RunDir = New-RunDirectory
$Script:Step = 0

function Write-AgentLog {
    param([string]$Message)
    $line = "$(Get-Date -Format o) $Message"
    Add-Content -Path (Join-Path $Script:RunDir "agent.log") -Value $line
}

function Get-ScreenInfo {
    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $primary = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $cursor = New-Object NativeWinGui+POINT
    [NativeWinGui]::GetCursorPos([ref]$cursor) | Out-Null
    $sb = New-Object System.Text.StringBuilder 512
    [NativeWinGui]::GetWindowText([NativeWinGui]::GetForegroundWindow(), $sb, $sb.Capacity) | Out-Null
    return [ordered]@{
        virtual = [ordered]@{
            x = $bounds.X
            y = $bounds.Y
            width = $bounds.Width
            height = $bounds.Height
        }
        primary = [ordered]@{
            x = $primary.X
            y = $primary.Y
            width = $primary.Width
            height = $primary.Height
        }
        cursor = [ordered]@{
            x = $cursor.X
            y = $cursor.Y
        }
        activeWindowTitle = $sb.ToString()
        runDir = $Script:RunDir
    }
}

function Get-WindowTitle {
    param([IntPtr]$Hwnd)
    $len = [NativeWinGui]::GetWindowTextLength($Hwnd)
    if ($len -le 0) {
        return ""
    }
    $sb = New-Object System.Text.StringBuilder ($len + 1)
    [NativeWinGui]::GetWindowText($Hwnd, $sb, $sb.Capacity) | Out-Null
    return $sb.ToString()
}

function Get-WindowClassName {
    param([IntPtr]$Hwnd)
    $sb = New-Object System.Text.StringBuilder 256
    [NativeWinGui]::GetClassName($Hwnd, $sb, $sb.Capacity) | Out-Null
    return $sb.ToString()
}

function Convert-Rect {
    param([NativeWinGui+RECT]$Rect)
    return [ordered]@{
        left = $Rect.Left
        top = $Rect.Top
        right = $Rect.Right
        bottom = $Rect.Bottom
        width = $Rect.Right - $Rect.Left
        height = $Rect.Bottom - $Rect.Top
    }
}

function Get-TopLevelWindows {
    param([switch]$IncludeUntitled)
    $nativeWindows = [NativeWinGui]::EnumerateTopLevelWindows([bool]$IncludeUntitled)
    return @($nativeWindows | ForEach-Object {
        [ordered]@{
            hwnd = $_.Hwnd
            title = $_.Title
            className = $_.ClassName
            visible = $_.Visible
            rect = Convert-Rect $_.Rect
        }
    })
}

function Resolve-WindowHandle {
    param(
        $Hwnd,
        [string]$TitleContains,
        [string]$ClassNameContains,
        [switch]$IncludeUntitled,
        [switch]$RequireMatch
    )
    if ($null -ne $Hwnd -and ![string]::IsNullOrWhiteSpace([string]$Hwnd) -and [Int64]$Hwnd -ne 0) {
        return [IntPtr]::new([Int64]$Hwnd)
    }
    if (![string]::IsNullOrWhiteSpace($TitleContains) -or ![string]::IsNullOrWhiteSpace($ClassNameContains)) {
        $match = Get-TopLevelWindows -IncludeUntitled:$IncludeUntitled | Where-Object {
            $titleOk = $true
            $classOk = $true
            if (![string]::IsNullOrWhiteSpace($TitleContains)) {
                $titleOk = $_.title -like "*$TitleContains*"
            }
            if (![string]::IsNullOrWhiteSpace($ClassNameContains)) {
                $classOk = $_.className -like "*$ClassNameContains*"
            }
            $titleOk -and $classOk
        } | Select-Object -First 1
        if ($null -ne $match) {
            return [IntPtr]::new([Int64]$match.hwnd)
        }
    }
    if ($RequireMatch) {
        throw "Window not found"
    }
    return [NativeWinGui]::GetForegroundWindow()
}

function Wait-WindowHandle {
    param(
        [string]$TitleContains,
        [string]$ClassNameContains,
        [int]$TimeoutMs = 10000,
        [int]$IntervalMs = 250,
        [switch]$IncludeUntitled
    )
    if ([string]::IsNullOrWhiteSpace($TitleContains) -and [string]::IsNullOrWhiteSpace($ClassNameContains)) {
        throw "TitleContains or ClassNameContains is required"
    }
    if ($TimeoutMs -lt 0) {
        throw "TimeoutMs must be non-negative"
    }
    if ($IntervalMs -le 0) {
        throw "IntervalMs must be positive"
    }
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
    do {
        $match = Get-TopLevelWindows -IncludeUntitled:$IncludeUntitled | Where-Object {
            $titleOk = $true
            $classOk = $true
            if (![string]::IsNullOrWhiteSpace($TitleContains)) {
                $titleOk = $_.title -like "*$TitleContains*"
            }
            if (![string]::IsNullOrWhiteSpace($ClassNameContains)) {
                $classOk = $_.className -like "*$ClassNameContains*"
            }
            $titleOk -and $classOk
        } | Select-Object -First 1
        if ($null -ne $match) {
            return [IntPtr]::new([Int64]$match.hwnd)
        }
        Start-Sleep -Milliseconds $IntervalMs
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Window not found: $TitleContains $ClassNameContains"
}

function Set-WindowForeground {
    param(
        [IntPtr]$Handle,
        [int]$ShowCommand = [NativeWinGui]::SW_RESTORE
    )
    [NativeWinGui]::ShowWindow($Handle, $ShowCommand) | Out-Null
    Start-Sleep -Milliseconds 80

    $foreground = [NativeWinGui]::GetForegroundWindow()
    $unused = [uint32]0
    $foregroundThread = [NativeWinGui]::GetWindowThreadProcessId($foreground, [ref]$unused)
    $targetThread = [NativeWinGui]::GetWindowThreadProcessId($Handle, [ref]$unused)
    $currentThread = [NativeWinGui]::GetCurrentThreadId()

    $attachedForeground = $false
    $attachedTarget = $false
    try {
        if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
            $attachedForeground = [NativeWinGui]::AttachThreadInput($currentThread, $foregroundThread, $true)
        }
        if ($targetThread -ne 0 -and $targetThread -ne $currentThread) {
            $attachedTarget = [NativeWinGui]::AttachThreadInput($currentThread, $targetThread, $true)
        }
        [NativeWinGui]::BringWindowToTop($Handle) | Out-Null
        [NativeWinGui]::SetActiveWindow($Handle) | Out-Null
        [NativeWinGui]::SetForegroundWindow($Handle) | Out-Null
    } finally {
        if ($attachedTarget) {
            [NativeWinGui]::AttachThreadInput($currentThread, $targetThread, $false) | Out-Null
        }
        if ($attachedForeground) {
            [NativeWinGui]::AttachThreadInput($currentThread, $foregroundThread, $false) | Out-Null
        }
    }

    Start-Sleep -Milliseconds 250
    return [NativeWinGui]::GetForegroundWindow() -eq $Handle
}

function Save-Screenshot {
    param([string]$Label = "shot")
    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $Script:Step += 1
        $name = "{0:D5}-{1}.png" -f $Script:Step, $Label
        $path = Join-Path $Script:RunDir $name
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = $path
            width = $bounds.Width
            height = $bounds.Height
            step = $Script:Step
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Send-Json {
    param(
        [System.Net.HttpListenerContext]$Context,
        [object]$Object,
        [int]$StatusCode = 200
    )
    $json = $Object | ConvertTo-Json -Depth 12 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "application/json; charset=utf-8"
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Read-JsonBody {
    param([System.Net.HttpListenerRequest]$Request)
    if (!$Request.HasEntityBody) {
        return @{}
    }
    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try {
        $text = $reader.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($text)) {
            return @{}
        }
        return $text | ConvertFrom-Json
    } finally {
        $reader.Dispose()
    }
}

function Invoke-Click {
    param(
        [int]$X,
        [int]$Y,
        [int]$Clicks = 1,
        [int]$DelayMs = 80
    )
    [NativeWinGui]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 60
    for ($i = 0; $i -lt $Clicks; $i++) {
        [NativeWinGui]::mouse_event([NativeWinGui]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 30
        [NativeWinGui]::mouse_event([NativeWinGui]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
        if ($i -lt ($Clicks - 1)) {
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

function Invoke-TypeText {
    param(
        [string]$Text,
        [switch]$Raw
    )
    $value = $Text
    if (!$Raw) {
        $value = Convert-EscapedText $value
    }
    [System.Windows.Forms.Clipboard]::SetText($value)
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait("^v")
}

function Convert-EscapedText {
    param([string]$Text)
    if ($null -eq $Text) {
        return ""
    }
    $value = $Text
    $value = $value.Replace("\r\n", "`r`n")
    $value = $value.Replace("\n", "`n")
    $value = $value.Replace("\r", "`r")
    $value = $value.Replace("\t", "`t")
    return $value
}

function Invoke-Key {
    param([string]$Key)
    Send-VirtualKeyStroke -Key $Key
}

function Invoke-Hotkey {
    param([string[]]$Keys)
    if ($null -eq $Keys -or $Keys.Count -eq 0) {
        throw "Hotkey must include at least one key"
    }
    $vks = @($Keys | ForEach-Object { Resolve-VirtualKey $_ })
    foreach ($vk in $vks) {
        Send-VirtualKeyCode -VirtualKey $vk -KeyUp:$false
        Start-Sleep -Milliseconds 30
    }
    for ($i = $vks.Count - 1; $i -ge 0; $i--) {
        Send-VirtualKeyCode -VirtualKey $vks[$i] -KeyUp:$true
        Start-Sleep -Milliseconds 30
    }
}

function Resolve-VirtualKey {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) {
        throw "Key must not be empty"
    }
    $k = $Key.Trim()
    $upper = $k.ToUpperInvariant()
    $map = @{
        ENTER = 0x0D
        RETURN = 0x0D
        TAB = 0x09
        ESC = 0x1B
        ESCAPE = 0x1B
        SPACE = 0x20
        LEFT = 0x25
        UP = 0x26
        RIGHT = 0x27
        DOWN = 0x28
        BACKSPACE = 0x08
        DELETE = 0x2E
        HOME = 0x24
        END = 0x23
        PAGEUP = 0x21
        PAGEDOWN = 0x22
        ALT = 0x12
        MENU = 0x12
        CTRL = 0x11
        CONTROL = 0x11
        SHIFT = 0x10
    }
    if ($map.ContainsKey($upper)) {
        return [UInt16]$map[$upper]
    }
    if ($upper -match '^F([1-9]|1[0-9]|2[0-4])$') {
        return [UInt16](0x70 + [int]$Matches[1] - 1)
    }
    if ($upper.Length -eq 1) {
        $ch = [char]$upper[0]
        if (($ch -ge [char]'A' -and $ch -le [char]'Z') -or ($ch -ge [char]'0' -and $ch -le [char]'9')) {
            return [UInt16][int]$ch
        }
    }
    throw "Unsupported virtual key: $Key"
}

function Send-VirtualKeyCode {
    param(
        [UInt16]$VirtualKey,
        [switch]$KeyUp
    )
    $sent = [NativeWinGui]::SendVirtualKey($VirtualKey, [bool]$KeyUp)
    if ($sent -ne 1) {
        [NativeWinGui]::KeybdEventVirtualKey($VirtualKey, [bool]$KeyUp)
    }
}

function Send-VirtualKeyStroke {
    param([string]$Key)
    $vk = Resolve-VirtualKey $Key
    Send-VirtualKeyCode -VirtualKey $vk
    Start-Sleep -Milliseconds 40
    Send-VirtualKeyCode -VirtualKey $vk -KeyUp
}

function Invoke-WithScreenshots {
    param(
        [string]$Label,
        [scriptblock]$Action,
        [int]$AfterDelayMs = 250
    )
    $before = Save-Screenshot "$Label-before"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Action
    Start-Sleep -Milliseconds $AfterDelayMs
    $sw.Stop()
    $after = Save-Screenshot "$Label-after"
    return [ordered]@{
        ok = $true
        label = $Label
        durationMs = $sw.ElapsedMilliseconds
        before = $before
        after = $after
        screen = Get-ScreenInfo
    }
}

function Convert-UiaRect {
    param($Rect)
    if ($Rect.IsEmpty) {
        return $null
    }
    return [ordered]@{
        left = [int]$Rect.Left
        top = [int]$Rect.Top
        right = [int]$Rect.Right
        bottom = [int]$Rect.Bottom
        width = [int]$Rect.Width
        height = [int]$Rect.Height
    }
}

function Convert-UiaElement {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [int]$Depth = 0
    )
    if ($null -eq $Element) {
        return $null
    }
    $controlType = $Element.Current.ControlType
    return [ordered]@{
        name = $Element.Current.Name
        automationId = $Element.Current.AutomationId
        className = $Element.Current.ClassName
        controlType = $controlType.ProgrammaticName
        localizedControlType = $Element.Current.LocalizedControlType
        processId = $Element.Current.ProcessId
        nativeWindowHandle = $Element.Current.NativeWindowHandle
        isEnabled = $Element.Current.IsEnabled
        isOffscreen = $Element.Current.IsOffscreen
        hasKeyboardFocus = $Element.Current.HasKeyboardFocus
        boundingRectangle = Convert-UiaRect $Element.Current.BoundingRectangle
        depth = $Depth
    }
}

function Get-UiaRootElement {
    param(
        $Hwnd,
        [string]$WindowTitleContains
    )
    $handle = Resolve-WindowHandle -Hwnd $Hwnd -TitleContains $WindowTitleContains -RequireMatch:$false
    if ($handle -eq [IntPtr]::Zero) {
        return [System.Windows.Automation.AutomationElement]::RootElement
    }
    return [System.Windows.Automation.AutomationElement]::FromHandle($handle)
}

function New-UiaCondition {
    param($Body)
    $conditions = New-Object System.Collections.Generic.List[System.Windows.Automation.Condition]
    if ($null -ne $Body.name -and ![string]::IsNullOrWhiteSpace([string]$Body.name)) {
        $conditions.Add((New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty, [string]$Body.name))) | Out-Null
    }
    if ($null -ne $Body.automationId -and ![string]::IsNullOrWhiteSpace([string]$Body.automationId)) {
        $conditions.Add((New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::AutomationIdProperty, [string]$Body.automationId))) | Out-Null
    }
    if ($null -ne $Body.controlType -and ![string]::IsNullOrWhiteSpace([string]$Body.controlType)) {
        $typeName = [string]$Body.controlType
        if ($typeName -notlike "ControlType.*") {
            $typeName = "ControlType.$typeName"
        }
        $controlType = $null
        foreach ($field in [System.Windows.Automation.ControlType].GetFields()) {
            if ($field.FieldType -eq [System.Windows.Automation.ControlType]) {
                $candidate = $field.GetValue($null)
                if ($candidate.ProgrammaticName -eq $typeName -or $field.Name -eq [string]$Body.controlType) {
                    $controlType = $candidate
                    break
                }
            }
        }
        if ($null -ne $controlType) {
            $conditions.Add((New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $controlType))) | Out-Null
        }
    }
    if ($conditions.Count -eq 0) {
        return [System.Windows.Automation.Condition]::TrueCondition
    }
    if ($conditions.Count -eq 1) {
        return $conditions[0]
    }
    return New-Object System.Windows.Automation.AndCondition ([System.Windows.Automation.Condition[]]$conditions.ToArray())
}

function Find-UiaElements {
    param(
        $Body,
        [int]$Limit = 50
    )
    $root = Get-UiaRootElement -Hwnd $Body.hwnd -WindowTitleContains ([string]$Body.windowTitleContains)
    $condition = New-UiaCondition $Body
    $scope = [System.Windows.Automation.TreeScope]::Descendants
    if ($null -ne $Body.childrenOnly -and [bool]$Body.childrenOnly) {
        $scope = [System.Windows.Automation.TreeScope]::Children
    }
    $found = $root.FindAll($scope, $condition)
    $items = New-Object System.Collections.Generic.List[System.Windows.Automation.AutomationElement]
    for ($i = 0; $i -lt $found.Count -and $items.Count -lt $Limit; $i++) {
        $el = $found.Item($i)
        if ($null -ne $Body.nameContains -and ![string]::IsNullOrWhiteSpace([string]$Body.nameContains)) {
            if ($el.Current.Name -notlike "*$($Body.nameContains)*") {
                continue
            }
        }
        if ($null -ne $Body.classNameContains -and ![string]::IsNullOrWhiteSpace([string]$Body.classNameContains)) {
            if ($el.Current.ClassName -notlike "*$($Body.classNameContains)*") {
                continue
            }
        }
        if ($null -ne $Body.includeOffscreen -and ![bool]$Body.includeOffscreen -and $el.Current.IsOffscreen) {
            continue
        }
        if ($null -ne $Body.isEnabled -and [bool]$Body.isEnabled -ne $el.Current.IsEnabled) {
            continue
        }
        if ($null -ne $Body.enabled -and [bool]$Body.enabled -ne $el.Current.IsEnabled) {
            continue
        }
        $items.Add($el) | Out-Null
    }
    return @($items)
}

function Get-UiaTree {
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [int]$MaxDepth = 3,
        [int]$MaxNodes = 200
    )
    $script:UiaTreeCount = 0
    function Convert-Node {
        param(
            [System.Windows.Automation.AutomationElement]$Element,
            [int]$Depth
        )
        if ($script:UiaTreeCount -ge $MaxNodes) {
            return $null
        }
        $script:UiaTreeCount += 1
        $node = Convert-UiaElement -Element $Element -Depth $Depth
        $node.children = @()
        if ($Depth -lt $MaxDepth) {
            $children = $Element.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
            for ($i = 0; $i -lt $children.Count -and $script:UiaTreeCount -lt $MaxNodes; $i++) {
                $childNode = Convert-Node -Element $children.Item($i) -Depth ($Depth + 1)
                if ($null -ne $childNode) {
                    $node.children += $childNode
                }
            }
        }
        return $node
    }
    return Convert-Node -Element $Root -Depth 0
}

function Invoke-UiaElement {
    param([System.Windows.Automation.AutomationElement]$Element)
    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        $pattern.Invoke()
        return "invokePattern"
    }
    try {
        $Element.SetFocus()
    } catch {
        Write-AgentLog "uiaSetFocusWarning $($_.Exception.Message)"
    }
    $rect = $Element.Current.BoundingRectangle
    if ($rect.IsEmpty) {
        throw "Element has no clickable rectangle and no InvokePattern"
    }
    $x = [int]($rect.Left + ($rect.Width / 2))
    $y = [int]($rect.Top + ($rect.Height / 2))
    Invoke-Click -X $x -Y $y
    return "focusAndClick"
}

function Set-UiaElementText {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [string]$Text
    )
    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        if (!$pattern.Current.IsReadOnly) {
            $pattern.SetValue($Text)
            return "valuePattern"
        }
    }
    try {
        $Element.SetFocus()
    } catch {
        Write-AgentLog "uiaSetTextFocusWarning $($_.Exception.Message)"
        $rect = $Element.Current.BoundingRectangle
        if (!$rect.IsEmpty) {
            $x = [int]($rect.Left + ($rect.Width / 2))
            $y = [int]($rect.Top + ($rect.Height / 2))
            Invoke-Click -X $x -Y $y
        }
    }
    Invoke-Hotkey -Keys @("ctrl", "a")
    Invoke-TypeText -Text $Text
    return "focusClipboardPaste"
}

function Compare-Images {
    param(
        [string]$BeforePath,
        [string]$AfterPath,
        [int]$Step = 8,
        [int]$Threshold = 24
    )
    if (!(Test-Path $BeforePath)) {
        throw "Before image not found: $BeforePath"
    }
    if (!(Test-Path $AfterPath)) {
        throw "After image not found: $AfterPath"
    }
    $before = [System.Drawing.Bitmap]::FromFile($BeforePath)
    $after = [System.Drawing.Bitmap]::FromFile($AfterPath)
    try {
        if ($before.Width -ne $after.Width -or $before.Height -ne $after.Height) {
            throw "Image dimensions differ"
        }
        if ($Step -lt 1) {
            $Step = 1
        }
        $sampled = 0
        $changed = 0
        [Int64]$totalDelta = 0
        $maxDelta = 0
        for ($y = 0; $y -lt $before.Height; $y += $Step) {
            for ($x = 0; $x -lt $before.Width; $x += $Step) {
                $a = $before.GetPixel($x, $y)
                $b = $after.GetPixel($x, $y)
                $delta = [Math]::Abs([int]$a.R - [int]$b.R) + [Math]::Abs([int]$a.G - [int]$b.G) + [Math]::Abs([int]$a.B - [int]$b.B)
                $sampled += 1
                $totalDelta += $delta
                if ($delta -gt $maxDelta) {
                    $maxDelta = $delta
                }
                if ($delta -ge $Threshold) {
                    $changed += 1
                }
            }
        }
        $changedRatio = 0
        $averageDelta = 0
        if ($sampled -gt 0) {
            $changedRatio = $changed / $sampled
            $averageDelta = $totalDelta / $sampled
        }
        return [ordered]@{
            before = $BeforePath
            after = $AfterPath
            width = $before.Width
            height = $before.Height
            step = $Step
            threshold = $Threshold
            sampledPixels = $sampled
            changedPixels = $changed
            changedRatio = $changedRatio
            averageDelta = $averageDelta
            maxDelta = $maxDelta
        }
    } finally {
        $before.Dispose()
        $after.Dispose()
    }
}

function Find-ImageTemplate {
    param(
        [string]$ImagePath,
        [string]$TemplatePath,
        [int]$Step = 4,
        [int]$PixelStep = 4,
        $Left,
        $Top,
        $Right,
        $Bottom
    )
    if (!(Test-Path $ImagePath)) {
        throw "Image not found: $ImagePath"
    }
    if (!(Test-Path $TemplatePath)) {
        throw "Template not found: $TemplatePath"
    }
    if ($Step -lt 1) { $Step = 1 }
    if ($PixelStep -lt 1) { $PixelStep = 1 }
    $image = [System.Drawing.Bitmap]::FromFile($ImagePath)
    $template = [System.Drawing.Bitmap]::FromFile($TemplatePath)
    try {
        if ($template.Width -gt $image.Width -or $template.Height -gt $image.Height) {
            throw "Template is larger than image"
        }
        $searchLeft = 0
        $searchTop = 0
        $searchRight = $image.Width
        $searchBottom = $image.Height
        if ($null -ne $Left -and ![string]::IsNullOrWhiteSpace([string]$Left)) { $searchLeft = [Math]::Max(0, [int]$Left) }
        if ($null -ne $Top -and ![string]::IsNullOrWhiteSpace([string]$Top)) { $searchTop = [Math]::Max(0, [int]$Top) }
        if ($null -ne $Right -and ![string]::IsNullOrWhiteSpace([string]$Right)) { $searchRight = [Math]::Min($image.Width, [int]$Right) }
        if ($null -ne $Bottom -and ![string]::IsNullOrWhiteSpace([string]$Bottom)) { $searchBottom = [Math]::Min($image.Height, [int]$Bottom) }
        $maxX = $searchRight - $template.Width
        $maxY = $searchBottom - $template.Height
        if ($maxX -lt $searchLeft -or $maxY -lt $searchTop) {
            throw "Search region is smaller than template"
        }
        $bestX = $searchLeft
        $bestY = $searchTop
        [double]$bestAverageDelta = [double]::PositiveInfinity
        $positions = 0
        $templateSamples = 0
        for ($ty = 0; $ty -lt $template.Height; $ty += $PixelStep) {
            for ($tx = 0; $tx -lt $template.Width; $tx += $PixelStep) {
                $templateSamples += 1
            }
        }
        for ($y = $searchTop; $y -le $maxY; $y += $Step) {
            for ($x = $searchLeft; $x -le $maxX; $x += $Step) {
                $positions += 1
                [Int64]$totalDelta = 0
                for ($ty = 0; $ty -lt $template.Height; $ty += $PixelStep) {
                    for ($tx = 0; $tx -lt $template.Width; $tx += $PixelStep) {
                        $a = $image.GetPixel($x + $tx, $y + $ty)
                        $b = $template.GetPixel($tx, $ty)
                        $totalDelta += [Math]::Abs([int]$a.R - [int]$b.R) + [Math]::Abs([int]$a.G - [int]$b.G) + [Math]::Abs([int]$a.B - [int]$b.B)
                    }
                }
                $averageDelta = $totalDelta / $templateSamples
                if ($averageDelta -lt $bestAverageDelta) {
                    $bestAverageDelta = $averageDelta
                    $bestX = $x
                    $bestY = $y
                }
            }
        }
        $confidence = [Math]::Max([double]0, [double]1 - ([double]$bestAverageDelta / [double]765))
        return [ordered]@{
            image = $ImagePath
            template = $TemplatePath
            x = $bestX
            y = $bestY
            centerX = [int]($bestX + ($template.Width / 2))
            centerY = [int]($bestY + ($template.Height / 2))
            width = $template.Width
            height = $template.Height
            step = $Step
            pixelStep = $PixelStep
            sampledTemplatePixels = $templateSamples
            searchedPositions = $positions
            averageDelta = $bestAverageDelta
            confidence = $confidence
            searchRegion = [ordered]@{
                left = $searchLeft
                top = $searchTop
                right = $searchRight
                bottom = $searchBottom
            }
        }
    } finally {
        $image.Dispose()
        $template.Dispose()
    }
}

function Test-ValuePresent {
    param($Value)
    return $null -ne $Value -and ![string]::IsNullOrWhiteSpace([string]$Value)
}

function New-ImageCrop {
    param(
        [string]$ImagePath,
        $Left,
        $Top,
        $Right,
        $Bottom,
        [string]$Label = "ocr-crop"
    )
    $hasCrop = (Test-ValuePresent $Left) -or (Test-ValuePresent $Top) -or (Test-ValuePresent $Right) -or (Test-ValuePresent $Bottom)
    if (!$hasCrop) {
        return $null
    }

    $source = [System.Drawing.Bitmap]::FromFile($ImagePath)
    $cropped = $null
    try {
        $cropLeft = 0
        $cropTop = 0
        $cropRight = $source.Width
        $cropBottom = $source.Height
        if (Test-ValuePresent $Left) { $cropLeft = [Math]::Max(0, [int]$Left) }
        if (Test-ValuePresent $Top) { $cropTop = [Math]::Max(0, [int]$Top) }
        if (Test-ValuePresent $Right) { $cropRight = [Math]::Min($source.Width, [int]$Right) }
        if (Test-ValuePresent $Bottom) { $cropBottom = [Math]::Min($source.Height, [int]$Bottom) }
        if ($cropRight -le $cropLeft -or $cropBottom -le $cropTop) {
            throw "Crop bounds are empty"
        }

        $rect = New-Object System.Drawing.Rectangle $cropLeft, $cropTop, ($cropRight - $cropLeft), ($cropBottom - $cropTop)
        $cropped = $source.Clone($rect, $source.PixelFormat)
        $Script:Step += 1
        $name = "{0:D5}-{1}.png" -f $Script:Step, $Label
        $path = Join-Path $Script:RunDir $name
        $cropped.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

        return [ordered]@{
            path = $path
            left = $cropLeft
            top = $cropTop
            right = $cropRight
            bottom = $cropBottom
            width = $cropRight - $cropLeft
            height = $cropBottom - $cropTop
        }
    } finally {
        if ($null -ne $cropped) { $cropped.Dispose() }
        $source.Dispose()
    }
}

function Find-OcrBackend {
    $candidates = @(
        "tesseract.exe",
        "tesseract",
        "C:\Program Files\Tesseract-OCR\tesseract.exe",
        "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"
    )
    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return [ordered]@{
                ok = $true
                engine = "tesseract"
                path = $cmd.Source
            }
        }
        if (Test-Path $candidate) {
            return [ordered]@{
                ok = $true
                engine = "tesseract"
                path = $candidate
            }
        }
    }
    return [ordered]@{
        ok = $false
        engine = $null
        path = $null
        error = "No OCR backend found. Install Tesseract OCR and ensure tesseract.exe is on PATH."
    }
}

function Invoke-Ocr {
    param(
        [string]$ImagePath,
        [string]$Language = "eng",
        [int]$Psm = 6,
        $Left,
        $Top,
        $Right,
        $Bottom
    )
    if ([string]::IsNullOrWhiteSpace($ImagePath)) {
        $shot = Save-Screenshot "ocr-source"
        $ImagePath = $shot.path
    }
    if (!(Test-Path $ImagePath)) {
        throw "OCR image not found: $ImagePath"
    }
    $backend = Find-OcrBackend
    if (!$backend.ok) {
        return [ordered]@{
            ok = $false
            backend = $backend
            image = $ImagePath
            processedImage = $ImagePath
            crop = $null
            text = ""
            words = @()
        }
    }

    $crop = New-ImageCrop -ImagePath $ImagePath -Left $Left -Top $Top -Right $Right -Bottom $Bottom
    $processedImage = $ImagePath
    $offsetX = 0
    $offsetY = 0
    if ($null -ne $crop) {
        $processedImage = $crop.path
        $offsetX = [int]$crop.left
        $offsetY = [int]$crop.top
    }

    $Script:Step += 1
    $outBase = Join-Path $Script:RunDir ("{0:D5}-ocr" -f $Script:Step)
    $arguments = @(
        $processedImage,
        $outBase,
        "-l", $Language,
        "--psm", [string]$Psm,
        "tsv"
    )
    $process = Start-Process -FilePath $backend.path -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
    $tsvPath = "$outBase.tsv"
    if ($process.ExitCode -ne 0 -or !(Test-Path $tsvPath)) {
        return [ordered]@{
            ok = $false
            backend = $backend
            image = $ImagePath
            processedImage = $processedImage
            crop = $crop
            exitCode = $process.ExitCode
            text = ""
            words = @()
            error = "OCR backend failed"
        }
    }

    $rows = Import-Csv -Delimiter "`t" -Path $tsvPath
    $words = @()
    foreach ($row in $rows) {
        $text = [string]$row.text
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        $confidence = 0
        [double]::TryParse([string]$row.conf, [ref]$confidence) | Out-Null
        if ($confidence -lt 0) {
            continue
        }
        $localLeft = [int]$row.left
        $localTop = [int]$row.top
        $width = [int]$row.width
        $height = [int]$row.height
        $screenLeft = $localLeft + $offsetX
        $screenTop = $localTop + $offsetY
        $words += [ordered]@{
            text = $text
            confidence = $confidence
            left = $screenLeft
            top = $screenTop
            width = $width
            height = $height
            right = $screenLeft + $width
            bottom = $screenTop + $height
            centerX = [int]($screenLeft + ($width / 2))
            centerY = [int]($screenTop + ($height / 2))
            localLeft = $localLeft
            localTop = $localTop
        }
    }
    $fullText = ($words | ForEach-Object { $_.text }) -join " "
    return [ordered]@{
        ok = $true
        backend = $backend
        image = $ImagePath
        processedImage = $processedImage
        crop = $crop
        language = $Language
        psm = $Psm
        text = $fullText
        words = $words
        tsv = $tsvPath
    }
}

function Find-OcrText {
    param(
        [string]$ImagePath,
        [string]$Text,
        [string]$Language = "eng",
        [int]$Psm = 6,
        $Left,
        $Top,
        $Right,
        $Bottom
    )
    $ocr = Invoke-Ocr -ImagePath $ImagePath -Language $Language -Psm $Psm -Left $Left -Top $Top -Right $Right -Bottom $Bottom
    if (!$ocr.ok) {
        return [ordered]@{ ok = $false; ocr = $ocr; matches = @() }
    }
    $matches = @()
    $needle = [string]$Text
    foreach ($word in $ocr.words) {
        if ($word.text -like "*$needle*") {
            $matches += $word
        }
    }
    $ok = $matches.Count -gt 0 -or $ocr.text -like "*$needle*"
    return [ordered]@{
        ok = $ok
        query = $needle
        ocr = $ocr
        matches = $matches
    }
}

function Select-OcrClickTarget {
    param(
        $Found,
        [double]$MinConfidence = 0
    )
    $matches = @($Found.matches | Where-Object { [double]$_.confidence -ge $MinConfidence } | Sort-Object -Property confidence -Descending)
    if ($matches.Count -lt 1) {
        throw "OCR text found only as full text or below confidence threshold. Use a single visible word or lower minConfidence."
    }
    return $matches[0]
}

function Invoke-OcrClickText {
    param(
        [string]$ImagePath,
        [string]$Text,
        [string]$Language = "eng",
        [int]$Psm = 6,
        $Left,
        $Top,
        $Right,
        $Bottom,
        [double]$MinConfidence = 0
    )
    $found = Find-OcrText -ImagePath $ImagePath -Text $Text -Language $Language -Psm $Psm -Left $Left -Top $Top -Right $Right -Bottom $Bottom
    if (!$found.ok) {
        throw "OCR text not found: $Text"
    }
    $target = Select-OcrClickTarget -Found $found -MinConfidence $MinConfidence
    $result = Invoke-WithScreenshots "ocr-click-text" {
        Invoke-Click -X ([int]$target.centerX) -Y ([int]$target.centerY)
    }
    $result.query = $Text
    $result.target = $target
    $result.found = $found
    return $result
}

function Test-Expectation {
    param($Expect)
    if ($null -eq $Expect) {
        return [ordered]@{ ok = $true; checks = @() }
    }
    $checks = @()
    $allOk = $true

    if ($null -ne $Expect.activeWindowTitleContains -and ![string]::IsNullOrWhiteSpace([string]$Expect.activeWindowTitleContains)) {
        $screen = Get-ScreenInfo
        $needle = [string]$Expect.activeWindowTitleContains
        $ok = $screen.activeWindowTitle -like "*$needle*"
        if (!$ok) { $allOk = $false }
        $checks += [ordered]@{
            type = "activeWindowTitleContains"
            ok = $ok
            expected = $needle
            actual = $screen.activeWindowTitle
        }
    }

    if ($null -ne $Expect.uiaExists) {
        $body = $Expect.uiaExists
        $limit = 1
        if ($null -ne $body.limit) { $limit = [int]$body.limit }
        $elements = Find-UiaElements -Body $body -Limit $limit
        $ok = $elements.Count -gt 0
        if (!$ok) { $allOk = $false }
        $first = $null
        if ($elements.Count -gt 0) {
            $first = Convert-UiaElement -Element $elements[0]
        }
        $checks += [ordered]@{
            type = "uiaExists"
            ok = $ok
            count = $elements.Count
            first = $first
        }
    }

    if ($null -ne $Expect.windowExists) {
        $body = $Expect.windowExists
        $includeUntitled = $false
        if ($null -ne $body.includeUntitled) { $includeUntitled = [bool]$body.includeUntitled }
        $titleContains = [string]$body.titleContains
        $classNameContains = [string]$body.classNameContains
        $matches = @(Get-TopLevelWindows -IncludeUntitled:($includeUntitled) | Where-Object {
            $titleOk = $true
            $classOk = $true
            if (![string]::IsNullOrWhiteSpace($titleContains)) {
                $titleOk = $_.title -like "*$titleContains*"
            }
            if (![string]::IsNullOrWhiteSpace($classNameContains)) {
                $classOk = $_.className -like "*$classNameContains*"
            }
            $titleOk -and $classOk
        })
        $ok = $matches.Count -gt 0
        if (!$ok) { $allOk = $false }
        $checks += [ordered]@{
            type = "windowExists"
            ok = $ok
            count = $matches.Count
            first = if ($matches.Count -gt 0) { $matches[0] } else { $null }
        }
    }

    if ($null -ne $Expect.fileExists) {
        $body = $Expect.fileExists
        $path = [string]$body
        if ($null -ne $body.path) { $path = [string]$body.path }
        $exists = ![string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)
        if (!$exists) { $allOk = $false }
        $checks += [ordered]@{
            type = "fileExists"
            ok = $exists
            path = $path
        }
    }

    if ($null -ne $Expect.fileTextContains) {
        $body = $Expect.fileTextContains
        $path = [string]$body.path
        $needle = [string]$body.text
        $exists = ![string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)
        $text = ""
        if ($exists) {
            $text = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        }
        $ok = $exists -and $text -like "*$needle*"
        if (!$ok) { $allOk = $false }
        $checks += [ordered]@{
            type = "fileTextContains"
            ok = $ok
            path = $path
            expected = $needle
            exists = $exists
        }
    }

    if ($null -ne $Expect.diff) {
        $body = $Expect.diff
        $step = 8
        $threshold = 24
        if ($null -ne $body.step) { $step = [int]$body.step }
        if ($null -ne $body.threshold) { $threshold = [int]$body.threshold }
        $diff = Compare-Images -BeforePath ([string]$body.before) -AfterPath ([string]$body.after) -Step $step -Threshold $threshold
        $minChangedRatio = 0
        if ($null -ne $body.minChangedRatio) { $minChangedRatio = [double]$body.minChangedRatio }
        $ok = $diff.changedRatio -ge $minChangedRatio
        if (!$ok) { $allOk = $false }
        $checks += [ordered]@{
            type = "diff"
            ok = $ok
            minChangedRatio = $minChangedRatio
            diff = $diff
        }
    }

    if ($null -ne $Expect.ocrTextContains) {
        $body = $Expect.ocrTextContains
        $language = "eng"
        $psm = 6
        if ($null -ne $body.language) { $language = [string]$body.language }
        if ($null -ne $body.psm) { $psm = [int]$body.psm }
        $found = Find-OcrText `
            -ImagePath ([string]$body.image) `
            -Text ([string]$body.text) `
            -Language $language `
            -Psm $psm `
            -Left $body.left `
            -Top $body.top `
            -Right $body.right `
            -Bottom $body.bottom
        if (!$found.ok) { $allOk = $false }
        $checks += [ordered]@{
            type = "ocrTextContains"
            ok = $found.ok
            query = [string]$body.text
            found = $found
        }
    }

    return [ordered]@{
        ok = $allOk
        checks = $checks
    }
}

function Invoke-AgentAction {
    param($Body)
    $action = [string]$Body.action
    switch ($action) {
        "run" {
            $file = [string]$Body.file
            $arguments = [string]$Body.arguments
            if ([string]::IsNullOrWhiteSpace($file)) { throw "file is required" }
            if ([string]::IsNullOrWhiteSpace($arguments)) {
                $proc = Start-Process -FilePath $file -PassThru
            } else {
                $proc = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
            }
            Start-Sleep -Milliseconds 500
            $result = [ordered]@{ action = $action; processId = $proc.Id; file = $file; arguments = $arguments }
            if ($null -ne $Body.waitForWindowTitleContains -and ![string]::IsNullOrWhiteSpace([string]$Body.waitForWindowTitleContains)) {
                $timeoutMs = 10000
                $intervalMs = 250
                if ($null -ne $Body.waitTimeoutMs) { $timeoutMs = [int]$Body.waitTimeoutMs }
                if ($null -ne $Body.waitIntervalMs) { $intervalMs = [int]$Body.waitIntervalMs }
                $handle = Wait-WindowHandle `
                    -TitleContains ([string]$Body.waitForWindowTitleContains) `
                    -ClassNameContains ([string]$Body.waitForWindowClassNameContains) `
                    -TimeoutMs $timeoutMs `
                    -IntervalMs $intervalMs `
                    -IncludeUntitled:([bool]$Body.waitIncludeUntitled)
                $result.waitedWindow = [ordered]@{
                    hwnd = $handle.ToInt64()
                    title = Get-WindowTitle $handle
                    className = Get-WindowClassName $handle
                }
            }
            return $result
        }
        "click" {
            $clicks = 1
            if ($null -ne $Body.clicks) { $clicks = [int]$Body.clicks }
            Invoke-Click -X ([int]$Body.x) -Y ([int]$Body.y) -Clicks $clicks
            return [ordered]@{ action = $action; x = [int]$Body.x; y = [int]$Body.y; clicks = $clicks }
        }
        "type" {
            $raw = $false
            if ($null -ne $Body.raw) { $raw = [bool]$Body.raw }
            Invoke-TypeText -Text ([string]$Body.text) -Raw:$raw
            return [ordered]@{ action = $action; textLength = ([string]$Body.text).Length; raw = $raw }
        }
        "key" {
            Invoke-Key -Key ([string]$Body.key)
            return [ordered]@{ action = $action; key = [string]$Body.key }
        }
        "hotkey" {
            Invoke-Hotkey -Keys ([string[]]$Body.keys)
            return [ordered]@{ action = $action; keys = @([string[]]$Body.keys) }
        }
        "activate_window" {
            $handle = Resolve-WindowHandle -Hwnd $Body.hwnd -TitleContains ([string]$Body.titleContains) -ClassNameContains ([string]$Body.classNameContains) -IncludeUntitled:([bool]$Body.includeUntitled) -RequireMatch
            $foreground = Set-WindowForeground -Handle $handle -ShowCommand ([NativeWinGui]::SW_RESTORE)
            return [ordered]@{ action = $action; hwnd = $handle.ToInt64(); foreground = $foreground }
        }
        "maximize_window" {
            $handle = Resolve-WindowHandle -Hwnd $Body.hwnd -TitleContains ([string]$Body.titleContains) -ClassNameContains ([string]$Body.classNameContains) -IncludeUntitled:([bool]$Body.includeUntitled) -RequireMatch
            $foreground = Set-WindowForeground -Handle $handle -ShowCommand ([NativeWinGui]::SW_MAXIMIZE)
            return [ordered]@{ action = $action; hwnd = $handle.ToInt64(); foreground = $foreground }
        }
        "close_window" {
            $handle = Resolve-WindowHandle -Hwnd $Body.hwnd -TitleContains ([string]$Body.titleContains) -ClassNameContains ([string]$Body.classNameContains) -IncludeUntitled:([bool]$Body.includeUntitled) -RequireMatch
            [NativeWinGui]::PostMessage($handle, [NativeWinGui]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            Start-Sleep -Milliseconds 250
            return [ordered]@{ action = $action; hwnd = $handle.ToInt64() }
        }
        "uia_click" {
            $elements = Find-UiaElements -Body $Body -Limit 1
            if ($elements.Count -lt 1) { throw "UIA element not found" }
            $elementInfo = Convert-UiaElement -Element $elements[0]
            $method = Invoke-UiaElement -Element $elements[0]
            return [ordered]@{ action = $action; method = $method; element = $elementInfo }
        }
        "uia_set_text" {
            $elements = Find-UiaElements -Body $Body -Limit 1
            if ($elements.Count -lt 1) { throw "UIA element not found" }
            $text = Convert-EscapedText ([string]$Body.text)
            $method = Set-UiaElementText -Element $elements[0] -Text $text
            return [ordered]@{ action = $action; method = $method; element = Convert-UiaElement -Element $elements[0] }
        }
        "ocr_click_text" {
            $language = "eng"
            $psm = 6
            $minConfidence = 0
            if ($null -ne $Body.language) { $language = [string]$Body.language }
            if ($null -ne $Body.psm) { $psm = [int]$Body.psm }
            if ($null -ne $Body.minConfidence) { $minConfidence = [double]$Body.minConfidence }
            return Invoke-OcrClickText `
                -ImagePath ([string]$Body.image) `
                -Text ([string]$Body.text) `
                -Language $language `
                -Psm $psm `
                -Left $Body.left `
                -Top $Body.top `
                -Right $Body.right `
                -Bottom $Body.bottom `
                -MinConfidence $minConfidence
        }
        default {
            throw "Unknown action: $action"
        }
    }
}

$prefix = "http://${HostName}:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-AgentLog "started prefix=$prefix runDir=$Script:RunDir"
Write-Host "win-gui-agent listening at $prefix"
Write-Host "runDir=$Script:RunDir"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
            $path = $ctx.Request.Url.AbsolutePath.TrimEnd("/")
            if ($path -eq "") { $path = "/" }
            Write-AgentLog "$($ctx.Request.HttpMethod) $path"

            switch ($path) {
                "/health" {
                    Send-Json $ctx ([ordered]@{
                        ok = $true
                        pid = $PID
                        time = (Get-Date -Format o)
                        runDir = $Script:RunDir
                    })
                }
                "/screen" {
                    Send-Json $ctx (Get-ScreenInfo)
                }
                "/screenshot" {
                    $shot = Save-Screenshot "manual"
                    Send-Json $ctx ([ordered]@{ ok = $true; screenshot = $shot; screen = Get-ScreenInfo })
                }
                "/click" {
                    $body = Read-JsonBody $ctx.Request
                    $clicks = 1
                    if ($null -ne $body.clicks) {
                        $clicks = [int]$body.clicks
                    }
                    $result = Invoke-WithScreenshots "click" {
                        Invoke-Click -X ([int]$body.x) -Y ([int]$body.y) -Clicks $clicks
                    }
                    Send-Json $ctx $result
                }
                "/double_click" {
                    $body = Read-JsonBody $ctx.Request
                    $result = Invoke-WithScreenshots "double-click" {
                        Invoke-Click -X ([int]$body.x) -Y ([int]$body.y) -Clicks 2
                    }
                    Send-Json $ctx $result
                }
                "/move" {
                    $body = Read-JsonBody $ctx.Request
                    [NativeWinGui]::SetCursorPos([int]$body.x, [int]$body.y) | Out-Null
                    Send-Json $ctx ([ordered]@{ ok = $true; screen = Get-ScreenInfo })
                }
                { $_ -eq "/type" -or $_ -eq "/text" } {
                    $body = Read-JsonBody $ctx.Request
                    $raw = $false
                    if ($null -ne $body.raw) { $raw = [bool]$body.raw }
                    $result = Invoke-WithScreenshots "type" {
                        Invoke-TypeText -Text ([string]$body.text) -Raw:$raw
                    }
                    Send-Json $ctx $result
                }
                "/key" {
                    $body = Read-JsonBody $ctx.Request
                    $result = Invoke-WithScreenshots "key" {
                        Invoke-Key -Key ([string]$body.key)
                    }
                    Send-Json $ctx $result
                }
                "/hotkey" {
                    $body = Read-JsonBody $ctx.Request
                    $result = Invoke-WithScreenshots "hotkey" {
                        Invoke-Hotkey -Keys ([string[]]$body.keys)
                    }
                    Send-Json $ctx $result
                }
                "/run" {
                    $body = Read-JsonBody $ctx.Request
                    $file = [string]$body.file
                    $arguments = [string]$body.arguments
                    if ([string]::IsNullOrWhiteSpace($file)) {
                        throw "file is required"
                    }
                    if ([string]::IsNullOrWhiteSpace($arguments)) {
                        $proc = Start-Process -FilePath $file -PassThru
                    } else {
                        $proc = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
                    }
                    Start-Sleep -Milliseconds 500
                    Send-Json $ctx ([ordered]@{
                        ok = $true
                        processId = $proc.Id
                        file = $file
                        arguments = $arguments
                        screen = Get-ScreenInfo
                    })
                }
                "/windows" {
                    $includeUntitled = $false
                    if ($ctx.Request.QueryString["includeUntitled"] -eq "1") {
                        $includeUntitled = $true
                    }
                    Send-Json $ctx ([ordered]@{
                        ok = $true
                        windows = @(Get-TopLevelWindows -IncludeUntitled:$includeUntitled)
                        screen = Get-ScreenInfo
                    })
                }
                "/active_window" {
                    $hWnd = [NativeWinGui]::GetForegroundWindow()
                    $rect = New-Object NativeWinGui+RECT
                    [NativeWinGui]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
                    Send-Json $ctx ([ordered]@{
                        ok = $true
                        window = [ordered]@{
                            hwnd = $hWnd.ToInt64()
                            title = Get-WindowTitle $hWnd
                            className = Get-WindowClassName $hWnd
                            rect = Convert-Rect $rect
                        }
                        screen = Get-ScreenInfo
                    })
                }
                "/activate_window" {
                    $body = Read-JsonBody $ctx.Request
                    $handle = Resolve-WindowHandle -Hwnd $body.hwnd -TitleContains ([string]$body.titleContains) -ClassNameContains ([string]$body.classNameContains) -IncludeUntitled:([bool]$body.includeUntitled) -RequireMatch
                    $foreground = Set-WindowForeground -Handle $handle -ShowCommand ([NativeWinGui]::SW_RESTORE)
                    Send-Json $ctx ([ordered]@{ ok = $true; hwnd = $handle.ToInt64(); foreground = $foreground; screen = Get-ScreenInfo })
                }
                "/maximize_window" {
                    $body = Read-JsonBody $ctx.Request
                    $handle = Resolve-WindowHandle -Hwnd $body.hwnd -TitleContains ([string]$body.titleContains) -ClassNameContains ([string]$body.classNameContains) -IncludeUntitled:([bool]$body.includeUntitled) -RequireMatch
                    $foreground = Set-WindowForeground -Handle $handle -ShowCommand ([NativeWinGui]::SW_MAXIMIZE)
                    Send-Json $ctx ([ordered]@{ ok = $true; hwnd = $handle.ToInt64(); foreground = $foreground; screen = Get-ScreenInfo })
                }
                "/close_window" {
                    $body = Read-JsonBody $ctx.Request
                    $handle = Resolve-WindowHandle -Hwnd $body.hwnd -TitleContains ([string]$body.titleContains) -ClassNameContains ([string]$body.classNameContains) -IncludeUntitled:([bool]$body.includeUntitled) -RequireMatch
                    [NativeWinGui]::PostMessage($handle, [NativeWinGui]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                    Start-Sleep -Milliseconds 250
                    Send-Json $ctx ([ordered]@{ ok = $true; hwnd = $handle.ToInt64(); screen = Get-ScreenInfo })
                }
                "/uia/tree" {
                    $body = Read-JsonBody $ctx.Request
                    $maxDepth = 3
                    $maxNodes = 200
                    if ($null -ne $body.maxDepth) { $maxDepth = [int]$body.maxDepth }
                    if ($null -ne $body.maxNodes) { $maxNodes = [int]$body.maxNodes }
                    $root = Get-UiaRootElement -Hwnd $body.hwnd -WindowTitleContains ([string]$body.windowTitleContains)
                    Send-Json $ctx ([ordered]@{
                        ok = $true
                        root = Get-UiaTree -Root $root -MaxDepth $maxDepth -MaxNodes $maxNodes
                    })
                }
                "/uia/find" {
                    $body = Read-JsonBody $ctx.Request
                    $limit = 50
                    if ($null -ne $body.limit) { $limit = [int]$body.limit }
                    $elements = Find-UiaElements -Body $body -Limit $limit
                    Send-Json $ctx ([ordered]@{
                        ok = $true
                        count = $elements.Count
                        elements = @($elements | ForEach-Object { Convert-UiaElement -Element $_ })
                    })
                }
                "/uia/click" {
                    $body = Read-JsonBody $ctx.Request
                    $elements = Find-UiaElements -Body $body -Limit 1
                    if ($elements.Count -lt 1) {
                        throw "UIA element not found"
                    }
                    $method = $null
                    $result = Invoke-WithScreenshots "uia-click" {
                        $script:uiaMethod = Invoke-UiaElement -Element $elements[0]
                    }
                    $method = $script:uiaMethod
                    $result.element = Convert-UiaElement -Element $elements[0]
                    $result.method = $method
                    Send-Json $ctx $result
                }
                "/uia/set_text" {
                    $body = Read-JsonBody $ctx.Request
                    $elements = Find-UiaElements -Body $body -Limit 1
                    if ($elements.Count -lt 1) {
                        throw "UIA element not found"
                    }
                    $text = Convert-EscapedText ([string]$body.text)
                    $method = $null
                    $result = Invoke-WithScreenshots "uia-set-text" {
                        $script:uiaTextMethod = Set-UiaElementText -Element $elements[0] -Text $text
                    }
                    $method = $script:uiaTextMethod
                    $result.element = Convert-UiaElement -Element $elements[0]
                    $result.method = $method
                    Send-Json $ctx $result
                }
                "/vision/diff" {
                    $body = Read-JsonBody $ctx.Request
                    $step = 8
                    $threshold = 24
                    if ($null -ne $body.step) { $step = [int]$body.step }
                    if ($null -ne $body.threshold) { $threshold = [int]$body.threshold }
                    $diff = Compare-Images -BeforePath ([string]$body.before) -AfterPath ([string]$body.after) -Step $step -Threshold $threshold
                    Send-Json $ctx ([ordered]@{ ok = $true; diff = $diff })
                }
                "/vision/find_image" {
                    $body = Read-JsonBody $ctx.Request
                    $step = 4
                    $pixelStep = 4
                    if ($null -ne $body.step) { $step = [int]$body.step }
                    if ($null -ne $body.pixelStep) { $pixelStep = [int]$body.pixelStep }
                    $match = Find-ImageTemplate `
                        -ImagePath ([string]$body.image) `
                        -TemplatePath ([string]$body.template) `
                        -Step $step `
                        -PixelStep $pixelStep `
                        -Left $body.left `
                        -Top $body.top `
                        -Right $body.right `
                        -Bottom $body.bottom
                    $ok = $true
                    if ($null -ne $body.maxAverageDelta -and $match.averageDelta -gt [double]$body.maxAverageDelta) {
                        $ok = $false
                    }
                    Send-Json $ctx ([ordered]@{ ok = $ok; match = $match })
                }
                "/vision/click_image" {
                    $body = Read-JsonBody $ctx.Request
                    $imagePath = [string]$body.image
                    if ([string]::IsNullOrWhiteSpace($imagePath)) {
                        $shot = Save-Screenshot "vision-click-source"
                        $imagePath = $shot.path
                    }
                    $step = 4
                    $pixelStep = 4
                    if ($null -ne $body.step) { $step = [int]$body.step }
                    if ($null -ne $body.pixelStep) { $pixelStep = [int]$body.pixelStep }
                    $match = Find-ImageTemplate `
                        -ImagePath $imagePath `
                        -TemplatePath ([string]$body.template) `
                        -Step $step `
                        -PixelStep $pixelStep `
                        -Left $body.left `
                        -Top $body.top `
                        -Right $body.right `
                        -Bottom $body.bottom
                    if ($null -ne $body.maxAverageDelta -and $match.averageDelta -gt [double]$body.maxAverageDelta) {
                        throw "Image match is below threshold. averageDelta=$($match.averageDelta)"
                    }
                    $result = Invoke-WithScreenshots "vision-click-image" {
                        Invoke-Click -X ([int]$match.centerX) -Y ([int]$match.centerY)
                    }
                    $result.match = $match
                    Send-Json $ctx $result
                }
                "/ocr" {
                    $body = Read-JsonBody $ctx.Request
                    $language = "eng"
                    $psm = 6
                    if ($null -ne $body.language) { $language = [string]$body.language }
                    if ($null -ne $body.psm) { $psm = [int]$body.psm }
                    $ocr = Invoke-Ocr `
                        -ImagePath ([string]$body.image) `
                        -Language $language `
                        -Psm $psm `
                        -Left $body.left `
                        -Top $body.top `
                        -Right $body.right `
                        -Bottom $body.bottom
                    Send-Json $ctx $ocr
                }
                "/ocr/find_text" {
                    $body = Read-JsonBody $ctx.Request
                    $language = "eng"
                    $psm = 6
                    if ($null -ne $body.language) { $language = [string]$body.language }
                    if ($null -ne $body.psm) { $psm = [int]$body.psm }
                    $found = Find-OcrText `
                        -ImagePath ([string]$body.image) `
                        -Text ([string]$body.text) `
                        -Language $language `
                        -Psm $psm `
                        -Left $body.left `
                        -Top $body.top `
                        -Right $body.right `
                        -Bottom $body.bottom
                    Send-Json $ctx $found
                }
                "/ocr/click_text" {
                    $body = Read-JsonBody $ctx.Request
                    $language = "eng"
                    $psm = 6
                    $minConfidence = 0
                    if ($null -ne $body.language) { $language = [string]$body.language }
                    if ($null -ne $body.psm) { $psm = [int]$body.psm }
                    if ($null -ne $body.minConfidence) { $minConfidence = [double]$body.minConfidence }
                    $clicked = Invoke-OcrClickText `
                        -ImagePath ([string]$body.image) `
                        -Text ([string]$body.text) `
                        -Language $language `
                        -Psm $psm `
                        -Left $body.left `
                        -Top $body.top `
                        -Right $body.right `
                        -Bottom $body.bottom `
                        -MinConfidence $minConfidence
                    Send-Json $ctx $clicked
                }
                "/verify" {
                    $body = Read-JsonBody $ctx.Request
                    $expectation = Test-Expectation $body.expect
                    Send-Json $ctx ([ordered]@{
                        ok = $expectation.ok
                        expectation = $expectation
                        screen = Get-ScreenInfo
                    })
                }
                "/action" {
                    $body = Read-JsonBody $ctx.Request
                    $label = "action"
                    if ($null -ne $body.action) { $label = "action-$($body.action)" }
                    $before = Save-Screenshot "$label-before"
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()
                    $actionResult = Invoke-AgentAction $body
                    if ($null -ne $body.delayMs) {
                        Start-Sleep -Milliseconds ([int]$body.delayMs)
                    } else {
                        Start-Sleep -Milliseconds 250
                    }
                    $sw.Stop()
                    $after = Save-Screenshot "$label-after"
                    $expectBody = $body.expect
                    if ($null -ne $expectBody -and $null -ne $expectBody.diff) {
                        $diffBody = [ordered]@{}
                        foreach ($prop in $expectBody.diff.PSObject.Properties) {
                            $diffBody[$prop.Name] = $prop.Value
                        }
                        if ([string]::IsNullOrWhiteSpace([string]$diffBody.before)) {
                            $diffBody.before = $before.path
                        }
                        if ([string]::IsNullOrWhiteSpace([string]$diffBody.after)) {
                            $diffBody.after = $after.path
                        }
                        $expectBody = [ordered]@{}
                        foreach ($prop in $body.expect.PSObject.Properties) {
                            $expectBody[$prop.Name] = $prop.Value
                        }
                        $expectBody.diff = [pscustomobject]$diffBody
                        $expectBody = [pscustomobject]$expectBody
                    }
                    $expectation = Test-Expectation $expectBody
                    Send-Json $ctx ([ordered]@{
                        ok = $expectation.ok
                        action = $actionResult
                        durationMs = $sw.ElapsedMilliseconds
                        before = $before
                        after = $after
                        expectation = $expectation
                        screen = Get-ScreenInfo
                    })
                }
                default {
                    Send-Json $ctx ([ordered]@{ ok = $false; error = "not found"; path = $path }) 404
                }
            }
        } catch {
            Write-AgentLog "error $($_.Exception.Message)"
            Write-AgentLog "errorInvocation $($_.InvocationInfo.PositionMessage)"
            Write-AgentLog "errorStack $($_.ScriptStackTrace)"
            Send-Json $ctx ([ordered]@{ ok = $false; error = $_.Exception.Message }) 500
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
    Write-AgentLog "stopped"
}
