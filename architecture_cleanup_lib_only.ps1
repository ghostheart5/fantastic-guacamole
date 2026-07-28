$ErrorActionPreference = "Stop"

Write-Host "Starting app architecture cleanup pass..." -ForegroundColor Cyan
Write-Host "Scope: lib only. Tests are intentionally ignored." -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archiveRoot = ".\.dead_code_archive_architecture_$timestamp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

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

function Write-Utf8 {
  param(
    [string]$Path,
    [string]$Content
  )

  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# ------------------------------------------------------------
# 1. Clean old temporary/backup folder if present.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 1: Archiving old cleanup backup folders..." -ForegroundColor Cyan

if (Test-Path ".\backup_timeline_history_cleanup") {
  Move-ToArchive ".\backup_timeline_history_cleanup"
}

# ------------------------------------------------------------
# 2. Quarantine orphaned Tasks feature if no lib references remain.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 2: Checking orphaned Tasks feature..." -ForegroundColor Cyan

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
  Write-Host "Tasks feature still has lib references. Not archiving yet:" -ForegroundColor Yellow
  $taskRefs | Select-Object Path,LineNumber,Line
}

# ------------------------------------------------------------
# 3. Quarantine orphaned Milestones feature if no lib references remain.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 3: Checking orphaned Milestones feature..." -ForegroundColor Cyan

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
  Write-Host "Milestones feature still has lib references. Not archiving yet:" -ForegroundColor Yellow
  $milestoneRefs | Select-Object Path,LineNumber,Line
}

# ------------------------------------------------------------
# 4. Preserve internal Soul Map dependencies but remove user-facing wording.
# Internal soul_map_provider / soul_map_models should stay for SI pipeline until migrated.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 4: Cleaning user-facing Soul Map wording only..." -ForegroundColor Cyan

$wordingFiles = @(
  ".\lib\features\home\ui\smart_coach_screen.dart",
  ".\lib\tutorial\tutorial_content.dart",
  ".\lib\features\si_console\ui\si_console_screen.dart"
)

foreach ($file in $wordingFiles) {
  if (-not (Test-Path $file)) {
    continue
  }

  Copy-Item $file "$file.bak_arch_wording" -Force

  $text = Get-Content $file -Raw

  # User-facing wording only. Do not rename classes/providers/imports.
  $text = $text.Replace("SOUL MAP", "TIMELINE")
  $text = $text.Replace("Soul Map", "Timeline")
  $text = $text.Replace("soul map", "timeline")

  $text = $text.Replace("GOALS WORKSPACE", "CREATOR WORKSPACE")
  $text = $text.Replace("Goals Workspace", "Creator Workspace")
  $text = $text.Replace("ALIGN GOALS", "OPEN CREATOR")

  $text = $text.Replace("ACTIVITY LEDGER", "TIMELINE")
  $text = $text.Replace("Activity Ledger", "Timeline")

  Write-Utf8 $file $text
  Write-Host "Cleaned wording: $file" -ForegroundColor Green
}

# ------------------------------------------------------------
# 5. Smart Coach specific cleanup checks.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 5: Smart Coach surface cleanup..." -ForegroundColor Cyan

$smartCoach = ".\lib\features\home\ui\smart_coach_screen.dart"

if (Test-Path $smartCoach) {
  Copy-Item $smartCoach "$smartCoach.bak_arch_smartcoach" -Force

  $text = Get-Content $smartCoach -Raw

  # Route removed surfaces to Creator/Timeline.
  $text = $text.Replace(".toSoulMap()", ".toTimeline()")
  $text = $text.Replace("AppView.soulMap", "AppView.timeline")
  $text = $text.Replace(".toGoals()", ".toCreator()")
  $text = $text.Replace("AppView.goals", "AppView.creator")
  $text = $text.Replace(".toTasks()", ".toCreator()")
  $text = $text.Replace("AppView.tasks", "AppView.creator")

  # Old recommended task surface should not be on Smart Coach as a task block.
  $text = $text.Replace("RECOMMENDED TASK", "COACHING SIGNAL")
  $text = $text.Replace("Recommended Task", "Coaching Signal")

  Write-Utf8 $smartCoach $text
  Write-Host "Patched Smart Coach removed-surface references." -ForegroundColor Green
}

# ------------------------------------------------------------
# 6. Navigation sanity: Nexus should not be a bottom nav item label.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 6: Navigation sanity check..." -ForegroundColor Cyan

$navFile = ".\lib\app\navigation_shell.dart"

if (Test-Path $navFile) {
  Copy-Item $navFile "$navFile.bak_arch_nav" -Force

  $text = Get-Content $navFile -Raw

  # The app may still default to Nexus internally, but bottom tab label should not expose Nexus.
  $text = $text.Replace(
    "_navItem(AppAssets.iconNexus, 'Nexus', tabIndex == 0)",
    "_navItem(AppAssets.iconNexus, 'Coach', tabIndex == 0)"
  )

  # If tab 0 still routes to Nexus directly, send it to Coach.
  $text = $text.Replace(
"        controller.toNexus();
        break;
      case 1:",
"        controller.toSmartCoach();
        break;
      case 1:"
  )

  Write-Utf8 $navFile $text
  Write-Host "Navigation sanity patch applied." -ForegroundColor Green
}

# ------------------------------------------------------------
# 7. Progression + Timeline back buttons should return to Profile.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 7: Back button behavior..." -ForegroundColor Cyan

$backRouteFiles = @(
  ".\lib\features\timeline\ui\timeline_screen.dart",
  ".\lib\features\progression\ui\progression_screen.dart"
)

foreach ($file in $backRouteFiles) {
  if (-not (Test-Path $file)) {
    continue
  }

  Copy-Item $file "$file.bak_arch_back" -Force

  $text = Get-Content $file -Raw
  $text = $text.Replace(
    "ref.read(appFlowProvider.notifier).toNexus()",
    "ref.read(appFlowProvider.notifier).toProfile()"
  )

  Write-Utf8 $file $text
  Write-Host "Back route patched to Profile: $file" -ForegroundColor Green
}

# ------------------------------------------------------------
# 8. Audit remaining removed user-facing surfaces.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Step 8: Remaining removed-surface references..." -ForegroundColor Cyan

$remaining = Select-String `
  -Path .\lib\**\*.dart `
  -Pattern "TaskScreen|MilestonesScreen|AppView\.tasks|AppView\.milestones|toTasks\(|toMilestones\(|toSoulMap\(|AppView\.soulMap|Soul Map|SOUL MAP|Activity Ledger|ACTIVITY LEDGER|LogsScreen|logs_screen" `
  -ErrorAction SilentlyContinue

if ($remaining) {
  Write-Host "Remaining references found. Review below:" -ForegroundColor Yellow
  $remaining | Select-Object Path,LineNumber,Line
} else {
  Write-Host "No removed-surface references found in lib." -ForegroundColor Green
}

# ------------------------------------------------------------
# 9. Format and analyze.
# ------------------------------------------------------------
Write-Host ""
Write-Host "Formatting lib..." -ForegroundColor Cyan
dart format .\lib

Write-Host ""
Write-Host "Analyzing lib..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Architecture cleanup pass complete." -ForegroundColor Green
Write-Host "Archive folder: $archiveRoot" -ForegroundColor Green
