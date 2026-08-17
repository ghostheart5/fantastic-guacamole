param(
  [switch]$ScanHistory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $failures = New-Object System.Collections.Generic.List[string]
  $tracked = @(git ls-files)
  if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }

  $textExtensions = @('.dart', '.yaml', '.yml', '.json', '.toml', '.md', '.html', '.txt', '.ps1', '.sh', '.ts', '.js', '.kt', '.kts', '.properties', '.env.example')
  $files = $tracked | Where-Object {
    $extension = [IO.Path]::GetExtension($_).ToLowerInvariant()
    $textExtensions -contains $extension -and (Test-Path $_)
  }

  $patterns = @(
    # A PEM marker in a parser/normalizer is safe; require an adjacent encoded
    # payload before treating it as a committed private key.
    @{ Regex = '(?is)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s*[A-Za-z0-9+/=]{40,}'; Message = 'private key block' },
    @{ Regex = '(?i)\b(?:ghp|github_pat|xoxb|xoxp|sk-live|sk-proj|sk-ant)-[A-Za-z0-9_\-]{16,}'; Message = 'provider token' },
    @{ Regex = '(?i)\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b'; Message = 'JWT-shaped token' },
    @{ Regex = '(?i)(?:service_role|secret|private_key|access_token|api_key)\s*[:=]\s*["'']?[A-Za-z0-9_\-/.+=]{20,}'; Message = 'assigned secret-like value' }
  )

  foreach ($file in $files) {
    $content = Get-Content -Raw -LiteralPath $file
    foreach ($pattern in $patterns) {
      if ($content -match $pattern.Regex) {
        $failures.Add("$($pattern.Message) detected in $file")
      }
    }
  }

  if ($ScanHistory) {
    $history = git log --all --format= --patch -- . ':!pubspec.lock' 2>$null
    foreach ($pattern in $patterns) {
      if ($history -match $pattern.Regex) { $failures.Add("$($pattern.Message) detected in repository history") }
    }
  }

  if ($failures.Count -gt 0) {
    Write-Host 'Secret content guard failed:' -ForegroundColor Red
    $failures | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
  }
  Write-Host 'Secret content guard passed.' -ForegroundColor Green
} finally {
  Pop-Location
}
