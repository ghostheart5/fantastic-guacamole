[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

$files = @()
$files += @(Get-ChildItem -LiteralPath $root -File -Filter '*.ps1')
$files += @(Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -File -Filter '*.ps1' -Recurse)
$files = @($files | Sort-Object FullName -Unique)

if ($files.Count -eq 0) {
  throw 'PowerShell parse gate discovered zero maintained scripts.'
}

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $file.FullName,
    [ref]$tokens,
    [ref]$parseErrors
  ) | Out-Null

  foreach ($parseError in @($parseErrors)) {
    $relativePath = $file.FullName.Substring($root.Length).TrimStart('\', '/')
    $failures.Add(
      "${relativePath}:$($parseError.Extent.StartLineNumber):$($parseError.Extent.StartColumnNumber): $($parseError.Message)"
    )
  }
}

if ($failures.Count -gt 0) {
  throw "PowerShell parse gate failed:`n$($failures -join [Environment]::NewLine)"
}

Write-Host "PowerShell parse gate passed for $($files.Count) maintained script(s)." -ForegroundColor Green
