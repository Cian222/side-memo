# Diagnostic: where do keystrokes go after clicking the panel input?
param([string]$ExePath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class U32 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
"@
[U32]::SetProcessDPIAware() | Out-Null

function FGInfo {
  $h = [U32]::GetForegroundWindow()
  $sb = New-Object System.Text.StringBuilder 256
  [U32]::GetWindowText($h, $sb, 256) | Out-Null
  $pid2 = 0
  [U32]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  $pname = (Get-Process -Id $pid2 -ErrorAction SilentlyContinue).ProcessName
  Write-Host ("foreground: pid={0} proc={1} title={2}" -f $pid2, $pname, $sb.ToString())
}

function Click([int]$x, [int]$y) {
  [U32]::SetCursorPos($x, $y) | Out-Null
  Start-Sleep -Milliseconds 150
  [U32]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [U32]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

# fresh state
Get-Process side-memo -ErrorAction SilentlyContinue | Stop-Process -Force
$dataDir = Join-Path $env:APPDATA "com.zcode.sideMemo"
if (Test-Path $dataDir) { Remove-Item -Recurse -Force $dataDir }
Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3

Write-Host "--- after launch (first-run expanded):"
FGInfo

# click the memo textarea (inside panel, y~88 logical)
$right = 1920
Click ($right - 170) 88
Write-Host "--- after click on textarea:"
FGInfo

Set-Clipboard -Value "diag paste test"
[System.Windows.Forms.SendKeys]::SendWait("^v")
Start-Sleep -Milliseconds 400
Write-Host "--- after ctrl+v:"
FGInfo

$shots = "D:\zcode项目\侧边备忘录\.shots"
$bmp = New-Object System.Drawing.Bitmap 560, 400
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(($right - 560), 0, 0, 0, (New-Object System.Drawing.Size 560, 400))
$bmp.Save((Join-Path $shots "diag-paste.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "diag shot saved"
