$ErrorActionPreference = 'SilentlyContinue'

"=== cargo in common paths ==="
foreach ($p in @(
  "$env:USERPROFILE\.cargo\bin\cargo.exe",
  "C:\cargo\bin\cargo.exe",
  "C:\Rust\bin\cargo.exe",
  "$env:LOCALAPPDATA\Programs\Cargo\bin\cargo.exe"
)) { if (Test-Path $p) { "FOUND: $p" } }

"=== rustup ==="
@("$env:USERPROFILE\.cargo\bin\rustup.exe", "C:\ProgramData\chocolatey\bin\rustup.exe") | ForEach-Object { if (Test-Path $_) { "FOUND: $_" } }

"=== MSVC cl.exe/link.exe search ==="
foreach ($root in @("C:\Program Files\Microsoft Visual Studio", "C:\Program Files (x86)\Microsoft Visual Studio")) {
  if (Test-Path $root) {
    Get-ChildItem -Path $root -Recurse -Filter "cl.exe" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -First 3 -ExpandProperty FullName
  } else { "no dir: $root" }
}
foreach ($root in @("C:\Program Files (x86)\Windows Kits\10\bin", "C:\Program Files (x86)\Windows Kits")) {
  if (Test-Path $root) { "kits dir exists: $root" }
}

"=== winget ==="
winget --version

"=== choco ==="
choco --version

"=== scoop ==="
scoop --version
