param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$logsRoot = Join-Path $repoRoot 'logs/repro'
$activeSessionFile = Join-Path $logsRoot 'active_capture.json'

if (-not (Test-Path $activeSessionFile)) {
  Write-Host 'No active capture session found.'
  exit 1
}

$session = Get-Content -Path $activeSessionFile -Raw | ConvertFrom-Json

function Stop-ByPid {
  param(
    [int]$Pid,
    [string]$Label
  )

  try {
    $proc = Get-Process -Id $Pid -ErrorAction Stop
    Stop-Process -Id $proc.Id -Force
    Write-Host "$Label process stopped (PID $Pid)."
  }
  catch {
    Write-Host "$Label process already exited (PID $Pid)."
  }
}

Stop-ByPid -Pid ([int]$session.flutterPid) -Label 'flutter'
Stop-ByPid -Pid ([int]$session.adbPid) -Label 'adb logcat'

$finalDump = Join-Path $session.sessionDir 'adb_errors_final_dump.log'
& adb logcat -d -v threadtime AndroidRuntime:E flutter:E ActivityManager:E *:S | Set-Content -Path $finalDump -Encoding UTF8

$summary = @()
$summary += "Session: $($session.sessionDir)"
$summary += "flutter stdout: $($session.flutterStdout)"
$summary += "flutter stderr: $($session.flutterStderr)"
$summary += "adb errors: $($session.adbErrors)"
$summary += "adb stderr: $($session.adbErrorsStderr)"
$summary += "adb final dump: $finalDump"

$summaryFile = Join-Path $session.sessionDir 'capture_summary.txt'
Set-Content -Path $summaryFile -Value ($summary -join [Environment]::NewLine) -Encoding UTF8

Remove-Item -Path $activeSessionFile -Force

Write-Host ''
Write-Host 'Capture stopped and summary written:'
Write-Host $summaryFile
