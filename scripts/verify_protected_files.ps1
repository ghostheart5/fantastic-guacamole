param(
  [string]$BaselinePath = ".rebuild/protected-file-hashes.txt"
)

if (-not (Test-Path -LiteralPath $BaselinePath)) {
  Write-Error "Baseline file not found: $BaselinePath"
  exit 2
}

$failed = $false
$lines = Get-Content -LiteralPath $BaselinePath | Where-Object { $_.Trim().Length -gt 0 }

foreach ($line in $lines) {
  $parts = $line.Split('|', 2)
  if ($parts.Count -ne 2) {
    Write-Host "SKIP malformed baseline entry: $line" -ForegroundColor Yellow
    continue
  }

  $path = $parts[0]
  $expected = $parts[1].Trim().ToUpperInvariant()

  if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "MISSING: $path" -ForegroundColor Red
    $failed = $true
    continue
  }

  $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
  if ($actual -ne $expected) {
    Write-Host "CHANGED: $path" -ForegroundColor Red
    Write-Host "  Expected: $expected" -ForegroundColor DarkRed
    Write-Host "  Actual:   $actual" -ForegroundColor DarkRed
    $failed = $true
  } else {
    Write-Host "OK: $path" -ForegroundColor Green
  }
}

if ($failed) {
  exit 1
}

Write-Host "All protected files match baseline." -ForegroundColor Green
exit 0
