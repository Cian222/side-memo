# v0.2 verification: notes tab + editor. SAFE automation:
# - expand via second-launch wake (no keys sent to user apps)
# - poll window position, then click ONLY if the point is inside OUR window (pid guard)
# - send keys ONLY while foreground process is ours
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
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  public struct PT { public int x; public int y; }
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[U32]::SetProcessDPIAware() | Out-Null
$scale = 1.0

$procName = 'side-memo'
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$right = $vs.X + $vs.Width
$top = $vs.Y

New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null

function Shot([string]$name, [int]$w) {
  $bmp = New-Object System.Drawing.Bitmap $w, $vs.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen(($right - $w), $top, 0, 0, (New-Object System.Drawing.Size $w, $vs.Height))
  $bmp.Save((Join-Path $ShotDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "shot: $name"
}

function FG-Pid { $p = 0; [U32]::GetWindowThreadProcessId([U32]::GetForegroundWindow(), [ref]$p) | Out-Null; $p }

# launch (data seeded -> starts retracted)
Start-Process -FilePath $ExePath -WindowStyle Hidden
Start-Sleep -Seconds 3

# wake via second launch, then poll until expanded and click fast (inside the 0.9s grace)
$myPid = (Get-Process $procName -ErrorAction Stop).Id
Write-Host "app pid: $myPid"
$panelW = [int][Math]::Round(340 * $scale)
$clickX = $right - [int][Math]::Round(170 * $scale)
$clickY = $top + [int][Math]::Round(215 * $scale)

$clicked = $false
foreach ($try in 1..3) {
  if ($try -gt 1) { Start-Process -FilePath $ExePath -WindowStyle Hidden; Start-Sleep -Milliseconds 800 }
  Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null
  Start-Sleep -Milliseconds 300
  # wait until expanded (window x <= right - panelW + sliver)
  $expanded = $false
  foreach ($i in 1..30) {
    Start-Sleep -Milliseconds 100
    $p = Get-Process $procName -ErrorAction SilentlyContinue
    if (-not $p -or $p.MainWindowHandle -eq 0) { break }
    $rect = New-Object 'U32+RECT'
    [U32]::GetWindowRect($p.MainWindowHandle, [ref]$rect) | Out-Null
    if ($rect.Left -le ($right - $panelW + 12) -and ($rect.Right - $rect.Left) -ge ($panelW - 12)) { $expanded = $true; break }
  }
  if (-not $expanded) { Write-Host "try $try : never expanded"; continue }

  # pid guard at the click point (resolve to ROOT window: WebView2 child windows
  # belong to a separate msedgewebview2 process, the root is our tao window)
  $pt = New-Object 'U32+PT'
  $pt.x = $clickX; $pt.y = $clickY
  $h = [U32]::WindowFromPoint($pt)
  $root = [U32]::GetAncestor($h, 2)
  $tpid = 0
  [U32]::GetWindowThreadProcessId($root, [ref]$tpid) | Out-Null
  Write-Host ("try {0}: root window under click pid={1}" -f $try, $tpid)
  if ($tpid -ne $myPid) { continue }

  [U32]::SetCursorPos($clickX, $clickY) | Out-Null
  Start-Sleep -Milliseconds 120
  [U32]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 50
  [U32]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 400
  if ((FG-Pid) -ne $myPid) { Write-Host "try $try : foreground not ours after click"; continue }
  $clicked = $true
  break
}

if (-not $clicked) {
  Write-Host "FAILED to safely click a note; taking list shot only"
  Shot "10-notes-list.png" 560
  exit 1
}

Shot "10-editor-open.png" 560

# paste into body (foreground is ours -> safe), autosave fires within 400ms
Set-Clipboard -Value "Pasted autosave line"
[System.Windows.Forms.SendKeys]::SendWait("^v")
Start-Sleep -Milliseconds 1000
Shot "11-editor-autosave.png" 560

# Esc goes back to the list (editor intercepts Esc)
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 500
Shot "12-back-to-list.png" 560

Write-Host "v02 test done (app left running)"
