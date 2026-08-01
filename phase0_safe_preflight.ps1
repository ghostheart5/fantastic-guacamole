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
  'lib/domain/usecases/archive_goal.dart',
  'lib/domain/usecases/reopen_goal.dart',
  'lib/state/providers/domain_usecase_providers.dart',
  'lib/state/providers/goals_provider.dart',
  'lib/state/providers/task_provider.dart',
  'lib/state/providers/event_bus_provider.dart',
  'lib/state/providers/intelligence_fusion_provider.dart',
  'lib/state/providers/future_timeline_provider.dart',
  'lib/state/controllers/coach_query_controller.dart',
  'lib/state/controllers/ai_controller.dart',
  'lib/state/controllers/ai_controller.helpers.dart',
  'lib/features/monetization/providers/monetization_compat_providers.dart',
  'lib/features/monetization/guards/monetization_guards.dart',
  'lib/features/monetization/providers/monetization_feature_providers.dart',
  'lib/features/monetization/presentation/screens/paywall_screen.dart',
  'lib/features/monetization/presentation/plan_comparison_screen.dart',
  'lib/features/auth/domain/usecases/goals/view/view_active_goals_usecase.dart',
  'lib/features/auth/domain/usecases/goals/view/view_completed_goals_usecase.dart',
  'lib/features/auth/domain/usecases/goals/view/view_archived_goals_usecase.dart',
  'test/release/goal_lifecycle_provider_contract_test.dart',
  'test/release/goal_status_visibility_contract_test.dart',
  'test/release/goal_transition_matrix_contract_test.dart',
  'test/release/completion_event_propagation_contract_test.dart',
  'test/release/p11_future_ascension_completion_signal_contract_test.dart',
  'test/release/p12_smart_coach_context_consolidation_contract_test.dart',
  'test/release/p13_monetization_stack_normalization_contract_test.dart',
  'test/release/p14_creator_first_navigation_contract_test.dart',
  'test/coverage_zero/use_case_command_coverage_test.dart',
  'docs/chronospark_p02_completion_verification_report.txt'
)

$violationsBlocked = @()
$violationsOutOfScope = @()

foreach ($file in $changedFiles) {
  if ($allowedExact -contains $file) {
    continue
  }

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

  $isAllowed = Is-UnderPrefix $file $allowedPrefixes
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
