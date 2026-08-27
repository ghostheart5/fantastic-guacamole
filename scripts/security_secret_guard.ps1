$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $failures = New-Object System.Collections.Generic.List[string]

  function Add-Failure([string]$message) {
    $script:failures.Add($message)
  }

  Write-Host 'Running security secret guard checks...'

  $repositoryFiles = @(git ls-files --cached --others --exclude-standard)
  if ($LASTEXITCODE -ne 0) {
    throw 'git repository file discovery failed.'
  }

  $forbiddenRepositoryPaths = @(
    'android/key.properties',
    '.env',
    '.env.local'
  )

  foreach ($path in $forbiddenRepositoryPaths) {
    if ($repositoryFiles -contains $path) {
      Add-Failure("Forbidden repository secret file: $path")
    }
  }

  foreach ($path in $repositoryFiles) {
    if ($path -match '(?i)(^|/)\.env(?:\..+)?$' -and $path -notmatch '(?i)(^|/)\.env\.example$') {
      Add-Failure("Forbidden repository environment file: $path")
    }
    if ($path -match '(?i)\.(jks|keystore|p12|pfx|key)$') {
      Add-Failure("Forbidden repository credential artifact: $path")
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
