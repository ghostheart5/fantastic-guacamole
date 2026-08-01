param(
  [switch]$SoftFail
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Add-Failure {
  param(
    [System.Collections.Generic.List[string]]$Failures,
    [string]$Message
  )

  $Failures.Add($Message)
}

function Test-Pattern {
  param(
    [string]$Content,
    [string]$Pattern
  )

  return $Content -match $Pattern
}

$failures = New-Object System.Collections.Generic.List[string]

$bootstrapPath = Join-Path $root 'lib/app/startup/app_bootstrap.dart'
$loggerPath = Join-Path $root 'lib/core/debug/logger.dart'

if (-not (Test-Path $bootstrapPath)) {
  Add-Failure -Failures $failures -Message "Missing startup bootstrap file: $bootstrapPath"
}

if (-not (Test-Path $loggerPath)) {
  Add-Failure -Failures $failures -Message "Missing logger file: $loggerPath"
}

if ($failures.Count -eq 0) {
  $bootstrapContent = Get-Content -Path $bootstrapPath -Raw
  $loggerContent = Get-Content -Path $loggerPath -Raw

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'runZonedGuarded\s*\(')) {
    Add-Failure -Failures $failures -Message 'App bootstrap must use runZonedGuarded.'
  }

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'FlutterError\.onError\s*=')) {
    Add-Failure -Failures $failures -Message 'App bootstrap must assign FlutterError.onError.'
  }

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'PlatformDispatcher\.instance\.onError\s*=')) {
    Add-Failure -Failures $failures -Message 'App bootstrap must assign PlatformDispatcher.instance.onError.'
  }

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'ErrorBoundary\.reportGlobalError\s*\(')) {
    Add-Failure -Failures $failures -Message 'Global errors must be routed through ErrorBoundary.reportGlobalError.'
  }

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'RuntimeDiagnostics\.record\s*\(')) {
    Add-Failure -Failures $failures -Message 'Global errors must be recorded in RuntimeDiagnostics.'
  }

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'FirebaseCrashlytics\.instance\.recordFlutterFatalError\s*\(')) {
    Add-Failure -Failures $failures -Message 'Flutter fatal errors must be reported to FirebaseCrashlytics.'
  }

  if (-not (Test-Pattern -Content $bootstrapContent -Pattern 'FirebaseCrashlytics\.instance\.recordError\s*\(')) {
    Add-Failure -Failures $failures -Message 'Unhandled platform or zone errors must be reported to FirebaseCrashlytics.'
  }

  if (-not (Test-Pattern -Content $loggerContent -Pattern 'static\s+void\s+error\s*\(')) {
    Add-Failure -Failures $failures -Message 'Logger must expose Logger.error for non-fatal error reporting.'
  }

  if (-not (Test-Pattern -Content $loggerContent -Pattern 'static\s+void\s+errorCategory\s*\(')) {
    Add-Failure -Failures $failures -Message 'Logger must expose Logger.errorCategory for categorized reporting.'
  }

  if (-not (Test-Pattern -Content $loggerContent -Pattern 'FirebaseCrashlytics\.instance\.recordError\s*\(')) {
    Add-Failure -Failures $failures -Message 'Logger error path must report into FirebaseCrashlytics.'
  }

  if (-not (Test-Pattern -Content $loggerContent -Pattern 'redactSensitive\s*\(')) {
    Add-Failure -Failures $failures -Message 'Logger must redact sensitive values before output.'
  }
}

Write-Host 'Phase B crash observability verifier summary:'
if ($failures.Count -eq 0) {
  Write-Host 'All required crash observability controls are present.' -ForegroundColor Green
  exit 0
}

foreach ($failure in $failures) {
  Write-Host " - $failure" -ForegroundColor Red
}

if ($SoftFail) {
  Write-Host 'Soft fail enabled. Returning success for advisory mode.' -ForegroundColor Yellow
  exit 0
}

exit 1
