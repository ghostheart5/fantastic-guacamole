$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

git config core.hooksPath .githooks
Write-Host 'Configured git core.hooksPath to .githooks'