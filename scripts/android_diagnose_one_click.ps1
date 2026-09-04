[CmdletBinding()]
param(
  [string]$PackageName = 'com.ghostheart5.chronospark',
  [string]$DeviceSerial,
  [string]$AdbPath,
  [ValidateRange(1, 3600)]
  [int]$BuildTimeoutSeconds = 900,
  [ValidateRange(1, 300)]
  [int]$AdbTimeoutSeconds = 60,
  [ValidateRange(1, 120)]
  [int]$LaunchReadinessTimeoutSeconds = 30,
  [string]$LaunchEvidencePath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

function Resolve-CommandPath {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [string[]]$Candidates = @()
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }
  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  return $null
}

function Stop-NativeProcessTree {
  param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

  $isWindowsHost = $env:OS -eq 'Windows_NT'
  $isWindowsVariable = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
  if ($isWindowsVariable) {
    $isWindowsHost = [bool]$isWindowsVariable.Value
  }
  if ($isWindowsHost) {
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
  }
  else {
    try { $Process.Kill($true) } catch { $Process.Kill() }
  }
  if (-not $Process.HasExited) {
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-BoundedCommand {
  param(
    [Parameter(Mandatory)]
    [string]$Executable,
    [Parameter(Mandatory)]
    [string[]]$Arguments,
    [Parameter(Mandatory)]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds,
    [string]$LogPath
  )

  $startedAt = (Get-Date).ToUniversalTime()
  $process = $null
  $processStarted = $false
  $timedOut = $false
  $exitCode = -1
  $output = ''
  $startError = $null
  try {
    $payloadJson = [ordered]@{
      executable = $Executable
      arguments = @($Arguments)
    } | ConvertTo-Json -Compress
    $payloadBase64 = [Convert]::ToBase64String(
      [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
    )
    $invokeCommand = @"
`$payloadJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$payloadBase64'))
`$payload = `$payloadJson | ConvertFrom-Json
`$target = [string]`$payload.executable
`$targetArguments = @(`$payload.arguments | ForEach-Object { [string]`$_ })
& `$target @targetArguments
exit `$LASTEXITCODE
"@
    $encodedCommand = [Convert]::ToBase64String(
      [System.Text.Encoding]::Unicode.GetBytes($invokeCommand)
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Process -Id $PID).Path
    $startInfo.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCommand"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $processStarted = $process.Start()
    if (-not $processStarted) {
      throw "Unable to start native command: $Executable"
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $timedOut = $true
      Stop-NativeProcessTree -Process $process
      if (-not $process.WaitForExit(5000)) {
        throw "Timed-out native command could not be terminated: $Executable"
      }
    }
    else {
      $process.WaitForExit()
    }

    if (-not $stdoutTask.Wait(5000) -or -not $stderrTask.Wait(5000)) {
      throw "Native command output pipes did not close after termination: $Executable"
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $outputParts = @($stdout, $stderr) |
      Where-Object { -not [string]::IsNullOrEmpty($_) } |
      ForEach-Object { $_.TrimEnd() }
    $output = $outputParts -join [Environment]::NewLine
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
  }
  catch {
    $startError = $_.Exception.Message
    $output = $startError
  }
  finally {
    if ($processStarted -and $process -and -not $process.HasExited) {
      Stop-NativeProcessTree -Process $process
      [void]$process.WaitForExit(5000)
    }
    if ($process) {
      $process.Dispose()
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $logDirectory = Split-Path -Parent $LogPath
    if ($logDirectory) {
      New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    }
    [System.IO.File]::WriteAllText(
      $LogPath,
      $output,
      [System.Text.UTF8Encoding]::new($false)
    )
  }

  $finishedAt = (Get-Date).ToUniversalTime()
  return [pscustomobject]@{
    Status = if (-not $timedOut -and $exitCode -eq 0 -and -not $startError) {
      'passed'
    }
    else {
      'failed'
    }
    ExitCode = $exitCode
    TimedOut = $timedOut
    StartError = $startError
    Output = $output
    DurationSeconds = [math]::Round(($finishedAt - $startedAt).TotalSeconds, 3)
  }
}

function ConvertTo-OperationEvidence {
  param([Parameter(Mandatory)]$Result)

  return [ordered]@{
    status = $Result.Status
    exitCode = $Result.ExitCode
    timedOut = $Result.TimedOut
    durationSeconds = $Result.DurationSeconds
    verified = ($Result.Status -eq 'passed')
  }
}

function Test-CommandPassed {
  param([Parameter(Mandatory)]$Result)
  return $Result.Status -eq 'passed' -and
    -not $Result.TimedOut -and
    $Result.ExitCode -eq 0
}

function Get-AppReadiness {
  param(
    [Parameter(Mandatory)][string]$ResolvedAdbPath,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$AppPackage,
    [ValidateRange(1, 120)][int]$TimeoutSeconds,
    [ValidateRange(1, 30)][int]$ProbeTimeoutSeconds,
    [ValidateRange(1, 10)][int]$RequiredStableSamples = 2,
    [ValidateRange(100, 5000)][int]$PollMilliseconds = 500
  )

  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  $focusPattern = '(?i)\bmCurrentFocus=.*\bu\d+\s+' +
    [regex]::Escape($AppPackage) + '(?:/|\.)'
  $stableSamples = 0
  $stablePid = ''
  $lastPid = ''
  $lastFocus = ''
  $probeCommandsSucceeded = $true

  do {
    $pidResult = Invoke-BoundedCommand `
      -Executable $ResolvedAdbPath `
      -Arguments @('-s', $Serial, 'shell', 'pidof', $AppPackage) `
      -TimeoutSeconds $ProbeTimeoutSeconds
    $focusResult = Invoke-BoundedCommand `
      -Executable $ResolvedAdbPath `
      -Arguments @('-s', $Serial, 'shell', 'dumpsys', 'window', 'displays') `
      -TimeoutSeconds $ProbeTimeoutSeconds

    $pidCommandValid = -not $pidResult.TimedOut -and
      $pidResult.ExitCode -in @(0, 1)
    $focusCommandValid = Test-CommandPassed -Result $focusResult
    $probeCommandsSucceeded = $probeCommandsSucceeded -and
      $pidCommandValid -and
      $focusCommandValid

    $pidTokens = @($pidResult.Output -split '\s+' | Where-Object {
      $_ -match '^\d+$'
    })
    $lastPid = if ($pidTokens.Count -gt 0) { $pidTokens[0] } else { '' }
    $lastFocus = @($focusResult.Output -split "`r?`n" | Where-Object {
      $_ -match 'mCurrentFocus='
    } | Select-Object -Last 1) -join ''
    $ownsFocus = $pidResult.ExitCode -eq 0 -and
      -not [string]::IsNullOrWhiteSpace($lastPid) -and
      $focusCommandValid -and
      $lastFocus -match $focusPattern

    if ($ownsFocus) {
      if ($lastPid -eq $stablePid) {
        $stableSamples++
      }
      else {
        $stablePid = $lastPid
        $stableSamples = 1
      }
      if ($stableSamples -ge $RequiredStableSamples) {
        return [pscustomobject]@{
          Ready = $true
          PidObserved = $true
          Focused = $true
          Pid = $lastPid
          Focus = $lastFocus.Trim()
          StableSamples = $stableSamples
          ProbeCommandsSucceeded = $probeCommandsSucceeded
          ElapsedSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
        }
      }
    }
    else {
      $stableSamples = 0
      $stablePid = ''
    }

    if ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
      Start-Sleep -Milliseconds $PollMilliseconds
    }
  } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)

  return [pscustomobject]@{
    Ready = $false
    PidObserved = -not [string]::IsNullOrWhiteSpace($lastPid)
    Focused = $lastFocus -match $focusPattern
    Pid = $lastPid
    Focus = $lastFocus.Trim()
    StableSamples = $stableSamples
    ProbeCommandsSucceeded = $probeCommandsSucceeded
    ElapsedSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
  }
}

$logsRoot = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$buildLog = Join-Path $logsRoot "flutter-apk-debug-$timestamp.log"
$installLog = Join-Path $logsRoot "adb-install-$timestamp.log"
$runtimeLog = Join-Path $logsRoot "android-logcat-$timestamp.log"
if ([string]::IsNullOrWhiteSpace($LaunchEvidencePath)) {
  $LaunchEvidencePath = Join-Path $logsRoot "android-launch-evidence-$timestamp.json"
}
elseif (-not [System.IO.Path]::IsPathRooted($LaunchEvidencePath)) {
  $LaunchEvidencePath = Join-Path $root $LaunchEvidencePath
}
$LaunchEvidencePath = [System.IO.Path]::GetFullPath($LaunchEvidencePath)
$evidenceDirectory = Split-Path -Parent $LaunchEvidencePath
if ($evidenceDirectory) {
  New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
}

$evidence = [ordered]@{
  schemaVersion = 1
  status = 'running'
  failureReason = $null
  packageName = $PackageName
  deviceSerial = $DeviceSerial
  deviceVerified = $false
  startedAt = (Get-Date).ToUniversalTime().ToString('o')
  finishedAt = $null
  buildLog = $buildLog
  installLog = $installLog
  runtimeLog = $runtimeLog
  apk = [ordered]@{
    path = $null
    sha256 = $null
  }
  operations = [ordered]@{}
  launch = [ordered]@{
    commandsSucceeded = $false
    fallbackAttempted = $false
    ready = $false
    pidObserved = $false
    focused = $false
    pid = ''
    focus = ''
    stableSamples = 0
    probeCommandsSucceeded = $false
    readinessSeconds = 0
  }
  logcatCollected = $false
  logcatByteCount = 0
  fatalMarkerCount = $null
}

function Save-LaunchEvidence {
  param(
    [Parameter(Mandatory)][ValidateSet('passed', 'failed')][string]$Status,
    [string]$FailureReason
  )

  $evidence.status = $Status
  $evidence.failureReason = $FailureReason
  $evidence.finishedAt = (Get-Date).ToUniversalTime().ToString('o')
  $evidence | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $LaunchEvidencePath -Encoding utf8
}

function Stop-DiagnoseFailure {
  param(
    [Parameter(Mandatory)][string]$Reason,
    [Parameter(Mandatory)][string]$Message
  )

  Save-LaunchEvidence -Status 'failed' -FailureReason $Reason
  Write-Host $Message -ForegroundColor Red
  Write-Host "Launch evidence: $LaunchEvidencePath"
  exit 1
}

if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
  Stop-DiagnoseFailure `
    -Reason 'device-serial-required' `
    -Message 'An explicit -DeviceSerial is required; automatic first-device selection is disabled.'
}
if ($DeviceSerial -notmatch '^[A-Za-z0-9._:-]+$') {
  Stop-DiagnoseFailure -Reason 'invalid-device-serial' -Message 'The selected device serial is invalid.'
}
if ($PackageName -notmatch '^[A-Za-z][A-Za-z0-9._]+$') {
  Stop-DiagnoseFailure -Reason 'invalid-package-name' -Message 'The Android package name is invalid.'
}

$adbCandidates = @(
  $(if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe' }),
  $(if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe' }),
  $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe' }),
  'C:/Android/Sdk/platform-tools/adb.exe',
  'C:/LDPlayer/LDPlayer9/adb.exe'
) | Where-Object { $_ }
$adb = if (-not [string]::IsNullOrWhiteSpace($AdbPath)) {
  if (Test-Path -LiteralPath $AdbPath -PathType Leaf) {
    (Resolve-Path -LiteralPath $AdbPath).Path
  }
  else {
    $null
  }
}
else {
  Resolve-CommandPath -Name 'adb' -Candidates $adbCandidates
}
if (-not $adb) {
  Stop-DiagnoseFailure -Reason 'adb-not-found' -Message 'adb was not found.'
}
$flutter = Resolve-CommandPath -Name 'flutter'
if (-not $flutter) {
  Stop-DiagnoseFailure -Reason 'flutter-not-found' -Message 'flutter was not found.'
}

$adbStart = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @('start-server') `
  -TimeoutSeconds $AdbTimeoutSeconds
$evidence.operations['adbStart'] = ConvertTo-OperationEvidence -Result $adbStart
if (-not (Test-CommandPassed -Result $adbStart)) {
  Stop-DiagnoseFailure -Reason 'adb-start-failed' -Message 'adb start-server failed or timed out.'
}

$deviceQuery = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @('devices', '-l') `
  -TimeoutSeconds $AdbTimeoutSeconds
$evidence.operations['deviceQuery'] = ConvertTo-OperationEvidence -Result $deviceQuery
if (-not (Test-CommandPassed -Result $deviceQuery)) {
  Stop-DiagnoseFailure -Reason 'device-query-failed' -Message 'adb devices failed or timed out.'
}
$matchingDevices = @($deviceQuery.Output -split "`r?`n" | Where-Object {
  $_ -match ('^' + [regex]::Escape($DeviceSerial) + '\s+device(?:\s|$)')
})
if ($matchingDevices.Count -ne 1) {
  Stop-DiagnoseFailure `
    -Reason 'selected-device-not-connected' `
    -Message "The explicitly selected Android device is not connected and authorized: $DeviceSerial"
}
$evidence.deviceVerified = $true

Write-Host "Building debug APK with bounded output capture: $buildLog"
$build = Invoke-BoundedCommand `
  -Executable $flutter `
  -Arguments @('build', 'apk', '--debug') `
  -TimeoutSeconds $BuildTimeoutSeconds `
  -LogPath $buildLog
$evidence.operations['build'] = ConvertTo-OperationEvidence -Result $build
if (-not (Test-CommandPassed -Result $build)) {
  Stop-DiagnoseFailure -Reason 'build-failed' -Message 'Flutter APK build failed or timed out.'
}

$apkPath = Join-Path $root 'build/app/outputs/flutter-apk/app-debug.apk'
if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
  Stop-DiagnoseFailure -Reason 'apk-missing' -Message "Debug APK not found: $apkPath"
}
$evidence.apk.path = [System.IO.Path]::GetFullPath($apkPath)
$evidence.apk.sha256 = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash

$install = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @('-s', $DeviceSerial, 'install', '--no-streaming', '-r', $apkPath) `
  -TimeoutSeconds $AdbTimeoutSeconds `
  -LogPath $installLog
$evidence.operations['install'] = ConvertTo-OperationEvidence -Result $install
$installVerified = Test-CommandPassed -Result $install
if ($install.Output -notmatch '(?m)^Success\s*$') {
  $installVerified = $false
  $evidence.operations['install'].status = 'failed'
  $evidence.operations['install'].verified = $false
}
if (-not $installVerified) {
  Stop-DiagnoseFailure -Reason 'install-failed' -Message 'APK install failed, timed out, or did not report Success.'
}

$logcatClear = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @('-s', $DeviceSerial, 'logcat', '-c') `
  -TimeoutSeconds $AdbTimeoutSeconds
$evidence.operations['logcatClear'] = ConvertTo-OperationEvidence -Result $logcatClear
if (-not (Test-CommandPassed -Result $logcatClear)) {
  Stop-DiagnoseFailure -Reason 'logcat-clear-failed' -Message 'Logcat clear failed or timed out.'
}

$forceStop = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @('-s', $DeviceSerial, 'shell', 'am', 'force-stop', $PackageName) `
  -TimeoutSeconds $AdbTimeoutSeconds
$evidence.operations['forceStop'] = ConvertTo-OperationEvidence -Result $forceStop
if (-not (Test-CommandPassed -Result $forceStop)) {
  Stop-DiagnoseFailure -Reason 'force-stop-failed' -Message 'Pre-launch force-stop failed or timed out.'
}

$monkeyLaunch = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey', '-p', $PackageName,
    '-c', 'android.intent.category.LAUNCHER', '1'
  ) `
  -TimeoutSeconds $AdbTimeoutSeconds
$evidence.operations['monkeyLaunch'] = ConvertTo-OperationEvidence -Result $monkeyLaunch
if (-not (Test-CommandPassed -Result $monkeyLaunch)) {
  Stop-DiagnoseFailure -Reason 'monkey-launch-failed' -Message 'Monkey launch failed or timed out.'
}

$probeTimeoutSeconds = [math]::Min(5, $AdbTimeoutSeconds)
$readiness = Get-AppReadiness `
  -ResolvedAdbPath $adb `
  -Serial $DeviceSerial `
  -AppPackage $PackageName `
  -TimeoutSeconds $LaunchReadinessTimeoutSeconds `
  -ProbeTimeoutSeconds $probeTimeoutSeconds

if (-not $readiness.Ready) {
  $evidence.launch.fallbackAttempted = $true
  $fallbackLaunch = Invoke-BoundedCommand `
    -Executable $adb `
    -Arguments @(
      '-s', $DeviceSerial, 'shell', 'am', 'start', '-W',
      '-a', 'android.intent.action.MAIN',
      '-c', 'android.intent.category.LAUNCHER',
      '-p', $PackageName
    ) `
    -TimeoutSeconds $AdbTimeoutSeconds
  $evidence.operations['fallbackLaunch'] = ConvertTo-OperationEvidence -Result $fallbackLaunch
  if (-not (Test-CommandPassed -Result $fallbackLaunch)) {
    Stop-DiagnoseFailure -Reason 'fallback-launch-failed' -Message 'Fallback launch failed or timed out.'
  }
  $fallbackReadiness = Get-AppReadiness `
    -ResolvedAdbPath $adb `
    -Serial $DeviceSerial `
    -AppPackage $PackageName `
    -TimeoutSeconds $LaunchReadinessTimeoutSeconds `
    -ProbeTimeoutSeconds $probeTimeoutSeconds
  $fallbackReadiness.ProbeCommandsSucceeded =
    $readiness.ProbeCommandsSucceeded -and $fallbackReadiness.ProbeCommandsSucceeded
  $readiness = $fallbackReadiness
}

$evidence.launch.commandsSucceeded = $true
$evidence.launch.ready = $readiness.Ready
$evidence.launch.pidObserved = $readiness.PidObserved
$evidence.launch.focused = $readiness.Focused
$evidence.launch.pid = $readiness.Pid
$evidence.launch.focus = $readiness.Focus
$evidence.launch.stableSamples = $readiness.StableSamples
$evidence.launch.probeCommandsSucceeded = $readiness.ProbeCommandsSucceeded
$evidence.launch.readinessSeconds = $readiness.ElapsedSeconds
if (-not $readiness.Ready -or
  -not $readiness.PidObserved -or
  -not $readiness.Focused -or
  -not $readiness.ProbeCommandsSucceeded) {
  Stop-DiagnoseFailure `
    -Reason 'launch-readiness-not-established' `
    -Message 'ChronoSpark did not establish a stable PID and focused window after launch.'
}

$logcatDump = Invoke-BoundedCommand `
  -Executable $adb `
  -Arguments @('-s', $DeviceSerial, 'logcat', '-d', '--pid', $readiness.Pid, '-v', 'time') `
  -TimeoutSeconds $AdbTimeoutSeconds `
  -LogPath $runtimeLog
$evidence.operations['logcatDump'] = ConvertTo-OperationEvidence -Result $logcatDump
if (-not (Test-CommandPassed -Result $logcatDump)) {
  Stop-DiagnoseFailure -Reason 'logcat-dump-failed' -Message 'PID-scoped Logcat collection failed or timed out.'
}
$evidence.logcatCollected = -not [string]::IsNullOrWhiteSpace([string]$logcatDump.Output)
$evidence.logcatByteCount = if ($evidence.logcatCollected) {
  (Get-Item -LiteralPath $runtimeLog).Length
}
else {
  0
}
if (-not $evidence.logcatCollected -or $evidence.logcatByteCount -le 0) {
  Stop-DiagnoseFailure `
    -Reason 'logcat-evidence-empty' `
    -Message 'PID-scoped Logcat collection returned no usable runtime evidence.'
}

$patterns = @(
  'FATAL EXCEPTION',
  'E/flutter',
  'ANR',
  'MissingPluginException',
  'NoSuchMethodError',
  'SocketException',
  'TimeoutException',
  'Failed assertion',
  'Process\s+' + [regex]::Escape($PackageName) + '\s+has died',
  'Unable to start.*' + [regex]::Escape($PackageName),
  'ANR in\s+' + [regex]::Escape($PackageName)
)
$hits = @(Select-String `
  -LiteralPath $runtimeLog `
  -Pattern $patterns `
  -CaseSensitive:$false `
  -Context 2, 4)
$evidence.fatalMarkerCount = $hits.Count
if ($hits.Count -gt 0) {
  Stop-DiagnoseFailure -Reason 'fatal-runtime-markers' -Message "Crash/error marker count: $($hits.Count)"
}

Save-LaunchEvidence -Status 'passed'
Write-Host ''
Write-Host '=== Diagnose Summary ==='
Write-Host "Build log: $buildLog"
Write-Host "Runtime log: $runtimeLog"
Write-Host "App PID: $($readiness.Pid)"
Write-Host "Focused window: $($readiness.Focus)"
Write-Host "Launch evidence: $LaunchEvidencePath"
Write-Host 'Android diagnose passed with bounded commands and verified launch readiness.' -ForegroundColor Green
exit 0
