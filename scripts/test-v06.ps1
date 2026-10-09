# v0.6 verification: edge mode (sliver/label/hidden) + edge width.
# Three rounds driven through the app's own settings (clicks are pid-guarded);
# each round restarts the app so the persisted edge mode is exercised.
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

function Kill-All {
  Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
  $cn = -join ([char]0x4FA7, [char]0x8FB9, [char]0x5907, [char]0x5FD8, [char]0x5F55)
  Get-Process -Name $cn -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 800
}

function Launch([int]$sleepMs) {
  Start-Process -FilePath $ExePath -WindowStyle Hidden
  Start-Sleep -Milliseconds $sleepMs
  $script:myPid = (Get-Process $procName -ErrorAction Stop).Id
}

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

# ---- Round 1: seeded sliver mode, width 20 ----
Kill-All
Launch 3000
Shot "25-edge-sliver20.png" 160

# wake expand, open settings
Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 1500
if (-not (Guarded-Click ($right - 60) ($top + 28))) { Shot "26-fail.png" 620; exit 1 }
Shot "26-settings-edge.png" 620

# click "label" segment (panelX+70, y~188), then "hidden" (panelX+274)
if (-not (Guarded-Click ($right - 270) ($top + 188))) { Shot "27-fail.png" 620; exit 1 }
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 600
Kill-All

# ---- Round 2: persisted label mode -> 28px pill ----
Launch 3000
Shot "27-edge-label.png" 160

# wake, open settings, click "hidden"
Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 1500
if (-not (Guarded-Click ($right - 60) ($top + 28))) { Shot "28-fail.png" 620; exit 1 }
if (-not (Guarded-Click ($right - 66) ($top + 188))) { Shot "28b-fail.png" 620; exit 1 }
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 600
Kill-All

# ---- Round 3: hidden mode -> nothing at edge, hover must NOT expand ----
Launch 3000
Shot "28-edge-hidden.png" 160
[U32]::SetCursorPos($right - 1, [int]($vs.Y + $vs.Height * 0.5)) | Out-Null
Start-Sleep -Milliseconds 1200
Shot "29-hidden-hover-noexpand.png" 160

# hotkey still summons
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 900
Shot "30-hidden-hotkey-expands.png" 620
Kill-All

Write-Host "v06 test done"
