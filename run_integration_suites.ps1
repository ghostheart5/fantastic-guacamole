param(
  [ValidateSet('smoke', 'full', 'local_full')]
  [string]$Suite = 'smoke',

  [string]$Target = 'test/integration'
)

$ErrorActionPreference = 'Stop'

function Invoke-CheckedCommand {
  param(
    [string]$Command
  )

  Write-Host "[ChronoSpark] Running: $Command" -ForegroundColor Cyan
  Invoke-Expression $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE: $Command"
  }
}

switch ($Suite) {
  'smoke' {
    Invoke-CheckedCommand "flutter test -t smoke $Target"
  }
  'full' {
    Invoke-CheckedCommand "flutter test -t full $Target"
  }
  'local_full' {
    Invoke-CheckedCommand "flutter test -t full -x live $Target"
  }
  default {
    throw "Unknown suite: $Suite"
  }
}

Write-Host "[ChronoSpark] Suite completed: $Suite" -ForegroundColor Green
