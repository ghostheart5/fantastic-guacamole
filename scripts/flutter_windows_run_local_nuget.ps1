$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$toolsDir = Join-Path $repoRoot 'tools'
$nugetPath = Join-Path $toolsDir 'nuget.exe'

if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

if (-not (Test-Path $nugetPath)) {
    Write-Host "nuget.exe not found. Downloading to: $nugetPath"
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetPath
}

# Prepend local tools so CMake/plugin build steps can resolve nuget reliably.
$env:PATH = "$toolsDir;$env:PATH"

Write-Host 'Running flutter run -d windows with local nuget on PATH...'
flutter run -d windows
exit $LASTEXITCODE
