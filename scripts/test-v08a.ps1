# v0.8 round A: launch with an overdue reminder -> app should auto-fire a toast
# and quietly expand the panel within ~5s. Then verify the bell popover.
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

Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
$cn = -join ([char]0x4FA7, [char]0x8FB9, [char]0x5907, [char]0x5FD8, [char]0x5F55)
Get-Process -Name $cn -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Start-Process -FilePath $args[0] -WindowStyle Hidden
Start-Sleep -Seconds 9
$myPid = (Get-Process $procName -ErrorAction Stop).Id

Shot "37-reminder-fired.png" 620

# bell popover on first card (bell is first op button)
if (Guarded-Click ($right - 112) ($top + 239)) {
  Start-Sleep -Milliseconds 300
  Shot "38-remind-pop.png" 620
  # click "10 minutes" (first grid cell)
  if (Guarded-Click ($right - 61) ($top + 272)) {
    Start-Sleep -Milliseconds 500
    Shot "39-reminder-set.png" 620
  }
}
Write-Host "v08 round A done"
