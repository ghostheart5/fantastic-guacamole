param(
  [string]$WeekOf,
  [string]$Owner = 'Unassigned',
  [string]$OutputDir = 'docs'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Resolve-WeekOfDate {
  param([string]$WeekOfInput)

  if (-not [string]::IsNullOrWhiteSpace($WeekOfInput)) {
    $parsed = [DateTime]::MinValue
    if (-not [DateTime]::TryParse($WeekOfInput, [ref]$parsed)) {
      throw "Invalid WeekOf value '$WeekOfInput'. Use a date like 2026-07-31."
    }
    return $parsed.Date
  }

  return (Get-Date).Date
}

$weekDate = Resolve-WeekOfDate -WeekOfInput $WeekOf
$weekToken = $weekDate.ToString('yyyy-MM-dd')

$resolvedOutputDir = Join-Path $root $OutputDir
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$reportPath = Join-Path $resolvedOutputDir ("weekly_crash_triage_report_{0}.txt" -f $weekToken)
if (Test-Path $reportPath) {
  Write-Host "Report already exists: $reportPath"
  exit 0
}

$template = @"
WEEKLY CRASH TRIAGE REPORT

Week of: $weekToken
Owner: $Owner
Generated: $(Get-Date -Format s)

1) Intake summary
- Fatal crashes (7d):
- Non-fatal top categories (7d):
- Secret exposure review: PASS / FAIL

2) Severity breakdown
- Sev-1 count:
- Sev-2 count:
- Sev-3 count:

3) Assignment and SLA
- Sev-1 owner assigned: YES / NO
- Sev-1 ETA documented: YES / NO
- Sev-2 tracking links present: YES / NO

4) Mitigation status
- Immediate mitigations in place:
- Deferred fixes and rationale:

5) Validation evidence
- Crash observability verifier run: PASS / FAIL
- Targeted subsystem tests run:
- Post-fix verification notes:

6) Release impact
- Buildable: YES / NO
- Play-ready: YES / NO
- Go / No-Go:

7) Actions for next cycle
-
-
-
"@

Set-Content -Path $reportPath -Value $template -NoNewline
Write-Host "Created weekly crash triage report: $reportPath"
