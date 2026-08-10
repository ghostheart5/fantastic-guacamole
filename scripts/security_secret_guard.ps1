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
    if ($path -match '(?i)(service[-_]?account|firebase-adminsdk).*\.json$') {
      Add-Failure("Forbidden tracked service-account credential file: $path")
    }
  }

  $embeddedPrivateKeys = git grep -n -I -E '"private_key"[[:space:]]*:[[:space:]]*"-----BEGIN' -- ':!test/**' ':!**/*.md'
  if ($LASTEXITCODE -eq 0) {
    Add-Failure('A tracked file contains a private key in JSON. Store service-account JSON only in a secret manager.')
  } elseif ($LASTEXITCODE -ne 1) {
    throw 'git grep for embedded private keys failed.'
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
