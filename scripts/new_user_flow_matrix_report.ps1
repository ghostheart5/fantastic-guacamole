param(
  [string]$Date,
  [string]$OutputDir = 'docs'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Resolve-ReportDate {
  param([string]$InputDate)

  if ([string]::IsNullOrWhiteSpace($InputDate)) {
    return (Get-Date).Date
  }

  $parsed = [DateTime]::MinValue
  if (-not [DateTime]::TryParse($InputDate, [ref]$parsed)) {
    throw "Invalid Date value '$InputDate'. Use a date like 2026-07-31."
  }

  return $parsed.Date
}

$reportDate = Resolve-ReportDate -InputDate $Date
$token = $reportDate.ToString('yyyy-MM-dd')

$resolvedOutputDir = Join-Path $root $OutputDir
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$reportPath = Join-Path $resolvedOutputDir ("user_flow_integration_matrix_{0}.txt" -f $token)
if (Test-Path $reportPath) {
  Write-Host "Report already exists: $reportPath"
  exit 0
}

$content = @"
USER FLOW INTEGRATION MATRIX

Cycle date: $token
Generated: $(Get-Date -Format s)

Flow,Status,Timestamp,Notes
Auth flow,UNKNOWN,$(Get-Date -Format s),
Navigation flow,UNKNOWN,$(Get-Date -Format s),
Timeline flow,UNKNOWN,$(Get-Date -Format s),
Creator flow,UNKNOWN,$(Get-Date -Format s),
Session lifecycle flow,UNKNOWN,$(Get-Date -Format s),
Integration actions flow,UNKNOWN,$(Get-Date -Format s),

Update the Status column to PASS/FAIL after targeted test execution.
"@

Set-Content -Path $reportPath -Value $content -NoNewline
Write-Host "Created user flow matrix report: $reportPath"
