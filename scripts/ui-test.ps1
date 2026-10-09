# Automated UI test: launch app, drive mouse/keyboard, capture screenshots.
# Keep ASCII-only (PS 5.1 parses BOM-less files as ANSI).
param(
  [Parameter(Mandatory=$true)][string]$ExePath,
  [Parameter(Mandatory=$true)][string]$ShotDir,
  [int]$PanelLogicalWidth = 340,
  [switch]$NoKill
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class U32 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern uint GetDpiForSystem();
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
}
"@

[U32]::SetProcessDPIAware() | Out-Null
$scale = [double][U32]::GetDpiForSystem() / 96.0
Write-Host ("system scale: {0}" -f $scale)

$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$right = $vs.X + $vs.Width
$top = $vs.Y
$centerX = [int]($vs.X + $vs.Width * 0.4)
$centerY = [int]($vs.Y + $vs.Height * 0.5)

New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null

function Shot([string]$name, [int]$cropLogical) {
  $w = [int]([Math]::Round($cropLogical * $scale))
  $x = $right - $w
  $bmp = New-Object System.Drawing.Bitmap $w, $vs.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $top, 0, 0, (New-Object System.Drawing.Size $w, $vs.Height))
  $out = Join-Path $ShotDir $name
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "shot: $name"
}

function Click([int]$x, [int]$y) {
  [U32]::SetCursorPos($x, $y) | Out-Null
  Start-Sleep -Milliseconds 120
  [U32]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
  [U32]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
}

# 0) fresh data dir so first-run path is exercised
$dataDir = Join-Path $env:APPDATA "com.zcode.sideMemo"
if (Test-Path $dataDir) { Remove-Item -Recurse -Force $dataDir }

# 1) launch
Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3
Shot "01-first-run.png" ([int]($PanelLogicalWidth + 220))

# 2) Esc hides the panel
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 700
Shot "02-after-esc.png" ([int]($PanelLogicalWidth + 220))

# 3) global shortcut brings it back
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 900
Shot "03-after-hotkey.png" ([int]($PanelLogicalWidth + 220))

# 4) type a memo (paste via clipboard to bypass IME)
$inputX = $right - [int][Math]::Round(170 * $scale)
$inputY = $top + [int][Math]::Round(88 * $scale)
Click $inputX $inputY
Start-Sleep -Milliseconds 400
Set-Clipboard -Value "Hello memo 123"
[System.Windows.Forms.SendKeys]::SendWait("^v")
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 600
Shot "04-typed.png" ([int]($PanelLogicalWidth + 220))

# 5) click desktop -> lose focus -> auto retract
Click $centerX $centerY
Start-Sleep -Milliseconds 1800
Shot "05-auto-retract.png" ([int]($PanelLogicalWidth + 220))
Shot "05b-sliver-closeup.png" 90

# 6) hover the right edge -> expand again
[U32]::SetCursorPos($right - 2, $centerY) | Out-Null
Start-Sleep -Milliseconds 800
Shot "06-hover-expand.png" ([int]($PanelLogicalWidth + 220))

# 7) hotkey hides again
[System.Windows.Forms.SendKeys]::SendWait("^%m")
Start-Sleep -Milliseconds 600

if (-not $NoKill) {
  Get-Process side-memo -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 500
}
Write-Host "ui-test done"
