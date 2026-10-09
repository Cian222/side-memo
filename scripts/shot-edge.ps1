$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root '.shots'
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$w = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$b = New-Object System.Drawing.Bitmap(80, 420)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen(($w - 80), 240, 0, 0, (New-Object System.Drawing.Size(80, 420)))
$b.Save((Join-Path $dir 'edge-0132.png'), [System.Drawing.Imaging.ImageFormat]::Png)
"saved: $dir\edge-0132.png (screen right 80px strip)"
