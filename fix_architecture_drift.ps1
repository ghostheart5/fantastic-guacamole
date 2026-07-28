$ErrorActionPreference = "Stop"

Write-Host "Running navigation and architecture correction pass..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$navFile = ".\lib\app\navigation_shell.dart"
$nexusWidgetsFile = ".\lib\features\nexus\ui\nexus_screen.widgets.dart"
$tutorialFile = ".\lib\tutorial\tutorial_content.dart"
$timelineFile = ".\lib\features\timeline\ui\timeline_screen.dart"
$progressionFile = ".\lib\features\progression\ui\progression_screen.dart"

foreach ($file in @($navFile, $nexusWidgetsFile, $tutorialFile, $timelineFile, $progressionFile)) {
  if (Test-Path $file) {
    Copy-Item $file "$file.bak_arch_fix" -Force
  }
}

# ------------------------------------------------------------
# 1. Navigation shell: bottom nav should not expose Nexus as a tab.
# Tab 0 becomes Smart Coach.
# ------------------------------------------------------------
if (Test-Path $navFile) {
  $text = Get-Content $navFile -Raw

  # Bottom tab view mapping: stop sending tab 0 to Nexus.
  $text = $text.Replace(
"      AppView.nexus || AppView.coach => AppView.nexus,",
"      AppView.nexus || AppView.coach => AppView.coach,"
  )

  # If there is a default bottom-tab fallback to Nexus, use Coach instead.
  $text = $text.Replace(
"      _ => AppView.nexus,",
"      _ => AppView.coach,"
  )

  # Tab 0 index can still include Nexus only for highlight fallback, but Nexus should not be an item label.
  $text = $text.Replace(
"            _navItem(AppAssets.iconNexus, 'Nexus', tabIndex == 0),",
"            _navItem(AppAssets.iconNexus, 'Coach', tabIndex == 0),"
  )

  # First tab tap should go to Coach, not Nexus.
  $text = $text.Replace(
"        controller.toNexus();
        break;
      case 1:",
"        controller.toSmartCoach();
        break;
      case 1:"
  )

  # Some controllers use toCoach instead of toSmartCoach. If toSmartCoach does not exist,
  # analyzer will catch it and we patch next.
  [System.IO.File]::WriteAllText($navFile, $text, $utf8NoBom)
  Write-Host "Patched bottom navigation away from Nexus." -ForegroundColor Green
}

# ------------------------------------------------------------
# 2. Nexus Action Hub: replace old Plan View with Creator/Timeline direction
# and add Progression as a real action.
# ------------------------------------------------------------
if (Test-Path $nexusWidgetsFile) {
  $text = Get-Content $nexusWidgetsFile -Raw

  # Old Plan View should not be a primary merged surface.
  $text = $text.Replace("label: 'Plan View'", "label: 'Timeline'")
  $text = $text.Replace(".toPlan()", ".toTimeline()")

  # Add Progression button after Timeline in compact branch, if missing.
  if ($text -notmatch "label: 'Progression'") {
    $text = $text.Replace(
"            HoloButton(
              label: 'Timeline',
              color: AppColors.memoryAmber,
              onTap: () => ref.read(appFlowProvider.notifier).toTimeline(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'SI Console',",
"            HoloButton(
              label: 'Timeline',
              color: AppColors.memoryAmber,
              onTap: () => ref.read(appFlowProvider.notifier).toTimeline(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'Progression',
              color: AppColors.memoryAmber,
              onTap: () => ref.read(appFlowProvider.notifier).toProgression(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'SI Console',"
    )

    # Add Progression row after Timeline/Creator area in wide branch.
    $text = $text.Replace(
"            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: HoloButton(
                    label: 'SI Console',",
"            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: HoloButton(
                    label: 'Progression',
                    color: AppColors.memoryAmber,
                    onTap: () =>
                        ref.read(appFlowProvider.notifier).toProgression(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: HoloButton(
                    label: 'SI Console',"
    )
  }

  # Fix corrupted middle dot if present.
  $text = $text.Replace("·", "-")

  [System.IO.File]::WriteAllText($nexusWidgetsFile, $text, $utf8NoBom)
  Write-Host "Patched Nexus Action Hub with Progression and Timeline direction." -ForegroundColor Green
}

# ------------------------------------------------------------
# 3. Timeline and Progression back buttons should return to Profile.
# ------------------------------------------------------------
foreach ($file in @($timelineFile, $progressionFile)) {
  if (Test-Path $file) {
    $text = Get-Content $file -Raw
    $text = $text.Replace(
      "ref.read(appFlowProvider.notifier).toNexus()",
      "ref.read(appFlowProvider.notifier).toProfile()"
    )
    [System.IO.File]::WriteAllText($file, $text, $utf8NoBom)
    Write-Host "Patched back route to Profile: $file" -ForegroundColor Green
  }
}

# ------------------------------------------------------------
# 4. Tutorial/user-facing wording cleanup.
# Keep internal goals domain intact; only tutorial wording changes.
# ------------------------------------------------------------
if (Test-Path $tutorialFile) {
  $text = Get-Content $tutorialFile -Raw

  $text = $text.Replace("GOALS WORKSPACE", "CREATOR WORKSPACE")
  $text = $text.Replace("Goals Workspace", "Creator Workspace")
  $text = $text.Replace("ALIGN GOALS", "OPEN CREATOR")
  $text = $text.Replace("Creating Goals", "Creating Outcomes")
  $text = $text.Replace("SOUL MAP", "TIMELINE")
  $text = $text.Replace("Soul Map", "Timeline")
  $text = $text.Replace(
    "Use Timeline regularly to detect drift between values and daily execution patterns.",
    "Use Timeline regularly to review history, detect drift, and course-correct execution."
  )
  $text = $text.Replace(
    "Use Creator regularly to detect drift between values and daily execution patterns.",
    "Use Timeline regularly to review history, detect drift, and course-correct execution."
  )

  [System.IO.File]::WriteAllText($tutorialFile, $text, $utf8NoBom)
  Write-Host "Patched tutorial wording away from Soul Map and standalone Goals." -ForegroundColor Green
}

Write-Host ""
Write-Host "Formatting touched files..." -ForegroundColor Cyan
dart format $navFile $nexusWidgetsFile $tutorialFile $timelineFile $progressionFile

Write-Host ""
Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Architecture correction pass complete." -ForegroundColor Green
