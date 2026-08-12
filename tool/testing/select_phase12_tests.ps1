param(
  [ValidateSet('pr', 'feature', 'nightly', 'pre-release', 'post-release')]
  [string]$Mode = 'pr',
  [string[]]$ChangedFiles,
  [string]$BaseRef = 'HEAD~1'
)

$ErrorActionPreference = 'Stop'

if ($Mode -eq 'pre-release' -or $Mode -eq 'nightly') {
  [pscustomobject]@{
    mode = $Mode
    selectionReason = 'Complete suite required; changed-file selection is forbidden.'
    testTargets = @('test')
  } | ConvertTo-Json -Compress
  exit 0
}

if ($null -eq $ChangedFiles -or $ChangedFiles.Count -eq 0) {
  $ChangedFiles = @(git diff --name-only "$BaseRef...HEAD")
}

$targets = New-Object System.Collections.Generic.List[string]
$targets.Add('test/release')
$targets.Add('test/behavior')

foreach ($path in $ChangedFiles) {
  $normalized = $path.Replace('\\', '/')
  if ($normalized -match '^test/') {
    $targets.Add($normalized)
  } elseif ($normalized -match '^lib/features/nexus/') {
    $targets.Add('test/features/nexus')
  } elseif ($normalized -match '^lib/features/creator/') {
    $targets.Add('test/features/creator')
  } elseif ($normalized -match '^lib/features/timeline/') {
    $targets.Add('test/features/timeline')
  } elseif ($normalized -match '^lib/features/trajectory') {
    $targets.Add('test/features/trajectory_engine')
  } elseif ($normalized -match '^lib/features/progression/') {
    $targets.Add('test/features/progression')
  } elseif ($normalized -match '^lib/features/(profile|settings)/') {
    $targets.Add('test/features')
  } elseif ($normalized -match '^(lib/app/|lib/state/|pubspec)') {
    $targets.Add('test/app')
    $targets.Add('test/integration')
  } elseif ($normalized -match '^(docs/testing/|tool/testing/|\.github/workflows/)') {
    $targets.Add('test/release/phase12_test_governance_contract_test.dart')
  } else {
    $targets.Add('test/smoke')
  }
}

[pscustomobject]@{
  mode = $Mode
  selectionReason = 'Conservative changed-file mapping with critical release and behavior guards retained.'
  changedFiles = @($ChangedFiles)
  testTargets = @($targets | Sort-Object -Unique)
} | ConvertTo-Json -Compress
