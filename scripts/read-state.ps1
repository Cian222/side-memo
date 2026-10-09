$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W2 {
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, ref R r);
  [DllImport("user32.dll")] public static extern int GetWindowRgn(IntPtr h, IntPtr rgn);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int a, int b, int c, int d);
  [DllImport("gdi32.dll")] public static extern int GetRgnBox(IntPtr h, ref R r);
}
"@
$p = Get-Process -Name 'side-memo' -ErrorAction Stop
$h = $p.MainWindowHandle
$rect = New-Object W2+R
[W2]::GetWindowRect($h, [ref]$rect) | Out-Null
$rgn = [W2]::CreateRectRgn(0,0,0,0)
$cx = [W2]::GetWindowRgn($h, $rgn)
$box = New-Object W2+R
[W2]::GetRgnBox($rgn, [ref]$box) | Out-Null
"HWND=$h RECT L=$($rect.L) T=$($rect.T) W=$($rect.Rt-$rect.L) H=$($rect.B-$rect.T)"
"RGN type=$cx box L=$($box.L) T=$($box.T) W=$($box.Rt-$box.L) H=$($box.B-$box.T)"
