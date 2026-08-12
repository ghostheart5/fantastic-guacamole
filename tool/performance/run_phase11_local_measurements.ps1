param(
  [ValidateSet('pr', 'nightly', 'release', 'soak')]
  [string]$Tier = 'pr',
  [switch]$ExecuteDevice
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$profilePath = Join-Path $root 'tool/performance/phase11_budget_profiles.json'

if (-not (Test-Path -LiteralPath $profilePath)) {
  throw "Missing Phase 11 profile: $profilePath"
}

$profile = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json
if ($profile.status -ne 'provisional-unvalidated') {
  throw 'Phase 11 budgets must remain provisional until candidate measurements are reviewed.'
}
@('empty', 'small', 'realistic', 'heavy', 'extreme') | ForEach-Object {
  if ($null -eq $profile.datasets.PSObject.Properties[$_]) {
    throw "Phase 11 is missing required dataset: $_"
  }
}
if (@($profile.datasets.PSObject.Properties).Count -ne 5) {
  throw 'Phase 11 must define exactly empty, small, realistic, heavy, and extreme datasets.'
}

$tierProfile = $profile.tiers.$Tier
if ($null -eq $tierProfile) {
  throw "Unknown Phase 11 tier: $Tier"
}
if ($tierProfile.candidateDeviceRequired -and -not $ExecuteDevice) {
  Write-Host "Phase 11 $Tier is device-required and remains PENDING. Use -ExecuteDevice only after selecting an isolated candidate and recording its metadata."
  exit 0
}
if ($ExecuteDevice) {
  throw 'Device execution is intentionally not implemented by this local-safe runner. Record an approved candidate-specific command before enabling it.'
}

Write-Host 'Phase 11 local-safe profile validation passed.'
Write-Host "Tier: $Tier"
Write-Host 'No application, network, backend, Monkey, or soak workload was launched.'
