param(
  [int]$Port = 9100,
  [switch]$Machine
)

$ErrorActionPreference = 'Stop'

$machineArg = if ($Machine) { '--machine' } else { '' }
$cmd = "dart devtools --port $Port $machineArg"

Write-Host "Starting Dart DevTools on port $Port..." -ForegroundColor Cyan
Write-Host "Command: $cmd" -ForegroundColor DarkGray

if ($Machine) {
  dart devtools --port $Port --machine
} else {
  dart devtools --port $Port
}
