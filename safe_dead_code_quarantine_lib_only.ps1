$ErrorActionPreference = "Stop"

Write-Host "Starting lib-only dead-code quarantine..." -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archiveRoot = ".\.dead_code_archive_lib_only_$timestamp"

New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null

function Move-ToArchive {
  param(
    [string]$Path
  )

  if (-not (Test-Path $Path)) {
    Write-Host "Missing, skipping: $Path" -ForegroundColor DarkGray
    return
  }

  $safeName = $Path.Replace(".\", "").Replace("\", "__").Replace("/", "__").Replace(":", "")
  $target = Join-Path $archiveRoot $safeName

  Move-Item $Path $target -Force
  Write-Host "Archived: $Path -> $target" -ForegroundColor Green
}

function Find-LibRefs {
  param(
    [string[]]$Patterns
  )

  $results = @()

  foreach ($pattern in $Patterns) {
    $matches = Select-String `
      -Path .\lib\**\*.dart `
      -Pattern $pattern `
      -ErrorAction SilentlyContinue

    if ($matches) {
      $results += $matches
    }
  }

  return $results
}

# ------------------------------------------------------------
# 1. Remove old backup folder from prior cleanup.
# ------------------------------------------------------------
if (Test-Path ".\backup_timeline_history_cleanup") {
  Move-ToArchive ".\backup_timeline_history_cleanup"
}

# ------------------------------------------------------------
# 2. Tasks feature directory.
# Only archive if lib has no active references.
# ------------------------------------------------------------
$taskRefs = Find-LibRefs @(
  "TaskScreen",
  "features/tasks",
  "task_screen.dart",
  "AppView\.tasks",
  "toTasks\("
)

if ($taskRefs.Count -eq 0) {
  Move-ToArchive ".\lib\features\tasks"
} else {
  Write-Host ""
  Write-Host "Tasks feature still has lib references. Not archiving yet:" -ForegroundColor Yellow
  $taskRefs | Select-Object Path,LineNumber,Line
}

# ------------------------------------------------------------
# 3. Milestones feature directory.
# Only archive if lib has no active references.
# ------------------------------------------------------------
$milestoneRefs = Find-LibRefs @(
  "MilestonesScreen",
  "features/milestones",
  "milestones_screen.dart",
  "AppView\.milestones",
  "toMilestones\("
)

if ($milestoneRefs.Count -eq 0) {
  Move-ToArchive ".\lib\features\milestones"

  Get-ChildItem .\lib -Recurse -Filter "milestones_screen.dart" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Move-ToArchive $_.FullName
    }
} else {
  Write-Host ""
  Write-Host "Milestones feature still has lib references. Not archiving yet:" -ForegroundColor Yellow
  $milestoneRefs | Select-Object Path,LineNumber,Line
}

# ------------------------------------------------------------
# 4. Soul Map files/providers.
# Only archive if lib has no active references.
# ------------------------------------------------------------
$soulRefs = Find-LibRefs @(
  "SoulMap",
  "soulMap",
  "soul_map_provider",
  "Soul Map",
  "SOUL MAP"
)

if ($soulRefs.Count -eq 0) {
  Get-ChildItem .\lib -Recurse -Filter "*soul_map*" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Move-ToArchive $_.FullName
    }
} else {
  Write-Host ""
  Write-Host "Soul Map still has lib references. Not archiving yet:" -ForegroundColor Yellow
  $soulRefs | Select-Object Path,LineNumber,Line
}

Write-Host ""
Write-Host "Formatting lib..." -ForegroundColor Cyan
dart format .\lib

Write-Host ""
Write-Host "Analyzing lib..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Lib-only dead-code quarantine complete." -ForegroundColor Green
Write-Host "Archive folder: $archiveRoot" -ForegroundColor Green
