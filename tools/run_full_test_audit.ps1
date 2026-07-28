$ErrorActionPreference = 'Stop'

$logPath = 'test_audit_output.txt'
"ChronoSpark Full Test Audit" | Set-Content -Path $logPath -Encoding UTF8
"Started: $(Get-Date -Format o)" | Add-Content -Path $logPath

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Command
  )

  $header = "`n===== $Title ====="
  Write-Host $header
  $header | Add-Content -Path $logPath
  "Command: $Command" | Add-Content -Path $logPath

  Invoke-Expression $Command 2>&1 | Tee-Object -FilePath $logPath -Append

  if ($LASTEXITCODE -ne 0) {
    $failure = "FAILED: $Title (exit code $LASTEXITCODE)"
    Write-Host $failure
    $failure | Add-Content -Path $logPath
    exit $LASTEXITCODE
  }
}

function Invoke-OptionalStep {
  param(
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][string] $Command
  )

  if (!(Test-Path $Path)) {
    $skip = "SKIP: $Title (missing $Path)"
    Write-Host $skip
    $skip | Add-Content -Path $logPath
    return
  }

  Invoke-Step -Title $Title -Command $Command
}

Invoke-Step -Title 'Flutter Pub Get' -Command 'flutter pub get'
Invoke-Step -Title 'Dart Format Check' -Command 'dart format . -o none --set-exit-if-changed'
Invoke-Step -Title 'Flutter Analyze Fatal Infos' -Command 'flutter analyze --fatal-infos'
Invoke-Step -Title 'Dart Fix Dry Run' -Command 'dart fix --dry-run'

$pubspecPath = 'pubspec.yaml'
$pubspecText = if (Test-Path $pubspecPath) { Get-Content $pubspecPath -Raw } else { '' }
if ($pubspecText -match '(?m)^\s*build_runner\s*:') {
  Invoke-Step -Title 'Build Runner Check' -Command 'dart run build_runner build --delete-conflicting-outputs'
} else {
  $skip = 'SKIP: Build Runner Check (build_runner not declared in pubspec.yaml)'
  Write-Host $skip
  $skip | Add-Content -Path $logPath
}

Invoke-OptionalStep -Title 'Unit Tests' -Path 'test/unit' -Command 'flutter test test/unit'
Invoke-OptionalStep -Title 'Smoke Tests' -Path 'test/smoke' -Command 'flutter test test/smoke'
Invoke-OptionalStep -Title 'Architecture Tests' -Path 'test/architecture' -Command 'flutter test test/architecture'
Invoke-OptionalStep -Title 'Behavior Tests' -Path 'test/behavior' -Command 'flutter test test/behavior'
Invoke-OptionalStep -Title 'Release Tests' -Path 'test/release' -Command 'flutter test test/release'

Invoke-Step -Title 'Coverage Run' -Command 'flutter test --coverage'
Invoke-Step -Title 'Coverage Summary' -Command 'powershell -ExecutionPolicy Bypass -File .\tools\coverage_summary.ps1'

"`nAudit completed successfully: $(Get-Date -Format o)" | Tee-Object -FilePath $logPath -Append
