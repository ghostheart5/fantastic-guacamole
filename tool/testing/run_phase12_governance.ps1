$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$required = @(
  'docs/testing/FLAKY_TEST_POLICY.md',
  'docs/testing/IMPLEMENTATION_PHASES.md',
  'docs/testing/governance/FLAKY_TEST_REGISTRY.md',
  'docs/testing/governance/QUARANTINE_REGISTRY.md',
  'docs/testing/governance/DUPLICATE_TEST_CANDIDATES.md',
  'tool/testing/select_phase12_tests.ps1'
)

foreach ($relativePath in $required) {
  $path = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing Phase 12 asset: $relativePath" }
}

$policy = Get-Content -Raw (Join-Path $root 'docs/testing/FLAKY_TEST_POLICY.md')
foreach ($term in @('first failure', 'expiry', 'replacement coverage', 'no permanent')) {
  if ($policy -notmatch [regex]::Escape($term)) { throw "Policy missing required term: $term" }
}

foreach ($registry in @('FLAKY_TEST_REGISTRY.md', 'QUARANTINE_REGISTRY.md', 'DUPLICATE_TEST_CANDIDATES.md')) {
  $text = Get-Content -Raw (Join-Path $root "docs/testing/governance/$registry")
  if ($text -notmatch '\| ID \|') { throw "Registry lacks a structured table: $registry" }
}

$selector = Join-Path $root 'tool/testing/select_phase12_tests.ps1'
$pr = & $selector -Mode pr -ChangedFiles @('lib/features/nexus/ui/nexus_screen.dart') | ConvertFrom-Json
if ($pr.testTargets -notcontains 'test/features/nexus') { throw 'Nexus PR mapping missing.' }
$release = & $selector -Mode pre-release -ChangedFiles @('lib/features/nexus/ui/nexus_screen.dart') | ConvertFrom-Json
if (($release.testTargets.Count -ne 1) -or ($release.testTargets[0] -ne 'test')) { throw 'Pre-release must select the full suite.' }

Write-Host 'Phase 12 governance validation passed.'
