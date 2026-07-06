$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $failures = New-Object System.Collections.Generic.List[string]

  function Add-Failure([string]$message) {
    $script:failures.Add($message)
  }

  Write-Host 'Running security secret guard checks...'

  $tracked = git ls-files
  if ($LASTEXITCODE -ne 0) {
    throw 'git ls-files failed.'
  }

  $forbiddenTrackedPaths = @(
    'android/key.properties',
    '.env',
    '.env.local'
  )

  foreach ($path in $forbiddenTrackedPaths) {
    if ($tracked -contains $path) {
      Add-Failure("Forbidden tracked secret file: $path")
    }
  }

  foreach ($path in $tracked) {
    if ($path -match '(?i)\.(jks|keystore|p12|pfx)$') {
      Add-Failure("Forbidden tracked credential artifact: $path")
    }
  }

  $possibleKeyFile = Join-Path $root 'android/key.properties'
  if (Test-Path $possibleKeyFile) {
    $raw = Get-Content -Path $possibleKeyFile -Raw
    if ($raw -match '(?im)^\s*storePassword\s*=\s*(?!YOUR_).+') {
      Add-Failure('android/key.properties contains a non-placeholder storePassword. Keep real signing secrets out of the repo.')
    }
    if ($raw -match '(?im)^\s*keyPassword\s*=\s*(?!YOUR_).+') {
      Add-Failure('android/key.properties contains a non-placeholder keyPassword. Keep real signing secrets out of the repo.')
    }
  }

  if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Security secret guard failed:' -ForegroundColor Red
    foreach ($failure in $failures) {
      Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
  }

  Write-Host 'Security secret guard passed.' -ForegroundColor Green
  exit 0
} finally {
  Pop-Location
}
