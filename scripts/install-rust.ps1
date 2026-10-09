$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dst = "$env:TEMP\rustup-init.exe"
Write-Host "downloading rustup-init..."
Invoke-WebRequest -Uri 'https://win.rustup.rs/x86_64' -OutFile $dst -UseBasicParsing
Write-Host "installing rust toolchain (stable-msvc, minimal profile)..."
& $dst -y --default-toolchain stable-x86_64-pc-windows-msvc --profile minimal
Write-Host "rustup exit: $LASTEXITCODE"
& "$env:USERPROFILE\.cargo\bin\cargo.exe" --version
& "$env:USERPROFILE\.cargo\bin\rustc.exe" --version
