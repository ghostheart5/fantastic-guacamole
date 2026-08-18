param(
  [string[]]$Roots = @('test', 'integration_test')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$existingRoots = @($Roots | Where-Object { Test-Path -LiteralPath $_ })
if ($existingRoots.Count -eq 0) {
  throw "No test roots found: $($Roots -join ', ')"
}

$testFiles = @(
  Get-ChildItem -Path $existingRoots -Recurse -File -Filter '*_test.dart' |
    Sort-Object FullName
)

if ($testFiles.Count -eq 0) {
  throw "No *_test.dart files found under: $($existingRoots -join ', ')"
}

$pattern = '^\s*(group|test|testWidgets)\s*\(\s*[''"]([^''"]+)[''"]'
$entries = New-Object System.Collections.Generic.List[object]

foreach ($file in $testFiles) {
  $relativePath = Resolve-Path -LiteralPath $file.FullName -Relative
  $lineNumber = 0

  foreach ($line in Get-Content -LiteralPath $file.FullName) {
    $lineNumber += 1
    $match = [regex]::Match($line, $pattern)
    if (-not $match.Success) {
      continue
    }

    $entries.Add([pscustomobject]@{
        Kind = $match.Groups[1].Value
        File = $relativePath
        Line = $lineNumber
        Name = $match.Groups[2].Value
      })
  }
}

if ($entries.Count -eq 0) {
  throw "No group/test/testWidgets declarations found under: $($existingRoots -join ', ')"
}

$entries | Format-Table -AutoSize
Write-Host ""
Write-Host "Discovered $($entries.Count) test declarations across $($testFiles.Count) test files."
