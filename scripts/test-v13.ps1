$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, ref R r);
  [DllImport("user32.dll")] public static extern int GetWindowRgn(IntPtr h, IntPtr rgn);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int a, int b, int c, int d);
  [DllImport("gdi32.dll")] public static extern int GetRgnBox(IntPtr h, ref R r);
}
"@

"SCREENS:"
[System.Windows.Forms.Screen]::AllScreens | ForEach-Object { "  " + $_.Bounds.ToString() + " primary=" + $_.Primary }

$exe = Join-Path (Split-Path -Parent $PSScriptRoot) 'src-tauri\target\release\side-memo.exe'
Start-Process -FilePath $exe
Start-Sleep -Seconds 3

$p = Get-Process -Name 'side-memo' -ErrorAction Stop
$h = $p.MainWindowHandle
"HWND=$h"

$rect = New-Object W+R
[W]::GetWindowRect($h, [ref]$rect) | Out-Null
"RECT L=$($rect.L) T=$($rect.T) R=$($rect.Rt) B=$($rect.B) W=$($rect.Rt - $rect.L) H=$($rect.B - $rect.T)"

$rgn = [W]::CreateRectRgn(0,0,0,0)
$cx = [W]::GetWindowRgn($h, $rgn)
$box = New-Object W+R
[W]::GetRgnBox($rgn, [ref]$box) | Out-Null
"RGN type=$cx box L=$($box.L) T=$($box.T) R=$($box.Rt) B=$($box.B)"
