Param(
  [switch]$IncludeUntracked
)

$ErrorActionPreference = 'Stop'

function Normalize-Path([string]$path) {
  return ($path -replace '\\', '/').Trim()
}

function Is-UnderPrefix([string]$path, [string[]]$prefixes) {
  foreach ($prefix in $prefixes) {
    if ($path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

Write-Host 'Phase 0 safe preflight: scanning changed files...' -ForegroundColor Cyan

$porcelain = git status --porcelain
if (-not $porcelain) {
  Write-Host 'PASS: no local changes detected.' -ForegroundColor Green
  exit 0
}

$changedFiles = New-Object System.Collections.Generic.HashSet[string]

foreach ($line in $porcelain) {
  if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
    continue
  }

  $status = $line.Substring(0, 2)
  $pathPart = $line.Substring(3).Trim()

  if (-not $IncludeUntracked -and $status -eq '??') {
    continue
  }

  if ($pathPart -like '* -> *') {
    $pathPart = $pathPart.Split(' -> ')[1].Trim()
  }

  $normalized = Normalize-Path $pathPart
  if (-not [string]::IsNullOrWhiteSpace($normalized)) {
    [void]$changedFiles.Add($normalized)
  }
}

if ($changedFiles.Count -eq 0) {
  Write-Host 'PASS: only untracked files present (not included in this run).' -ForegroundColor Green
  exit 0
}

$blockedPrefixes = @(
  'lib/features/auth/',
  'supabase/',
  'lib/features/monetization/',
  'android/app/',
  'ios/Runner/'
)

$blockedExact = @(
  'firebase.json',
  'android/key.properties',
  '.env',
  '.env.local'
)

$allowedPrefixes = @(
  'docs/',
  'lib/features/onboarding/',
  'lib/app/router/',
  'lib/tutorial/mission/'
)

$allowedExact = @(
  'phase0_safe_preflight.ps1',
  'lib/state/core/app_providers.dart',
  'lib/app/startup/app_bootstrap.dart',
  'lib/app/navigation_shell.dart',
  'lib/tutorial/tutorial_provider.dart',
  'lib/tutorial/tutorial_controller.dart',
  'lib/tutorial/tutorial_overlay.dart',
  'lib/tutorial/tutorial_analytics.dart',
  'lib/app/app_root.dart',
  'lib/domain/usecases/complete_goal.dart',
  'test/coverage_zero/use_case_command_coverage_test.dart'
)

$violationsBlocked = @()
$violationsOutOfScope = @()

foreach ($file in $changedFiles) {
  $isBlocked = $false

  if ($blockedExact -contains $file) {
    $isBlocked = $true
  }

  if (-not $isBlocked -and (Is-UnderPrefix $file $blockedPrefixes)) {
    $isBlocked = $true
  }

  if ($isBlocked) {
    $violationsBlocked += $file
    continue
  }

  $isAllowed = ($allowedExact -contains $file) -or (Is-UnderPrefix $file $allowedPrefixes)
  if (-not $isAllowed) {
    $violationsOutOfScope += $file
  }
}

if ($violationsBlocked.Count -gt 0 -or $violationsOutOfScope.Count -gt 0) {
  Write-Host 'FAIL: Phase 0 safety policy violation detected.' -ForegroundColor Red

  if ($violationsBlocked.Count -gt 0) {
    Write-Host ''
    Write-Host 'Blocked-area changes:' -ForegroundColor Yellow
    $violationsBlocked | Sort-Object | ForEach-Object { Write-Host " - $_" }
  }

  if ($violationsOutOfScope.Count -gt 0) {
    Write-Host ''
    Write-Host 'Out-of-scope changes (not in approved P0-1 targets):' -ForegroundColor Yellow
    $violationsOutOfScope | Sort-Object | ForEach-Object { Write-Host " - $_" }
  }

  Write-Host ''
  Write-Host 'Action: stop and clean/rollback this wave branch before continuing.' -ForegroundColor Red
  exit 1
}

Write-Host 'PASS: changed files comply with Phase 0 safe-action scope.' -ForegroundColor Green
exit 0
