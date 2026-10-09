# v0.4 verification: markdown preview. Same safe-automation pattern:
# wake via second launch, guarded clicks (root-window pid check), keys only when
# foreground is ours. Draws seed image, opens the seeded markdown note, toggles
# preview, screenshots both modes.
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

# seed image
$imagesDir = Join-Path $env:APPDATA 'com.zcode.sideMemo\images'
New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null
$seed = New-Object System.Drawing.Bitmap 360, 220
$g = [System.Drawing.Graphics]::FromImage($seed)
$rect = New-Object System.Drawing.Rectangle 0, 0, 360, 220
$br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255,138,124,248), [System.Drawing.Color]::FromArgb(255,96,156,255), 45.0)
$g.FillRectangle($br, $rect)
$f = New-Object System.Drawing.Font('Arial', 26, [System.Drawing.FontStyle]::Bold)
$g.DrawString('seed image 360x220', $f, [System.Drawing.Brushes]::White, 40, 90)
$g.Dispose()
$seed.Save((Join-Path $imagesDir 'img-seed.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$seed.Dispose()

# launch + wake
Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600
Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3
$myPid = (Get-Process $procName -ErrorAction Stop).Id
Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 300

$panelW = 340
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

# 1) open the seeded markdown note (first card, y ~215)
if (-not (Guarded-Click ($right - 170) ($top + 215))) { Shot "16-fail.png" 560; exit 1 }
Shot "16-edit-mode.png" 560

# 2) click the preview toggle (3rd icon button; flex gap 8 -> center at panelX+98, y~26)
if (-not (Guarded-Click ($right - 242) ($top + 26))) { Shot "17-fail.png" 560; exit 1 }
Start-Sleep -Milliseconds 300
Shot "17-preview-mode.png" 560

Write-Host "v04 test done (app left running)"
