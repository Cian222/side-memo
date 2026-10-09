# v0.10 round B: click tag chip -> filter; click archive toggle -> archived view.
param([string]$ExePath)
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
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  public struct PT { public int x; public int y; }
}
"@
[U32]::SetProcessDPIAware() | Out-Null

$procName = 'side-memo'
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$right = $vs.X + $vs.Width
$top = $vs.Y
$myPid = 0
$shotDir = Join-Path $PSScriptRoot "..\.shots"

function Shot([string]$name, [int]$w) {
  $bmp = New-Object System.Drawing.Bitmap $w, $vs.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen(($right - $w), $top, 0, 0, (New-Object System.Drawing.Size $w, $vs.Height))
  $bmp.Save((Join-Path $shotDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "shot: $name"
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
  Start-Sleep -Milliseconds 100
  [U32]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [U32]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 400
  $p = 0
  [U32]::GetWindowThreadProcessId([U32]::GetForegroundWindow(), [ref]$p) | Out-Null
  if ($p -ne $myPid) { Write-Host "click done but foreground not ours"; return $false }
  return $true
}

Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 1200
$myPid = (Get-Process $procName -ErrorAction Stop).Id

function Wait-Expanded([int]$tries) {
  foreach ($i in 1..$tries) {
    Start-Sleep -Milliseconds 100
    $p2 = Get-Process $procName -ErrorAction SilentlyContinue
    if (-not $p2 -or $p2.MainWindowHandle -eq 0) { return $false }
    $r2 = New-Object 'U33+RECT2'
    [U33]::GetWindowRect($p2.MainWindowHandle, [ref]$r2) | Out-Null
    if ($r2.Left -le ($right - $panelW + 12) -and ($r2.Right - $r2.Left) -ge ($panelW - 12)) { return $true }
  }
  return $false
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class U33 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT2 r);
  public struct RECT2 { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$panelW = 400
$expanded = Wait-Expanded 10
if (-not $expanded) {
  # wake once more and wait again
  Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
  $expanded = Wait-Expanded 30
}
if (-not $expanded) { Write-Host "FAIL: never expanded"; exit 1 }

# "#ideas" chip (from shot 41: crop x 330 -> right-290, y 209)
if (-not (Guarded-Click ($right - 290) ($top + 209))) { exit 1 }
Start-Sleep -Milliseconds 300
Shot "42-tag-filtered.png" 620

# archive toggle (searchbox right side: right-35, y 167)
if (-not (Guarded-Click ($right - 35) ($top + 167))) { exit 1 }
Start-Sleep -Milliseconds 300
Shot "43-archived-view.png" 620

# back to active view
if (-not (Guarded-Click ($right - 35) ($top + 167))) { exit 1 }
Start-Sleep -Milliseconds 300
Write-Host "v10 round B done"
