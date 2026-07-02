$ErrorActionPreference = 'Stop'

$log = Get-ChildItem -Path logs -Filter 'android-logcat-*.log' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $log) {
  Write-Host 'No Android logcat files found in logs/'
  exit 1
}

Write-Host "Using log: $($log.FullName)"

$patterns = @(
  'FATAL EXCEPTION',
  'AndroidRuntime',
  'E/flutter',
  'Exception',
  'ANR',
  'MissingPluginException',
  'NoSuchMethodError',
  'SocketException',
  'TimeoutException',
  'Failed assertion'
)

$hits = Select-String -Path $log.FullName -Pattern $patterns -CaseSensitive:$false -Context 2,4 |
  Select-Object -First 100

if (-not $hits) {
  Write-Host 'No crash/error markers found in latest logcat file.'
  exit 0
}

Write-Host ("Crash/error marker count: " + $hits.Count)
$hits | Select-Object -First 20 | ForEach-Object {
  Write-Host '---'
  $_.Context.PreContext | ForEach-Object { Write-Host $_ }
  Write-Host $_.Line
  $_.Context.PostContext | ForEach-Object { Write-Host $_ }
}