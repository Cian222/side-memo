# Verify list rendering + single-instance wake: seed data exists, so app starts
# retracted; launching the exe a second time wakes instance #1 and expands it.
# SAFE: no synthetic clicks/keys are sent to whatever window is foreground.
param([string]$ExePath, [string]$ShotPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class U32 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[U32]::SetProcessDPIAware() | Out-Null

Get-Process side-memo -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3

# second launch wakes the first instance -> panel expands
Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 2

$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$right = $vs.X + $vs.Width
$w = 560
$bmp = New-Object System.Drawing.Bitmap $w, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(($right - $w), $vs.Y, 0, 0, (New-Object System.Drawing.Size $w, $vs.Height))
$bmp.Save($ShotPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "list shot saved: $ShotPath"

# leave instance running for the user, expanded state is fine
