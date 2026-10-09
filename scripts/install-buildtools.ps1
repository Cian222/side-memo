$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "installing VS Build Tools (MSVC + Windows SDK)..."
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
Write-Host "winget exit: $LASTEXITCODE"
