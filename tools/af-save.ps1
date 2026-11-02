param([int]$x = -1, [int]$y = -1, [string]$shot = "shot", [string]$title = "Alien Fusion AI Test", [switch]$dbl, [switch]$nosave, [int]$x2 = -1, [int]$y2 = -1)
# Bring the Studio WINDOW whose title contains $title forward (Studio runs all its windows in one process, so the
# process's MainWindowTitle is whichever is active), optionally click at physical x,y, then screenshot (half size).
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class W2 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x,int y,int cx,int cy,uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@
[W2]::SetProcessDPIAware() | Out-Null
$script:hw = [IntPtr]::Zero
[W2]::EnumWindows({ param($h, $l)
  $sb = New-Object System.Text.StringBuilder 512; [W2]::GetWindowText($h, $sb, 512) | Out-Null
  if ([W2]::IsWindowVisible($h) -and $sb.ToString().Contains($title) -and $sb.ToString().Contains("Roblox Studio")) { $script:hw = $h }
  $true }, [IntPtr]::Zero) | Out-Null
if ($script:hw -eq [IntPtr]::Zero) { "no window with title $title"; exit 1 }
[W2]::ShowWindow($script:hw, 9) | Out-Null
[W2]::SetWindowPos($script:hw, [IntPtr]::Zero, 0, 0, 2400, 1500, 0x0004) | Out-Null
(New-Object -ComObject WScript.Shell).SendKeys('%'); [W2]::SetForegroundWindow($script:hw) | Out-Null
Start-Sleep -Milliseconds 500
if ([W2]::GetForegroundWindow() -ne $script:hw) { "window not foreground - abort"; exit 1 }
if ($x -ge 0) {
  [W2]::SetCursorPos($x, $y) | Out-Null; Start-Sleep -Milliseconds 150
  [W2]::mouse_event(2, 0, 0, 0, 0); Start-Sleep -Milliseconds 60; [W2]::mouse_event(4, 0, 0, 0, 0)
  if ($dbl) { Start-Sleep -Milliseconds 80; [W2]::mouse_event(2, 0, 0, 0, 0); Start-Sleep -Milliseconds 60; [W2]::mouse_event(4, 0, 0, 0, 0) }
  Start-Sleep -Milliseconds 1800
}
if ($x2 -ge 0) { [W2]::SetCursorPos($x2, $y2) | Out-Null; Start-Sleep -Milliseconds 250; [W2]::mouse_event(2, 0, 0, 0, 0); Start-Sleep -Milliseconds 60; [W2]::mouse_event(4, 0, 0, 0, 0); Start-Sleep -Milliseconds 6000 }
if (-not $nosave -and $x2 -lt 0) { (New-Object -ComObject WScript.Shell).SendKeys("^s"); Start-Sleep -Milliseconds 6000 }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$bmp = New-Object System.Drawing.Bitmap 2400, 1500; $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$s = New-Object System.Drawing.Bitmap $bmp, 1200, 750
$s.Save((Join-Path $PSScriptRoot "..\shots\$shot.png")); "ok"
