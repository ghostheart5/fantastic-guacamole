$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path logs | Out-Null
$ts = Get-Date -Format yyyyMMdd-HHmmss
$file = Join-Path logs ("flutter-apk-debug-$ts.log")

Write-Host 'Running flutter clean...'
flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Running flutter pub get...'
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Writing clean rebuild log to: $file"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& flutter build apk --debug -v *>&1 | Tee-Object -FilePath $file
$buildExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
exit $buildExitCode