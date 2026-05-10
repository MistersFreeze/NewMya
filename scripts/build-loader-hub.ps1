# Build roblox-ts loader-hub → packages/loader-hub/out/
$ErrorActionPreference = "Stop"
$pkg = Join-Path $PSScriptRoot "..\packages\loader-hub"
Set-Location $pkg
if (-not (Test-Path "node_modules")) {
    npm install
}
npm run build
Write-Host "Output: $pkg\out\init.luau"
