# v0.9 backup verification: theme toggle triggers save -> backup created;
# second toggle within 10 min -> gated (no new backup).
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

function Backup-Count {
  $dir = Join-Path $env:APPDATA 'com.zcode.sideMemo\backups'
  if (-not (Test-Path $dir)) { return 0 }
  (Get-ChildItem $dir -Filter 'memos-*.json' | Measure-Object).Count
}

Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
$cn = -join ([char]0x4FA7, [char]0x8FB9, [char]0x5907, [char]0x5FD8, [char]0x5F55)
Get-Process -Name $cn -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item (Join-Path $env:APPDATA 'com.zcode.sideMemo\backups') -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
Write-Host ("backups before: " + (Backup-Count))

Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3
$myPid = (Get-Process $procName -ErrorAction Stop).Id
Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 1500

# toggle theme -> save -> first backup
if (-not (Guarded-Click ($right - 28) ($top + 28))) { exit 1 }
Start-Sleep -Milliseconds 800
Write-Host ("backups after first save:  " + (Backup-Count))

# toggle back within 10 min -> gated
if (-not (Guarded-Click ($right - 28) ($top + 28))) { exit 1 }
Start-Sleep -Milliseconds 800
Write-Host ("backups after gated save:  " + (Backup-Count))

# open settings for the status line screenshot
if (-not (Guarded-Click ($right - 60) ($top + 28))) { exit 1 }
Start-Sleep -Milliseconds 300
Shot "40-backup-settings.png" 620
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Write-Host "v09 test done"
