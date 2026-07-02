Write-Host "🧠 FULL SYSTEM AUDIT START"
Write-Host "====================================="

$root = "lib"

# -----------------------------
# TRACK RESULTS
# -----------------------------
$unused = 0
$used = 0
$placeholders = 0
$violations = 0
$emptyFiles = 0

# -----------------------------
# FIND ALL DART FILES
# -----------------------------
$files = Get-ChildItem -Recurse -Filter *.dart -Path $root

foreach ($file in $files) {

    $name = $file.Name
    $content = Get-Content $file.FullName -ErrorAction SilentlyContinue

    # -------------------------
    # EMPTY FILE CHECK
    # -------------------------
    if ($content.Length -lt 3) {
        Write-Host "[EMPTY ❌] $($file.FullName)"
        $emptyFiles++
        continue
    }

    # -------------------------
    # PLACEHOLDER DETECTION
    # -------------------------
    if ($file.Name -match "placeholder") {
        Write-Host "[PLACEHOLDER ⚠] $($file.FullName)"
        $placeholders++
    }

    # -------------------------
    # USAGE CHECK (REFERENCE)
    # -------------------------
    $refs = Select-String -Path "$root\**\*.dart" -Pattern $name -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -ne $file.FullName } |
        Measure-Object | Select-Object -ExpandProperty Count

    if ($refs -gt 0) {
        $used++
    } else {
        Write-Host "[UNUSED ❌] $($file.FullName)"
        $unused++
    }

    # -------------------------
    # ARCHITECTURE VIOLATION
    # -------------------------
    $text = $content -join "`n"

    if ($file.FullName -match "features" -and ($text -match "engine/" -or $text -match "data/")) {
        Write-Host "[VIOLATION 🔥 UI->ENGINE] $($file.FullName)"
        $violations++
    }

    if ($file.FullName -match "engine" -and $text -match "state/") {
        Write-Host "[VIOLATION 🔥 ENGINE->STATE] $($file.FullName)"
        $violations++
    }

    if ($file.FullName -match "state" -and $text -match "features/") {
        Write-Host "[VIOLATION 🔥 STATE->UI] $($file.FullName)"
        $violations++
    }
}

# -----------------------------
# CORE FILE CHECKS
# -----------------------------
Write-Host "`n🔍 CORE SYSTEM CHECK"

$coreFiles = @(
    "lib/engine/si/si_core.dart",
    "lib/engine/si/response_engine.dart",
    "lib/engine/si/si_ai_service.dart",
    "lib/state/controllers/learning_controller.dart",
    "lib/state/controllers/insight_controller.dart"
)

foreach ($path in $coreFiles) {
    if (!(Test-Path $path)) {
        Write-Host "[MISSING ❌] $path"
    } else {
        Write-Host "[OK ✅] $path"
    }
}

# -----------------------------
# AI CONNECTION CHECKS
# -----------------------------
Write-Host "`n🤖 AI CONNECTION CHECK"

$aiChecks = @(
    "aiResponseProvider",
    "SIAIService",
    "SIEngine",
    "generateThought"
)

foreach ($term in $aiChecks) {
    $results = Select-String -Path "$root\**\*.dart" -Pattern $term -ErrorAction SilentlyContinue
    if ($results) {
        Write-Host "[CONNECTED ✅] $term"
    } else {
        Write-Host "[MISSING CONNECTION ❌] $term"
    }
}

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "`n====================================="
Write-Host "📊 AUDIT SUMMARY"
Write-Host "Used files: $used"
Write-Host "Unused files: $unused"
Write-Host "Placeholders: $placeholders"
Write-Host "Empty files: $emptyFiles"
Write-Host "Violations: $violations"
Write-Host "====================================="



Write-Host "🧠 Running FULL SYSTEM AUDIT..."
Write-Host ""

# =========================
# 1. EMPTY FILES / FOLDERS
# =========================
Write-Host "🔍 Checking empty files..."
Get-ChildItem -Recurse -File lib | Where-Object { $_.Length -eq 0 } | ForEach-Object {
  Write-Host "❌ Empty file: $($_.FullName)"
}

Write-Host ""
Write-Host "📁 Checking empty folders..."
Get-ChildItem lib -Recurse | Where-Object { $_.PSIsContainer -and !(Get-ChildItem $_.FullName) } | ForEach-Object {
  Write-Host "⚠️ Empty folder: $($_.FullName)"
}

# =========================
# 2. TODO / PLACEHOLDERS
# =========================
Write-Host ""
Write-Host "🧩 Searching TODO / placeholder code..."
Select-String -Path "lib\**\*.dart" -Pattern "TODO|placeholder|mock|not implemented" -CaseSensitive:$false | ForEach-Object {
  Write-Host "⚠️ $($_.Path):$($_.LineNumber) → $($_.Line.Trim())"
}

# =========================
# 3. IMPORT ERRORS
# =========================
Write-Host ""
Write-Host "🔗 Checking import paths..."

Select-String -Path "lib\**\*.dart" -Pattern "import" | ForEach-Object {
  if ($_.Line -match "'(.+?)'") {
    $path = $Matches[1]
    if ($path.StartsWith("package:") -eq $false -and $path.EndsWith(".dart")) {
      $fullPath = Join-Path (Split-Path $_.Path) $path
      if (!(Test-Path $fullPath)) {
        Write-Host "❌ Missing import: $($_.Path) → $path"
      }
    }
  }
}

# =========================
# 4. DUPLICATE CLASS NAMES
# =========================
Write-Host ""
Write-Host "🧠 Checking duplicate classes..."

$classes = @{}
Select-String -Path "lib\**\*.dart" -Pattern "class\s+(\w+)" | ForEach-Object {
  $name = $Matches[1]
  if ($classes.ContainsKey($name)) {
    Write-Host "❌ Duplicate class: $name"
  } else {
    $classes[$name] = 1
  }
}

# =========================
# 5. CORE SYSTEM CHECK
# =========================
Write-Host ""
Write-Host "⚙️ Checking core wiring..."

$coreFiles = @(
  "lib/engine/si/si_engine.dart",
  "lib/engine/learning/adaptive_learning.dart",
  "lib/state/controllers/ai_controller.dart",
  "lib/features/home/smart_coach_screen.dart"
)

foreach ($file in $coreFiles) {
  if (!(Test-Path $file)) {
    Write-Host "❌ Missing core file: $file"
  } else {
    Write-Host "✅ Found: $file"
  }
}

# =========================
# 6. PROVIDER CONNECTION CHECK
# =========================
Write-Host ""
Write-Host "🔌 Checking provider usage..."

Select-String -Path "lib\**\*.dart" -Pattern "Provider" | Measure-Object

# =========================
# 7. LOGGING PRESENCE
# =========================
Write-Host ""
Write-Host "📊 Checking logging usage..."

$logs = Select-String -Path "lib\**\*.dart" -Pattern "Logger\.log"
if ($logs.Count -eq 0) {
  Write-Host "⚠️ No logging found → system not observable"
} else {
  Write-Host "✅ Logging found ($($logs.Count) occurrences)"
}

# =========================
# 8. FINAL FLUTTER ANALYZE
# =========================
Write-Host ""
Write-Host "🧪 Running flutter analyze..."
flutter analyze

Write-Host ""
Write-Host "✅ AUDIT COMPLETE"


Write-Host "🧠 Running STRUCTURE AUDIT..."
Write-Host ""

# =========================
# EXPECTED STRUCTURE
# =========================
$expected = @(
  "lib/app/app.dart",
  "lib/app/app_root.dart",
  "lib/app/navigation_shell.dart",

  "lib/core/debug/logger.dart",
  "lib/core/navigation/app_router.dart",
  "lib/core/services/data_migration.dart",
  "lib/core/theme/app_theme.dart",

  "lib/data/models/task.dart",
  "lib/data/models/models.dart",
  "lib/data/models/notification.dart",
  "lib/data/models/decision.dart",

  "lib/data/repositories/task_repository.dart",
  "lib/data/sources/asset_loader.dart",

  "lib/engine/si/si_engine.dart",
  "lib/engine/si/si_state.dart",
  "lib/engine/si/si_core.dart",
  "lib/engine/si/ai_response.dart",
  "lib/engine/si/si_ai_service.dart",
  "lib/engine/si/decision.dart",

  "lib/engine/learning/learning_state.dart",
  "lib/engine/learning/adaptive_learning.dart",

  "lib/state/controllers/ai_controller.dart",
  "lib/state/controllers/learning_controller.dart",

  "lib/state/providers/energy_provider.dart",
  "lib/state/providers/task_provider.dart",
  "lib/state/providers/notification_provider.dart",

  "lib/features/home/smart_coach_screen.dart",
  "lib/features/focus/focus_screen.dart",
  "lib/features/tasks/tasks_screen.dart",
  "lib/features/tasks/widgets/task_card.dart",
  "lib/features/insights/insights_screen.dart",
  "lib/features/insights/insight_engine.dart",
  "lib/features/insights/insight_model.dart",
  "lib/features/si_console/si_console_screen.dart",
  "lib/features/profile/profile_screen.dart",

  "lib/widgets/app_background.dart",
  "lib/widgets/app_card.dart",
  "lib/widgets/debug_panel.dart"
)

# =========================
# CHECK FILES
# =========================
Write-Host "📁 Checking required files..."

foreach ($file in $expected) {
  if (!(Test-Path $file)) {
    Write-Host "❌ Missing: $file"
  } else {
    Write-Host "✅ Found: $file"
  }
}

# =========================
# CHECK CORE FOLDERS
# =========================
Write-Host ""
Write-Host "📂 Checking critical folders..."

$folders = @(
  "lib/engine/si",
  "lib/engine/learning",
  "lib/features/home",
  "lib/features/tasks",
  "lib/features/insights",
  "lib/state/providers",
  "lib/state/controllers",
  "lib/widgets"
)

foreach ($folder in $folders) {
  if (!(Test-Path $folder)) {
    Write-Host "❌ Missing folder: $folder"
  } else {
    Write-Host "✅ Found folder: $folder"
  }
}

# =========================
# OPTIONAL: EXTRA FILES CHECK
# =========================
Write-Host ""
Write-Host "🔎 Looking for unexpected files..."

$allFiles = Get-ChildItem -Recurse -File lib | Select-Object -ExpandProperty FullName

foreach ($file in $allFiles) {
  $relative = $file.Replace((Get-Location).Path + "\", "")
  if ($expected -notcontains $relative) {
    if ($file -like "*.dart") {
      Write-Host "⚠️ Extra file: $relative"
    }
  }
}

# =========================
# SUMMARY
# =========================
Write-Host ""
Write-Host "✅ STRUCTURE AUDIT COMPLETE"
