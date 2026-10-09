# v0.5 verification: edge label / pin / hotkey change / width.
# SAFE automation: wake via second launch, guarded clicks (root pid), keys only
# while foreground is ours.
param([string]$ExePath, [string]$ShotDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class U32 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(PT p);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  public struct PT { public int x; public int y; }
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[U32]::SetProcessDPIAware() | Out-Null

$procName = 'side-memo'
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$right = $vs.X + $vs.Width
$top = $vs.Y
New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null

function Shot([string]$name, [int]$w) {
  $bmp = New-Object System.Drawing.Bitmap $w, $vs.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen(($right - $w), $top, 0, 0, (New-Object System.Drawing.Size $w, $vs.Height))
  $bmp.Save((Join-Path $ShotDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "shot: $name"
}

function FG-Pid { $p = 0; [U32]::GetWindowThreadProcessId([U32]::GetForegroundWindow(), [ref]$p) | Out-Null; $p }

function Guarded-Click([int]$x, [int]$y) {
  $pt = New-Object 'U32+PT'
  $pt.x = $x; $pt.y = $y
  $h = [U32]::WindowFromPoint($pt)
  $root = [U32]::GetAncestor($h, 2)
  $tpid = 0
  [U32]::GetWindowThreadProcessId($root, [ref]$tpid) | Out-Null
  if ($tpid -ne $myPid) { Write-Host "click guard: pid=$tpid not ours"; return $false }
  [U32]::SetCursorPos($x, $y) | Out-Null
  Start-Sleep -Milliseconds 120
  [U32]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 50
  [U32]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 450
  if ((FG-Pid) -ne $myPid) { Write-Host "click done but foreground not ours"; return $false }
  return $true
}

# 0) launch (seeded data exists -> retracted with label pill)
Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
$cn = -join ([char]0x4FA7, [char]0x8FB9, [char]0x5907, [char]0x5FD8, [char]0x5F55)
Get-Process -Name $cn -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3
$myPid = (Get-Process $procName -ErrorAction Stop).Id
Shot "19-edge-label.png" ([int]($panelW0 = 380 + 220))

# 1) wake expand
Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 300
$panelW = 380
$expanded = $false
foreach ($i in 1..30) {
  Start-Sleep -Milliseconds 100
  $p = Get-Process $procName -ErrorAction SilentlyContinue
  if (-not $p -or $p.MainWindowHandle -eq 0) { break }
  $rect = New-Object 'U32+RECT'
  [U32]::GetWindowRect($p.MainWindowHandle, [ref]$rect) | Out-Null
  if ($rect.Left -le ($right - $panelW + 12) -and ($rect.Right - $rect.Left) -ge ($panelW - 12)) { $expanded = $true; break }
}
if (-not $expanded) { Write-Host "FAIL: never expanded"; exit 1 }

# 2) pin it, move mouse away -> must STAY expanded
if (-not (Guarded-Click ($right - 88) ($top + 28))) { Shot "20-fail.png" 620; exit 1 }
[U32]::SetCursorPos([int]($vs.X + $vs.Width * 0.4), [int]($vs.Y + $vs.Height * 0.5)) | Out-Null
Start-Sleep -Milliseconds 1800
Shot "20-pinned-stays.png" 620

# 3) unpin -> auto retract resumes
if (-not (Guarded-Click ($right - 88) ($top + 28))) { Shot "21-fail.png" 620; exit 1 }
[U32]::SetCursorPos([int]($vs.X + $vs.Width * 0.4), [int]($vs.Y + $vs.Height * 0.5)) | Out-Null
Start-Sleep -Milliseconds 1800
Shot "21-unpinned-retracts.png" 620

# 4) wake again, open settings
Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 1200
if (-not (Guarded-Click ($right - 60) ($top + 28))) { Shot "22-fail.png" 620; exit 1 }
Shot "22-settings.png" 620

# 5) click edit-hotkey, record Ctrl+Alt+J
if (-not (Guarded-Click ($right - 36) ($top + 96))) { Shot "23-fail.png" 620; exit 1 }
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("^%j")
Start-Sleep -Milliseconds 800
Shot "23-hotkey-changed.png" 620

# 6) close settings, new hotkey hides the panel
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait("^%j")
Start-Sleep -Milliseconds 900
Shot "24-new-hotkey-hidden.png" 620
[System.Windows.Forms.SendKeys]::SendWait("^%j")
Start-Sleep -Milliseconds 800

Write-Host "v05 test done (app left running)"
