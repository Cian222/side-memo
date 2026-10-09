# Generate app icons: gradient rounded square + CJK glyph (U+8BB0)
# NOTE: keep this file ASCII-only; Windows PowerShell 5.1 parses BOM-less files as ANSI.
param([string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot "..\src-tauri\icons" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$glyph = [string][char]0x8BB0  # CJK char for "note/record"

function New-IconBitmap([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $radius = [Math]::Max(4, [int]($size * 0.24))
  $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $radius * 2
  $gp.AddArc(0, 0, $d, $d, 180, 90)
  $gp.AddArc($size - $d, 0, $d, $d, 270, 90)
  $gp.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
  $gp.AddArc(0, $size - $d, $d, $d, 90, 90)
  $gp.CloseFigure()

  $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
  $c1 = [System.Drawing.Color]::FromArgb(255, 138, 124, 248)
  $c2 = [System.Drawing.Color]::FromArgb(255, 96, 156, 255)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 55.0)
  $g.FillPath($brush, $gp)

  $fontSize = [float]($size * 0.52)
  $font = New-Object System.Drawing.Font('Microsoft YaHei UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $box = New-Object System.Drawing.RectangleF(0.0, ([float]($size * 0.02)), ([float]$size), ([float]$size))
  $g.DrawString($glyph, $font, [System.Drawing.Brushes]::White, $box, $fmt)

  $g.Dispose()
  return $bmp
}

foreach ($s in 32, 128, 512) {
  $bmp = New-IconBitmap $s
  $name = if ($s -eq 512) { 'icon.png' } else { ('{0}x{0}.png' -f $s) }
  $bmp.Save((Join-Path $OutDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  if ($s -eq 32) {
    $hicon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hicon)
    $fs = [System.IO.File]::Create((Join-Path $OutDir 'icon.ico'))
    $icon.Save($fs)
    $fs.Close()
  }
  $bmp.Dispose()
}
Write-Host "icons written to $OutDir"
Get-ChildItem $OutDir | ForEach-Object { Write-Host ("{0}  {1} bytes" -f $_.Name, $_.Length) }
