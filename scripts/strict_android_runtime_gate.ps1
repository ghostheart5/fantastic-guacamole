[CmdletBinding()]
param(
  [string]$PackageName = 'com.ghostheart5.chronospark',
  [string]$DeviceSerial,
  [switch]$RequireDevice,
  [ValidateRange(1, 3600)]
  [int]$BuildTimeoutSeconds = 900,
  [ValidateRange(1, 300)]
  [int]$AdbTimeoutSeconds = 60,
  [ValidateRange(1, 120)]
  [int]$LaunchReadinessTimeoutSeconds = 30,
  [ValidateRange(1, 7200)]
  [int]$DiagnoseTimeoutSeconds = 1800,
  [string]$LaunchEvidencePath,
  [string]$ValidateEvidenceOnlyPath
)

$ErrorActionPreference = 'Stop'
$notRunExitCode = 2
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

function Resolve-AdbPath {
  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(
    $(if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe' }),
    $(if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe' }),
    $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe' }),
    'C:/Android/Sdk/platform-tools/adb.exe',
    'C:/LDPlayer/LDPlayer9/adb.exe'
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
  return $candidates | Select-Object -First 1
}

function Convert-ToProcessArgument {
  param([string]$Argument)

  if ([string]::IsNullOrEmpty($Argument)) { return '""' }
  if ($Argument -notmatch '[\s"]') { return $Argument }
  return '"' + $Argument.Replace('"', '\"') + '"'
}

function Stop-NativeProcessTree {
  param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

  $killer = New-Object System.Diagnostics.Process
  try {
    $killer.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $killer.StartInfo.FileName = 'taskkill.exe'
    $killer.StartInfo.Arguments = "/PID $($Process.Id) /T /F"
    $killer.StartInfo.UseShellExecute = $false
    $killer.StartInfo.CreateNoWindow = $true
    if ($killer.Start() -and -not $killer.WaitForExit(5000)) {
      $killer.Kill()
      [void]$killer.WaitForExit(2000)
    }
  }
  catch {
    # The direct process kill below remains the bounded fallback.
  }
  finally {
    $killer.Dispose()
  }
  if (-not $Process.HasExited) {
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-BoundedDiagnose {
  param(
    [Parameter(Mandatory)][string]$PowerShellPath,
    [Parameter(Mandatory)][string[]]$Arguments,
    [ValidateRange(1, 7200)][int]$TimeoutSeconds
  )

  $process = New-Object System.Diagnostics.Process
  $processStarted = $false
  try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $PowerShellPath
    $startInfo.Arguments = ($Arguments | ForEach-Object {
      Convert-ToProcessArgument $_
    }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process.StartInfo = $startInfo
    $processStarted = $process.Start()
    if (-not $processStarted) {
      throw 'Unable to start Android diagnose child process.'
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
      Stop-NativeProcessTree -Process $process
      if (-not $process.WaitForExit(5000)) {
        throw 'Timed-out Android diagnose child could not be terminated.'
      }
    }
    else {
      $process.WaitForExit()
    }
    if (-not $stdoutTask.Wait(5000) -or -not $stderrTask.Wait(5000)) {
      throw 'Android diagnose output pipes did not close after termination.'
    }
    $output = @($stdoutTask.Result, $stderrTask.Result) |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    return [pscustomobject]@{
      ExitCode = if ($completed) { $process.ExitCode } else { -1 }
      TimedOut = -not $completed
      Output = $output -join [Environment]::NewLine
    }
  }
  finally {
    if ($processStarted -and -not $process.HasExited) {
      Stop-NativeProcessTree -Process $process
      [void]$process.WaitForExit(5000)
    }
    $process.Dispose()
  }
}

function Test-LaunchEvidence {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$ExpectedPackageName,
    [Parameter(Mandatory)][string]$ExpectedDeviceSerial
  )

  $failed = {
    param([string]$Reason)
    return [pscustomobject]@{
      Passed = $false
      Reason = $Reason
      Evidence = $null
    }
  }

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return & $failed 'missing-launch-evidence'
  }
  try {
    $evidence = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  }
  catch {
    return & $failed 'invalid-launch-evidence-json'
  }

  if ($evidence.schemaVersion -ne 1) {
    return & $failed 'unsupported-launch-evidence-schema'
  }
  if ($evidence.status -ne 'passed') {
    return & $failed 'launch-evidence-status-not-passed'
  }
  if ($evidence.packageName -cne $ExpectedPackageName) {
    return & $failed 'launch-evidence-package-mismatch'
  }
  if ($evidence.deviceSerial -cne $ExpectedDeviceSerial) {
    return & $failed 'launch-evidence-device-mismatch'
  }
  if ($evidence.deviceVerified -ne $true) {
    return & $failed 'selected-device-not-verified'
  }
  if ($null -eq $evidence.apk) {
    return & $failed 'missing-apk-evidence'
  }
  $apkPath = [string]$evidence.apk.path
  $apkSha256 = [string]$evidence.apk.sha256
  if ([string]::IsNullOrWhiteSpace($apkPath) -or
    -not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    return & $failed 'apk-evidence-file-missing'
  }
  if ($apkSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    return & $failed 'apk-evidence-hash-invalid'
  }
  try {
    $stream = [System.IO.File]::OpenRead($apkPath)
    try {
      $sha256 = [System.Security.Cryptography.SHA256]::Create()
      try {
        $hashBytes = $sha256.ComputeHash($stream)
        $actualApkSha256 = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
      }
      finally {
        $sha256.Dispose()
      }
    }
    finally {
      $stream.Dispose()
    }
  }
  catch {
    return & $failed "apk-evidence-hash-unreadable: $($_.Exception.Message)"
  }
  if ($actualApkSha256 -cne $apkSha256.ToUpperInvariant()) {
    return & $failed 'apk-evidence-hash-mismatch'
  }
  if ($null -eq $evidence.operations) {
    return & $failed 'missing-operations-evidence'
  }
  if ($null -eq $evidence.launch) {
    return & $failed 'missing-launch-readiness-evidence'
  }

  $requiredOperations = @(
    'adbStart',
    'deviceQuery',
    'build',
    'install',
    'logcatClear',
    'forceStop',
    'monkeyLaunch',
    'logcatDump'
  )
  foreach ($operationName in $requiredOperations) {
    $operationProperty = $evidence.operations.PSObject.Properties[$operationName]
    if (-not $operationProperty) {
      return & $failed "missing-operation-$operationName"
    }
    $operation = $operationProperty.Value
    if ($operation.status -ne 'passed' -or
      $operation.exitCode -ne 0 -or
      $operation.timedOut -ne $false -or
      $operation.verified -ne $true) {
      return & $failed "operation-not-passed-$operationName"
    }
  }

  if ($evidence.launch.fallbackAttempted -eq $true) {
    $fallbackProperty = $evidence.operations.PSObject.Properties['fallbackLaunch']
    if (-not $fallbackProperty) {
      return & $failed 'missing-operation-fallbackLaunch'
    }
    $fallback = $fallbackProperty.Value
    if ($fallback.status -ne 'passed' -or
      $fallback.exitCode -ne 0 -or
      $fallback.timedOut -ne $false -or
      $fallback.verified -ne $true) {
      return & $failed 'operation-not-passed-fallbackLaunch'
    }
  }

  if ($evidence.launch.commandsSucceeded -ne $true) {
    return & $failed 'launch-commands-not-verified'
  }
  if ($evidence.launch.probeCommandsSucceeded -ne $true) {
    return & $failed 'launch-probes-not-verified'
  }
  if ($evidence.launch.ready -ne $true -or
    $evidence.launch.pidObserved -ne $true -or
    $evidence.launch.focused -ne $true) {
    return & $failed 'launch-readiness-not-verified'
  }
  $pidText = [string]$evidence.launch.pid
  if ($pidText -notmatch '^\d+$') {
    return & $failed 'launch-pid-invalid'
  }
  $focusPattern = '(?i)\bmCurrentFocus=.*\bu\d+\s+' +
    [regex]::Escape($ExpectedPackageName) + '(?:/|\.)'
  if ([string]$evidence.launch.focus -notmatch $focusPattern) {
    return & $failed 'launch-focus-invalid'
  }
  if ([int]$evidence.launch.stableSamples -lt 2) {
    return & $failed 'launch-focus-not-stable'
  }
  if ($evidence.logcatCollected -ne $true) {
    return & $failed 'logcat-evidence-not-collected'
  }
  if ([long]$evidence.logcatByteCount -le 0) {
    return & $failed 'logcat-evidence-empty'
  }
  if ($evidence.fatalMarkerCount -ne 0) {
    return & $failed 'fatal-runtime-markers-recorded'
  }
  $runtimeLog = [string]$evidence.runtimeLog
  if ([string]::IsNullOrWhiteSpace($runtimeLog) -or
    -not (Test-Path -LiteralPath $runtimeLog -PathType Leaf)) {
    return & $failed 'runtime-log-not-verified'
  }
  try {
    $runtimeLogItem = Get-Item -LiteralPath $runtimeLog
    $runtimeLogContent = [System.IO.File]::ReadAllText($runtimeLogItem.FullName)
  }
  catch {
    return & $failed 'runtime-log-unreadable'
  }
  if ($runtimeLogItem.Length -le 0 -or
    [string]::IsNullOrWhiteSpace($runtimeLogContent)) {
    return & $failed 'runtime-log-empty'
  }
  if ([long]$evidence.logcatByteCount -ne $runtimeLogItem.Length) {
    return & $failed 'runtime-log-byte-count-mismatch'
  }

  return [pscustomobject]@{
    Passed = $true
    Reason = $null
    Evidence = $evidence
  }
}

if (-not [string]::IsNullOrWhiteSpace($ValidateEvidenceOnlyPath)) {
  if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
    [pscustomobject]@{
      Passed = $false
      Reason = 'device-serial-required'
    } | ConvertTo-Json
    exit 1
  }
  $fixtureValidation = Test-LaunchEvidence `
    -Path $ValidateEvidenceOnlyPath `
    -ExpectedPackageName $PackageName `
    -ExpectedDeviceSerial $DeviceSerial
  [pscustomobject]@{
    Passed = $fixtureValidation.Passed
    Reason = $fixtureValidation.Reason
  } | ConvertTo-Json
  if (-not $fixtureValidation.Passed) {
    exit 1
  }
  exit 0
}

Write-Host 'Running strict Android runtime gate...'

if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
  if ($RequireDevice) {
    Write-Host 'An explicit -DeviceSerial is required for the requested runtime gate.'
    exit 1
  }
  Write-Host 'No explicit device serial selected. Android runtime checks were NOT RUN.'
  exit $notRunExitCode
}
if ($DeviceSerial -notmatch '^[A-Za-z0-9._:-]+$') {
  Write-Host 'The selected Android device serial is invalid.'
  exit 1
}

$adbPath = Resolve-AdbPath
if (-not $adbPath) {
  if ($RequireDevice) {
    Write-Host 'adb not found and device is required for this gate.'
    exit 1
  }
  Write-Host 'adb not found. Android runtime checks were NOT RUN.'
  exit $notRunExitCode
}

$logsRoot = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
$runId = (Get-Date -Format 'yyyyMMdd-HHmmssfff') + "-$PID"
if ([string]::IsNullOrWhiteSpace($LaunchEvidencePath)) {
  $launchEvidencePath = Join-Path $logsRoot "android-launch-evidence-$runId.json"
}
else {
  $launchEvidencePath = [System.IO.Path]::GetFullPath($LaunchEvidencePath)
  $launchEvidenceDirectory = Split-Path -Parent $launchEvidencePath
  if ($launchEvidenceDirectory) {
    New-Item -ItemType Directory -Force -Path $launchEvidenceDirectory | Out-Null
  }
}
$diagnosePath = Join-Path $root 'scripts/android_diagnose_one_click.ps1'
$powerShellPath = (Get-Process -Id $PID).Path
$diagnoseArguments = @(
  '-NoProfile',
  '-NonInteractive',
  '-ExecutionPolicy',
  'Bypass',
  '-File',
  $diagnosePath,
  '-PackageName',
  $PackageName,
  '-DeviceSerial',
  $DeviceSerial,
  '-AdbPath',
  $adbPath,
  '-BuildTimeoutSeconds',
  [string]$BuildTimeoutSeconds,
  '-AdbTimeoutSeconds',
  [string]$AdbTimeoutSeconds,
  '-LaunchReadinessTimeoutSeconds',
  [string]$LaunchReadinessTimeoutSeconds,
  '-LaunchEvidencePath',
  $launchEvidencePath
)

Write-Host "Selected Android device: $DeviceSerial"
Write-Host "Exact launch evidence: $launchEvidencePath"
$diagnoseResult = Invoke-BoundedDiagnose `
  -PowerShellPath $powerShellPath `
  -Arguments $diagnoseArguments `
  -TimeoutSeconds $DiagnoseTimeoutSeconds
if (-not [string]::IsNullOrWhiteSpace($diagnoseResult.Output)) {
  Write-Host $diagnoseResult.Output
}
$diagnoseExitCode = $diagnoseResult.ExitCode

if ($diagnoseResult.TimedOut) {
  Write-Host "Android diagnose one-click timed out after $DiagnoseTimeoutSeconds seconds."
  exit 1
}
if ($diagnoseExitCode -ne 0) {
  if (-not $RequireDevice -and (Test-Path -LiteralPath $launchEvidencePath -PathType Leaf)) {
    try {
      $failedEvidence = Get-Content -LiteralPath $launchEvidencePath -Raw | ConvertFrom-Json
      if ($failedEvidence.failureReason -eq 'selected-device-not-connected') {
        Write-Host 'The selected device is not connected. Android runtime diagnostics were NOT RUN.'
        exit $notRunExitCode
      }
    }
    catch {
      # Invalid failure evidence remains a hard failure below.
    }
  }
  Write-Host "Android diagnose one-click failed with exit code $diagnoseExitCode."
  exit 1
}

$validation = Test-LaunchEvidence `
  -Path $launchEvidencePath `
  -ExpectedPackageName $PackageName `
  -ExpectedDeviceSerial $DeviceSerial
if (-not $validation.Passed) {
  Write-Host "Launch evidence validation failed: $($validation.Reason)"
  exit 1
}

$runtimeLog = [string]$validation.Evidence.runtimeLog
$appFatalPatterns = @(
  "Process\s+$([regex]::Escape($PackageName))\s+has died",
  "ANR in\s+$([regex]::Escape($PackageName))",
  "Unable to start.*$([regex]::Escape($PackageName))",
  'E/flutter',
  'FATAL EXCEPTION'
)
$appHits = @(Select-String `
  -LiteralPath $runtimeLog `
  -Pattern $appFatalPatterns `
  -CaseSensitive:$false `
  -Context 2, 4)
if ($appHits.Count -gt 0) {
  Write-Host "App-specific fatal marker count: $($appHits.Count)" -ForegroundColor Red
  Write-Host 'STRICT ANDROID RUNTIME GATE FAILED' -ForegroundColor Red
  exit 1
}

Write-Host "Validated launch PID: $($validation.Evidence.launch.pid)"
Write-Host "Validated focused window: $($validation.Evidence.launch.focus)"
Write-Host "Validated PID-scoped Logcat: $runtimeLog"
Write-Host 'STRICT ANDROID RUNTIME GATE PASSED' -ForegroundColor Green
exit 0
