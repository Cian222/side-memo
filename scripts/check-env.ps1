# 检查 Tauri 构建所需环境
$ErrorActionPreference = 'SilentlyContinue'

"=== rust ==="
cargo --version
rustc --version

"=== node (可选) ==="
node --version

"=== webview2 运行时 ==="
$found = $false
foreach ($hive in 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients', 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients', 'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients') {
  $k = Get-ItemProperty (Join-Path $hive '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}') -ErrorAction SilentlyContinue
  if ($k -and $k.pv) { "found: $($k.pv) ($hive)"; $found = $true }
}
if (-not $found) { "NOT FOUND" }

"=== MSVC 工具链 ==="
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
  $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($vs) { "MSVC: $vs" } else { "MSVC: not found via vswhere" }
} else { "no vswhere" }

"=== 磁盘剩余 (D:) ==="
"{0:N1} GB" -f ((Get-PSDrive D).Free / 1GB)
