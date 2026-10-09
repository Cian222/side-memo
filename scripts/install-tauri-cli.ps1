$ErrorActionPreference = 'Continue'
& "$env:USERPROFILE\.cargo\bin\cargo.exe" install tauri-cli --locked 2>&1 | Select-Object -Last 5
Write-Host "cargo install exit: $LASTEXITCODE"
& "$env:USERPROFILE\.cargo\bin\cargo.exe" tauri --version
