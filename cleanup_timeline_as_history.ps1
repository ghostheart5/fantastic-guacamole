$ErrorActionPreference = "Stop"

Write-Host "Aligning app history architecture: Timeline replaces Logs and Activity Ledger..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$files = Get-ChildItem -Path ".\lib" -Recurse -Filter "*.dart"

# Backup likely affected files.
$backupDir = ".\backup_timeline_history_cleanup"
if (-not (Test-Path $backupDir)) {
  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

foreach ($file in $files) {
  $content = Get-Content $file.FullName -Raw
  if ($content -match "Activity Ledger|ACTIVITY LEDGER|AppView\.logs|toLogs\(|LogsScreen|logs_screen|RoutePaths\.logs|/logs|Logbook|LOGS") {
    $relative = Resolve-Path -Relative $file.FullName
    $safeName = $relative.Replace(".\", "").Replace("\", "__")
    Copy-Item $file.FullName (Join-Path $backupDir $safeName) -Force
  }
}

# Detect current timeline view/controller support.
$appFlowFile = ".\lib\state\controllers\app_flow_controller.dart"
$hasTimelineView = $false
$hasToTimeline = $false

if (Test-Path $appFlowFile) {
  $flowText = Get-Content $appFlowFile -Raw
  $hasTimelineView = $flowText -match "timeline"
  $hasToTimeline = $flowText -match "toTimeline\("
}

$replacementView = if ($hasTimelineView) { "AppView.timeline" } else { "AppView.nexus" }
$replacementMethod = if ($hasToTimeline) { ".toTimeline()" } else { ".toNexus()" }

Write-Host "Replacement view: $replacementView" -ForegroundColor Yellow
Write-Host "Replacement method: $replacementMethod" -ForegroundColor Yellow

foreach ($file in $files) {
  $path = $file.FullName
  $text = Get-Content $path -Raw
  $original = $text

  # User-facing labels.
  $text = $text.Replace("ACTIVITY LEDGER", "TIMELINE")
  $text = $text.Replace("Activity Ledger", "Timeline")
  $text = $text.Replace("activity ledger", "timeline")
  $text = $text.Replace("LOGS", "TIMELINE")
  $text = $text.Replace("Logs", "Timeline")
  $text = $text.Replace("logs", "timeline")

  # Restore package/provider names that should not be blindly renamed.
  $text = $text.Replace("timeline_provider.dart", "timeline_provider.dart")
  $text = $text.Replace("logs_provider.dart", "logs_provider.dart")
  $text = $text.Replace("logsActionsProvider", "logsActionsProvider")
  $text = $text.Replace("logRepositoryProvider", "logRepositoryProvider")
  $text = $text.Replace("LogRepository", "LogRepository")
  $text = $text.Replace("ILogRepository", "ILogRepository")
  $text = $text.Replace("addLogEntry", "addLogEntry")
  $text = $text.Replace("getLogs", "getLogs")

  # Removed app view references.
  $text = $text.Replace("AppView.logs", $replacementView)
  $text = $text.Replace(".toLogs()", $replacementMethod)
  $text = $text.Replace("RoutePaths.logs", "RoutePaths.timeline")

  # Remove stale screen imports if they exist.
  $text = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    "(?m)^import 'package:fantastic_guacamole/.*/logs_screen\.dart';\r?\n",
    ""
  )
  $text = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    "(?m)^import 'package:fantastic_guacamole/.*/activity_ledger.*\.dart';\r?\n",
    ""
  )

  if ($text -ne $original) {
    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
    Write-Host "Updated: $path" -ForegroundColor Green
  }
}

# Clean AppView enum and controller method if logs survived as its own view.
if (Test-Path $appFlowFile) {
  $flow = Get-Content $appFlowFile -Raw

  $flow = [System.Text.RegularExpressions.Regex]::Replace(
    $flow,
    "(?m)^\s*logs,\s*\r?\n",
    ""
  )

  $flow = [System.Text.RegularExpressions.Regex]::Replace(
    $flow,
    "(?m)^\s*void\s+toLogs\(\)\s*=>\s*state\s*=\s*AppView\.[a-zA-Z0-9_]+;\s*\r?\n",
    ""
  )

  [System.IO.File]::WriteAllText($appFlowFile, $flow, $utf8NoBom)
}

Write-Host ""
Write-Host "Formatting app code..." -ForegroundColor Cyan
dart format .\lib

Write-Host ""
Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Remaining user-facing Logs or Activity Ledger references:" -ForegroundColor Cyan
Select-String -Path .\lib\**\*.dart -Pattern "Activity Ledger|ACTIVITY LEDGER|AppView\.logs|toLogs\(|LogsScreen|logs_screen|RoutePaths\.logs" -ErrorAction SilentlyContinue |
  Select-Object Path,LineNumber,Line

Write-Host ""
Write-Host "Timeline is now the single history surface." -ForegroundColor Green
