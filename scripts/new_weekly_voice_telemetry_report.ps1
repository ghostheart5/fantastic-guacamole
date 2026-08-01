param(
  [string]$WeekOf,
  [string]$Owner = 'Unassigned',
  [string]$OutputDir = 'docs',
  [string[]]$LogFiles = @('runlog.txt', 'launch_log.txt', 'crashlog.txt')
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

function Get-ResolvedLogPaths {
  param(
    [string]$RepoRoot,
    [string[]]$Candidates
  )

  $paths = New-Object System.Collections.Generic.List[string]
  foreach ($candidate in $Candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      continue
    }

    $resolved = if ([System.IO.Path]::IsPathRooted($candidate)) {
      $candidate
    } else {
      Join-Path $RepoRoot $candidate
    }

    if (Test-Path $resolved) {
      $paths.Add($resolved)
    }
  }

  return $paths
}

function Get-VoiceEventCounts {
  param([string[]]$Files)

  $eventRegex = [regex]'\bvoice_[a-z_]+\b'
  $counts = @{}
  $lineCount = 0

  foreach ($file in $Files) {
    foreach ($line in Get-Content -Path $file) {
      $lineCount++
      $match = $eventRegex.Match($line)
      if (-not $match.Success) {
        continue
      }

      $eventName = $match.Value
      if (-not $counts.ContainsKey($eventName)) {
        $counts[$eventName] = 0
      }
      $counts[$eventName]++
    }
  }

  return [pscustomobject]@{
    Counts = $counts
    LinesScanned = $lineCount
  }
}

$weekDate = Resolve-WeekOfDate -WeekOfInput $WeekOf
$weekToken = $weekDate.ToString('yyyy-MM-dd')

$resolvedOutputDir = Join-Path $root $OutputDir
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$reportPath = Join-Path $resolvedOutputDir ("weekly_voice_telemetry_report_{0}.txt" -f $weekToken)
if (Test-Path $reportPath) {
  Write-Host "Report already exists: $reportPath"
  exit 0
}

$resolvedLogFiles = Get-ResolvedLogPaths -RepoRoot $root -Candidates $LogFiles
$voiceData = Get-VoiceEventCounts -Files $resolvedLogFiles
$counts = $voiceData.Counts

$knownEvents = @(
  'voice_mic_tapped',
  'voice_permission_result',
  'voice_listening_started',
  'voice_capture_result',
  'voice_command_parsed',
  'voice_command_routed',
  'voice_timeline_summary'
)

function Count-OrZero {
  param(
    [hashtable]$Map,
    [string]$Name
  )

  if ($Map.ContainsKey($Name)) {
    return [int]$Map[$Name]
  }
  return 0
}

$eventRows = foreach ($name in $knownEvents) {
  "- ${name}: $(Count-OrZero -Map $counts -Name $name)"
}

$logSourcesText = if ($resolvedLogFiles.Count -gt 0) {
  ($resolvedLogFiles | ForEach-Object {
    try {
      Resolve-Path -Path $_ -Relative
    } catch {
      $_
    }
  }) -join ', '
} else {
  'none found'
}

$template = @"
WEEKLY VOICE TELEMETRY REPORT

Week of: $weekToken
Owner: $Owner
Generated: $(Get-Date -Format s)

1) Data sources scanned
- Local log sources: $logSourcesText
- Total lines scanned: $($voiceData.LinesScanned)

2) Local event totals (from logs)
$($eventRows -join "`n")

3) Firebase analytics metrics (fill from dashboard/export)
- Top 5 intents by count (7d):
- Fallback count (outcome=fallback):
- Permission denied count (outcome=permission_denied):
- UI-confirmation-required count:
- Timeline summary usage split (today vs overdue):

4) Derived weekly KPIs
- Voice command parse volume trend (WoW):
- Successful route rate = success / voice_command_routed:
- Fallback rate = fallback / voice_command_routed:
- Capture success rate = captured=true / voice_capture_result:

5) Risks and quality signals
- High fallback intents:
- Commands with ambiguous phrasing:
- Permission friction observations:
- Any accidental high-risk auto-action observed: YES / NO

6) Actions for next cycle
- Parser phrase expansion targets:
- UX copy tweaks for command guidance:
- Accessibility improvements:
- Validation plan:

Notes:
- Local logs include event names only. Outcome/intent parameter splits require Firebase Analytics views or export.
"@

Set-Content -Path $reportPath -Value $template -NoNewline
Write-Host "Created weekly voice telemetry report: $reportPath"
