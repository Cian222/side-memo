# v0.7 round B: toggle autostart switch (verify registry), expand/collapse long memo.
# App is left running from round A with the settings panel open.
param([string]$ShotDir)
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
New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null
$myPid = (Get-Process $procName -ErrorAction Stop).Id

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

function Run-Key-Count {
  $k = Get-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
  if (-not $k) { return 0 }
  ($k.Property | Measure-Object).Count
}

function Run-Key-Names-B64 {
  $k = Get-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
  if (-not $k) { return @() }
  $k.Property | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)) }
}

Write-Host ("run-key values before: " + (Run-Key-Count))

# 1) click the autostart switch (from shot 32: x ~ right-35, y ~ 457)
if (-not (Guarded-Click ($right - 35) ($top + 457))) { exit 1 }
Start-Sleep -Milliseconds 900
Write-Host ("run-key values after ON:  " + (Run-Key-Count))
Run-Key-Names-B64 | ForEach-Object { Write-Host "  run value name b64: $_" }

# 2) toggle back off (leave user's machine clean)
if (-not (Guarded-Click ($right - 35) ($top + 457))) { exit 1 }
Start-Sleep -Milliseconds 900
Write-Host ("run-key values after OFF: " + (Run-Key-Count))

# 3) close settings, hide panel, wake again to memo list
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 700
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 1200

# 4) click the "expand" button of the long memo (from shot 31: x ~ right-45, y ~ 401)
if (-not (Guarded-Click ($right - 45) ($top + 401))) { exit 1 }
Start-Sleep -Milliseconds 400
Shot "33-long-memo-expanded.png" 620

# 5) collapse back
if (-not (Guarded-Click ($right - 45) ($top + 520))) { Write-Host "collapse click skipped" }
Start-Sleep -Milliseconds 300

Write-Host "v07 round B done"
