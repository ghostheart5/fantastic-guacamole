$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path logs | Out-Null
$ts = Get-Date -Format yyyyMMdd-HHmmss
$file = Join-Path logs ("flutter-apk-debug-$ts.log")

Write-Host "Writing build log to: $file"
flutter build apk --debug -v *>&1 | Tee-Object -FilePath $file