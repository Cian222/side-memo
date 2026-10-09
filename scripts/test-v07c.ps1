# v0.7 round C: deterministic autostart toggle verification.
# Kill -> fresh launch -> wake -> open settings -> toggle ON -> check registry
# -> toggle OFF -> check registry. All clicks pid-guarded, executed back-to-back.
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
  Start-Sleep -Milliseconds 350
  if (([U32]::GetWindowThreadProcessId([U32]::GetForegroundWindow(), [ref]$tpid)) -ne 0) {}
  if ($tpid -ne $myPid) {}
  $p = 0
  [U32]::GetWindowThreadProcessId([U32]::GetForegroundWindow(), [ref]$p) | Out-Null
  if ($p -ne $myPid) { Write-Host "click done but foreground not ours"; return $false }
  return $true
}

function Run-Info {
  $k = Get-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
  if (-not $k) { return "0 values" }
  $names = $k.Property | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)) }
  return ("count=" + $names.Count + " [" + ($names -join ', ') + "]")
}

# fresh deterministic state
Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
$cn = -join ([char]0x4FA7, [char]0x8FB9, [char]0x5907, [char]0x5FD8, [char]0x5F55)
Get-Process -Name $cn -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Start-Process -FilePath $args[0] -WindowStyle Hidden
Start-Sleep -Seconds 3
$myPid = (Get-Process $procName -ErrorAction Stop).Id
Start-Process -FilePath $args[0] -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 1500

Write-Host ("registry before: " + (Run-Info))
if (-not (Guarded-Click ($right - 60) ($top + 28))) { exit 1 }   # gear
if (-not (Guarded-Click ($right - 35) ($top + 457))) { exit 1 }  # switch ON
Start-Sleep -Milliseconds 900
Write-Host ("registry after ON:  " + (Run-Info))
if (-not (Guarded-Click ($right - 35) ($top + 457))) { exit 1 }  # switch OFF
Start-Sleep -Milliseconds 900
Write-Host ("registry after OFF: " + (Run-Info))
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Write-Host "round C done"
