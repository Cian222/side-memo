param([string]$ExePath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class U34 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT3 r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(PT2 p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public struct PT2 { public int x; public int y; }
  public struct RECT3 { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[U34]::SetProcessDPIAware() | Out-Null
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$right = $vs.X + $vs.Width

$procs = Get-Process side-memo -ErrorAction SilentlyContinue
$cn = -join ([char]0x4FA7, [char]0x8FB9, [char]0x5907, [char]0x5FD8, [char]0x5F55)
$procs2 = Get-Process -Name $cn -ErrorAction SilentlyContinue
Write-Host ("side-memo procs: " + (($procs.Id) -join ','))
Write-Host ("cjk-name procs:  " + (($procs2.Id) -join ','))

foreach ($pr in @($procs + $procs2)) {
  if (-not $pr) { continue }
  $r = New-Object 'U34+RECT3'
  [U34]::GetWindowRect($pr.MainWindowHandle, [ref]$r) | Out-Null
  $vis = [U34]::IsWindowVisible($pr.MainWindowHandle)
  Write-Host ("pid {0}: rect=({1},{2})-({3},{4}) visible={5}" -f $pr.Id, $r.Left, $r.Top, $r.Right, $r.Bottom, $vis)
}

# what sits at the click point now?
$pt = New-Object 'U34+PT2'
$pt.x = $right - 290; $pt.y = 209
$h = [U34]::WindowFromPoint($pt)
$root = [U34]::GetAncestor($h, 2)
$tpid = 0
[U34]::GetWindowThreadProcessId($root, [ref]$tpid) | Out-Null
$owner = Get-Process -Id $tpid -ErrorAction SilentlyContinue
Write-Host ("root window at click point: pid={0} proc={1}" -f $tpid, $owner.ProcessName)
