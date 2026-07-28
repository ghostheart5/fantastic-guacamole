$ErrorActionPreference = 'Stop'

$depsDirPreferred = 'tools'
$depsDirAlt = 'tool'

$outputPath = if (Test-Path $depsDirPreferred) {
  Join-Path $depsDirPreferred 'deps.txt'
} elseif (Test-Path $depsDirAlt) {
  Join-Path $depsDirAlt 'deps.txt'
} else {
  New-Item -ItemType Directory -Path $depsDirPreferred | Out-Null
  Join-Path $depsDirPreferred 'deps.txt'
}

"ChronoSpark Dependency Audit" | Set-Content -Path $outputPath -Encoding UTF8
"Generated: $(Get-Date -Format o)" | Add-Content -Path $outputPath

function Invoke-And-Log {
  param(
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Command
  )

  $header = "`n===== $Title ====="
  Write-Host $header
  $header | Add-Content -Path $outputPath
  "Command: $Command" | Add-Content -Path $outputPath

  Invoke-Expression $Command 2>&1 | Tee-Object -FilePath $outputPath -Append

  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $Title (exit code $LASTEXITCODE)"
  }
}

Invoke-And-Log -Title 'Outdated Dependencies (Transitive)' -Command 'flutter pub outdated --transitive'
Invoke-And-Log -Title 'Outdated Dependencies (No Overrides)' -Command 'flutter pub outdated --no-dependency-overrides'
Invoke-And-Log -Title 'Dependency Tree Compact' -Command 'flutter pub deps --style=compact'

$pubspecPath = 'pubspec.yaml'
if (Test-Path $pubspecPath) {
  $pubspecText = Get-Content $pubspecPath -Raw

  "`n===== Dependency Risk Flags =====" | Add-Content -Path $outputPath

  if ($pubspecText -match '(?m)^dependency_overrides\s*:') {
    'FLAG: dependency_overrides present.' | Tee-Object -FilePath $outputPath -Append
  } else {
    'OK: dependency_overrides not present.' | Tee-Object -FilePath $outputPath -Append
  }

  if ($pubspecText -match '(?m)^\s*[a-zA-Z0-9_\-]+\s*:\s*any\s*$') {
    'FLAG: one or more dependencies use any constraints.' | Tee-Object -FilePath $outputPath -Append
  } else {
    'OK: no any dependency constraints found.' | Tee-Object -FilePath $outputPath -Append
  }
}

Write-Host "Dependency audit complete. Output written to $outputPath"
