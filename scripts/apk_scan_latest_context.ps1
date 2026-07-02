$ErrorActionPreference = 'Stop'

$log = Get-ChildItem -Path logs -Filter 'flutter-apk-debug-*.log' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $log) {
  Write-Host 'No APK debug logs found in logs/'
  exit 1
}

Write-Host "Using log: $($log.FullName)"

$markers = @(
  "Execution failed for task ':app:mergeDebugResources'",
  'AAPT: error:',
  'resource .* not found',
  'duplicate resources',
  'failed linking references',
  'FAILURE: Build failed',
  'BUILD FAILED'
)

$lines = Get-Content -Path $log.FullName
$indexes = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
  foreach ($m in $markers) {
    if ($lines[$i] -match $m) {
      $indexes += $i
      break
    }
  }
}

if (-not $indexes) {
  Write-Host 'No hard failure markers found in latest APK debug log.'
  $success = Select-String -Path $log.FullName -Pattern 'BUILD SUCCESSFUL|Built build\\app\\outputs\\flutter-apk\\app-debug.apk|Running Gradle task ''assembleDebug''... [0-9,\.]+s' -CaseSensitive:$false | Select-Object -First 6
  if ($success) {
    Write-Host 'Success markers:'
    $success | ForEach-Object { Write-Host $_.Line }
  }
  Write-Host 'Log tail:'
  Get-Content -Path $log.FullName -Tail 20 | ForEach-Object { Write-Host $_ }
  exit 0
}

$unique = $indexes | Sort-Object -Unique | Select-Object -First 6
Write-Host ("Hard failure marker count: " + $unique.Count)

foreach ($idx in $unique) {
  Write-Host '---'
  $start = [Math]::Max(0, $idx - 2)
  $end = [Math]::Min($lines.Count - 1, $idx + 4)
  for ($j = $start; $j -le $end; $j++) {
    $text = $lines[$j]
    if ($text.Length -gt 220) {
      $text = $text.Substring(0, 220) + '...'
    }
    Write-Host (("{0}: {1}" -f ($j + 1), $text))
  }
}