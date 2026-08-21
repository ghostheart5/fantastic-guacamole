[CmdletBinding()]
param(
  [switch]$SkipFullTests,
  [switch]$SkipDebugBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location -LiteralPath $repoRoot

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Label,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command
  )

  Write-Host "`n[$Label]"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

$phaseLineage = @(
  @{ Phase = 1; Commit = '5946f0b4'; Subject = 'feat: isolate planner and SI assistant runtimes' },
  @{ Phase = 2; Commit = 'b738cb6e'; Subject = 'feat: add typed assistant boundaries' },
  @{ Phase = 3; Commit = 'e8780d95'; Subject = 'feat: add assistant evidence plane' },
  @{ Phase = 4; Commit = 'c9dafada'; Subject = 'feat: unify SI console shortcuts' },
  @{ Phase = 5; Commit = '798689f8'; Subject = 'feat(planner): implement read-only Planner V2' },
  @{ Phase = 6; Commit = '9daa4f43'; Subject = 'feat(creator): add confirmed mutation handshake' },
  @{ Phase = 7; Commit = '91028cc7'; Subject = 'feat(si): rebuild console with read-only evidence lens' },
  @{ Phase = 8; Commit = '75f34725'; Subject = 'feat: add phase 8 memory governance' },
  @{ Phase = 9; Commit = '71f39be5'; Subject = 'feat: add phase 9 assistant safety critic' },
  @{ Phase = 10; Commit = '5f93f17e'; Subject = 'feat: add phase 10 assistant accessibility' },
  @{ Phase = 11; Commit = '8edde268'; Subject = 'feat: add phase 11 controlled assistant release' }
)

Write-Host '[Assistant rebuild lineage]'
foreach ($entry in $phaseLineage) {
  & git merge-base --is-ancestor $entry.Commit HEAD
  if ($LASTEXITCODE -ne 0) {
    throw "Phase $($entry.Phase) commit $($entry.Commit) is not an ancestor of HEAD."
  }
  $actualSubject = (& git show -s --format=%s $entry.Commit).Trim()
  if ($LASTEXITCODE -ne 0 -or $actualSubject -ne $entry.Subject) {
    throw "Phase $($entry.Phase) lineage mismatch at $($entry.Commit)."
  }
  Write-Host "Phase $($entry.Phase): $($entry.Commit) $actualSubject"
}

Invoke-Checked -Label 'Architecture' -Command {
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\check_architecture.ps1
}

Invoke-Checked -Label 'Static analysis' -Command {
  & flutter analyze --no-fatal-infos
}

if (-not $SkipFullTests) {
  Invoke-Checked -Label 'Full Flutter test suite' -Command {
    & flutter test
  }
}

if (-not $SkipDebugBuild) {
  Invoke-Checked -Label 'Debug Android build' -Command {
    & flutter build apk --debug
  }
}

$headSha = (& git rev-parse HEAD).Trim()
Write-Host "`nASSISTANT REBUILD IMPLEMENTATION VERIFIED"
Write-Host "HEAD: $headSha"
Write-Host 'Live launch authorization still requires three complete production evidence windows.'
