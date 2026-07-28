$ErrorActionPreference = "Stop"

$file = "lib\features\trajectory_engine\ui\trajectory_engine_screen.dart"

if (-not (Test-Path $file)) {
  throw "Missing $file"
}

Copy-Item $file "$file.bak_lints" -Force

$text = Get-Content $file -Raw

# Remove redundant const from _Bullet calls when already inside a const widget tree.
$text = $text -replace "const _Bullet\(", "_Bullet("

# Add const where analyzer requested it for static widget constructors.
$text = $text -replace "(?m)^(\s+)(_MetricCard\(label: 'Pressure', value: ')", "`$1const `$2"
$text = $text -replace "(?m)^(\s+)(_MetricCard\(label: 'Divergence', value: ')", "`$1const `$2"
$text = $text -replace "(?m)^(\s+)(_MetricCard\(label: 'Completed', value: ')", "`$1const `$2"

# Do not touch Momentum because it uses dynamic momentumPercent interpolation.
Set-Content -Path $file -Value $text -Encoding UTF8

dart format $file
flutter analyze

if ($LASTEXITCODE -eq 0) {
  flutter build apk --debug
}
