$ErrorActionPreference = "Stop"

Write-Host "Starting architecture correction pass..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$smartCoach = ".\lib\features\home\ui\smart_coach_screen.dart"
$creator = ".\lib\features\creator\ui\creator_screen.dart"
$timeline = ".\lib\features\timeline\ui\timeline_screen.dart"
$progression = ".\lib\features\progression\ui\progression_screen.dart"

foreach ($file in @($smartCoach, $creator, $timeline, $progression)) {
  if (Test-Path $file) {
    Copy-Item $file "$file.bak_architecture_correction" -Force
  }
}

# ------------------------------------------------------------
# 1. Smart Coach cleanup: remove old Goals / Soul Map surface labels.
# ------------------------------------------------------------
if (Test-Path $smartCoach) {
  $text = Get-Content $smartCoach -Raw

  # Remove direct Soul Map navigation calls if any survived.
  $text = $text.Replace(".toSoulMap()", ".toCreator()")
  $text = $text.Replace("AppView.soulMap", "AppView.creator")

  # Replace user-facing Soul Map wording.
  $text = $text.Replace("Soul Map", "Creator")
  $text = $text.Replace("SOUL MAP", "CREATOR")

  # Replace old Goals workspace wording on Smart Coach only.
  $text = $text.Replace("Goals Workspace", "Creator Workspace")
  $text = $text.Replace("GOALS WORKSPACE", "CREATOR WORKSPACE")

  # Remove obvious recommended task remnants.
  $text = $text.Replace("RECOMMENDED TASK", "COACHING SIGNAL")
  $text = $text.Replace("Recommended Task", "Coaching Signal")

  [System.IO.File]::WriteAllText($smartCoach, $text, $utf8NoBom)
  Write-Host "Patched Smart Coach old surface wording." -ForegroundColor Green
}

# ------------------------------------------------------------
# 2. Timeline back button should go to Profile, not Nexus.
# ------------------------------------------------------------
if (Test-Path $timeline) {
  $text = Get-Content $timeline -Raw
  $text = $text.Replace("ref.read(appFlowProvider.notifier).toNexus()", "ref.read(appFlowProvider.notifier).toProfile()")
  [System.IO.File]::WriteAllText($timeline, $text, $utf8NoBom)
  Write-Host "Timeline back button now routes to Profile." -ForegroundColor Green
}

# ------------------------------------------------------------
# 3. Progression back button should go to Profile, not Nexus.
# ------------------------------------------------------------
if (Test-Path $progression) {
  $text = Get-Content $progression -Raw
  $text = $text.Replace("ref.read(appFlowProvider.notifier).toNexus()", "ref.read(appFlowProvider.notifier).toProfile()")
  [System.IO.File]::WriteAllText($progression, $text, $utf8NoBom)
  Write-Host "Progression back button now routes to Profile." -ForegroundColor Green
}

# ------------------------------------------------------------
# 4. Creator: put DynamicForm before the long workbench if needed.
# ------------------------------------------------------------
if (Test-Path $creator) {
  $text = Get-Content $creator -Raw

  $hasWorkbenchBeforeForm = $text.IndexOf("CreatorUnifiedWorkbench(") -ge 0 -and
                            $text.IndexOf("DynamicForm(") -ge 0 -and
                            $text.IndexOf("CreatorUnifiedWorkbench(") -lt $text.IndexOf("DynamicForm(")

  if ($hasWorkbenchBeforeForm) {
    Write-Host "Creator form appears below workbench. Reordering manually with targeted block move..." -ForegroundColor Yellow

    # This is intentionally conservative. If it cannot safely find the blocks, it leaves file unchanged.
    $formStart = $text.IndexOf("                DynamicForm(")
    $workbenchStart = $text.IndexOf("                CreatorUnifiedWorkbench(")

    if ($formStart -gt 0 -and $workbenchStart -gt 0 -and $workbenchStart -lt $formStart) {
      # We will not attempt a complex parse here. Leave signal for manual exact patch.
      Write-Host "Detected order issue. Send CreatorScreen section around workbench/form for exact reorder patch." -ForegroundColor Yellow
    }
  } else {
    Write-Host "Creator form order looks acceptable or could not detect issue." -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Formatting touched feature files..." -ForegroundColor Cyan
dart format .\lib\features\home\ui\smart_coach_screen.dart .\lib\features\creator\ui\creator_screen.dart .\lib\features\timeline\ui\timeline_screen.dart .\lib\features\progression\ui\progression_screen.dart

Write-Host ""
Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Architecture correction pass complete." -ForegroundColor Green
