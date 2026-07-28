$ErrorActionPreference = "Stop"

Write-Host "Starting full project audit completion pass..." -ForegroundColor Cyan
Write-Host "Scope: lib + pubspec. Tests intentionally excluded." -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = ".\full_audit_completion_report_$timestamp.txt"

function Add-Line {
  param([string]$Line)
  Add-Content -Path $reportPath -Value $Line
}

function Add-Section {
  param([string]$Title)
  Add-Line ""
  Add-Line "============================================================"
  Add-Line $Title
  Add-Line "============================================================"
}

function Count-Matches {
  param(
    [string]$Pattern
  )

  $matches = Select-String -Path .\lib\**\*.dart -Pattern $Pattern -ErrorAction SilentlyContinue
  if ($matches) {
    return $matches.Count
  }

  return 0
}

function Write-Matches {
  param(
    [string]$Pattern,
    [int]$Limit = 80
  )

  $matches = Select-String -Path .\lib\**\*.dart -Pattern $Pattern -ErrorAction SilentlyContinue

  if (-not $matches) {
    Add-Line "None"
    return
  }

  $matches |
    Select-Object -First $Limit |
    ForEach-Object {
      Add-Line "$($_.Path):$($_.LineNumber) $($_.Line.Trim())"
    }

  if ($matches.Count -gt $Limit) {
    Add-Line "... truncated. Total matches: $($matches.Count)"
  }
}

function Safe-FileLines {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return 0
  }

  return (Get-Content $Path | Measure-Object -Line).Lines
}

"FULL AUDIT COMPLETION REPORT - $timestamp" | Set-Content $reportPath
Add-Line "Scope: lib + pubspec only. Tests excluded."
Add-Line "Generated from: $(Get-Location)"
Add-Line ""

# ------------------------------------------------------------
# 1. Project snapshot
# ------------------------------------------------------------
Add-Section "1. PROJECT SNAPSHOT"

$dartFiles = Get-ChildItem .\lib -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue
$totalDartFiles = if ($dartFiles) { $dartFiles.Count } else { 0 }
$totalLines = 0

foreach ($file in $dartFiles) {
  $totalLines += Safe-FileLines $file.FullName
}

Add-Line "Dart files in lib: $totalDartFiles"
Add-Line "Approx total Dart lines in lib: $totalLines"

if (Test-Path ".\pubspec.yaml") {
  Add-Line "pubspec.yaml: FOUND"
} else {
  Add-Line "pubspec.yaml: MISSING"
}

if (Test-Path ".\analysis_options.yaml") {
  Add-Line "analysis_options.yaml: FOUND"
} else {
  Add-Line "analysis_options.yaml: MISSING"
}

# ------------------------------------------------------------
# 2. Feature reachability and navigation wiring
# ------------------------------------------------------------
Add-Section "2. FEATURE REACHABILITY AND NAVIGATION WIRING"

Add-Line "AppView references:"
Write-Matches "enum AppView|AppView\.|toNexus\(|toCreator\(|toTimeline\(|toProfile\(|toProgression\(|toSmartCoach\(|toCoach\(|toConsole\(|toSettings\(" 220

Add-Line ""
Add-Line "Navigation shell bottom/nav references:"
if (Test-Path ".\lib\app\navigation_shell.dart") {
  Select-String -Path ".\lib\app\navigation_shell.dart" -Pattern "BottomNavigationBar|NavigationBar|_navItem|AppView\.|toNexus|toCreator|toTimeline|toProfile|toProgression|toSmartCoach|toCoach" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Add-Line "$($_.Path):$($_.LineNumber) $($_.Line.Trim())"
    }
} else {
  Add-Line "navigation_shell.dart not found"
}

Add-Line ""
Add-Line "Router route references:"
if (Test-Path ".\lib\app\router\app_router.dart") {
  Select-String -Path ".\lib\app\router\app_router.dart" -Pattern "RoutePaths\.|GoRoute|redirect|Timeline|Creator|Nexus|Profile|Progression|Settings|SIConsole|logs|timeline" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Add-Line "$($_.Path):$($_.LineNumber) $($_.Line.Trim())"
    }
} else {
  Add-Line "app_router.dart not found"
}

# ------------------------------------------------------------
# 3. RoutePaths audit
# ------------------------------------------------------------
Add-Section "3. ROUTE PATHS AUDIT"

$routePathFiles = Get-ChildItem .\lib -Recurse -Filter "*.dart" |
  Select-String -Pattern "class RoutePaths" -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Path -Unique

if ($routePathFiles) {
  foreach ($routeFile in $routePathFiles) {
    Add-Line "RoutePaths file: $routeFile"
    Select-String -Path $routeFile -Pattern "static const" -ErrorAction SilentlyContinue |
      ForEach-Object {
        Add-Line "$($_.LineNumber) $($_.Line.Trim())"
      }
  }
} else {
  Add-Line "RoutePaths class not found."
}

# ------------------------------------------------------------
# 4. Removed/Consolidated surface leftovers
# ------------------------------------------------------------
Add-Section "4. REMOVED OR CONSOLIDATED FEATURE LEFTOVERS"

Add-Line "Tasks leftovers:"
Write-Matches "TaskScreen|features/tasks|task_screen\.dart|AppView\.tasks|toTasks\("

Add-Line ""
Add-Line "Milestones leftovers:"
Write-Matches "MilestonesScreen|features/milestones|milestones_screen\.dart|AppView\.milestones|toMilestones\("

Add-Line ""
Add-Line "Logs screen/user-facing leftovers:"
Write-Matches "LogsScreen|logs_screen\.dart|Activity Ledger|ACTIVITY LEDGER|AppView\.logs|toLogs\(|RoutePaths\.logs"

Add-Line ""
Add-Line "Soul Map user-facing leftovers:"
Write-Matches "Soul Map|SOUL MAP|toSoulMap\(|AppView\.soulMap"

Add-Line ""
Add-Line "Internal Soul Map compatibility references:"
Write-Matches "soul_map_provider|soul_map_models|SoulMapAlignment|SoulMapDimension|SoulMapFutureSelfComparison" 160

# ------------------------------------------------------------
# 5. Provider audit
# ------------------------------------------------------------
Add-Section "5. PROVIDER AUDIT"

$providerPatterns = @(
  "Provider<",
  "FutureProvider<",
  "StateProvider<",
  "StreamProvider<",
  "NotifierProvider<",
  "AsyncNotifierProvider<",
  "StateNotifierProvider<"
)

foreach ($pattern in $providerPatterns) {
  Add-Line "$pattern count: $(Count-Matches $pattern)"
}

Add-Line ""
Add-Line "Provider hotspots by file:"
Get-ChildItem .\lib -Recurse -Filter "*.dart" |
  ForEach-Object {
    $matches = Select-String -Path $_.FullName -Pattern "Provider<|FutureProvider<|StateProvider<|StreamProvider<|NotifierProvider<|AsyncNotifierProvider<|StateNotifierProvider<" -ErrorAction SilentlyContinue
    if ($matches) {
      [PSCustomObject]@{
        Path = $_.FullName
        Count = $matches.Count
      }
    }
  } |
  Sort-Object Count -Descending |
  Select-Object -First 40 |
  ForEach-Object {
    Add-Line "$($_.Count) providers - $($_.Path)"
  }

Add-Line ""
Add-Line "Provider barrel/export files:"
Write-Matches "export .*provider|providers\.dart|app_state\.dart" 120

# ------------------------------------------------------------
# 6. Domain/usecase/repository audit
# ------------------------------------------------------------
Add-Section "6. DOMAIN, USECASE, AND REPOSITORY AUDIT"

Add-Line "Domain exports:"
if (Test-Path ".\lib\domain\domain.dart") {
  Select-String -Path ".\lib\domain\domain.dart" -Pattern "export " -ErrorAction SilentlyContinue |
    ForEach-Object {
      Add-Line "$($_.LineNumber) $($_.Line.Trim())"
    }
} else {
  Add-Line "lib/domain/domain.dart not found."
}

Add-Line ""
Add-Line "Repository interfaces:"
Write-Matches "abstract class I.*Repository|class .*Repository|RepositoryProvider|repositoryProvider" 200

Add-Line ""
Add-Line "Usecase providers:"
if (Test-Path ".\lib\state\providers\domain_usecase_providers.dart") {
  Select-String -Path ".\lib\state\providers\domain_usecase_providers.dart" -Pattern "Provider<|FutureProvider<|UseCase|useCaseProvider|RepositoryProvider|repositoryProvider" -ErrorAction SilentlyContinue |
    Select-Object -First 240 |
    ForEach-Object {
      Add-Line "$($_.Path):$($_.LineNumber) $($_.Line.Trim())"
    }
} else {
  Add-Line "domain_usecase_providers.dart not found."
}

Add-Line ""
Add-Line "Plan domain references:"
Write-Matches "PlanEntity|plan_entity|PlanRepository|IPlanRepository|planRepositoryProvider|CreatePlan|GetPlan|UpdatePlan"

# ------------------------------------------------------------
# 7. Service layer audit
# ------------------------------------------------------------
Add-Section "7. SERVICE LAYER AUDIT"

Add-Line "Services by size:"
Get-ChildItem .\lib -Recurse -Filter "*.dart" |
  Where-Object { $_.FullName -match "\\services?\\|_service\.dart|service_" } |
  ForEach-Object {
    [PSCustomObject]@{
      Path = $_.FullName
      Lines = Safe-FileLines $_.FullName
    }
  } |
  Sort-Object Lines -Descending |
  Select-Object -First 60 |
  ForEach-Object {
    Add-Line "$($_.Lines) lines - $($_.Path)"
  }

Add-Line ""
Add-Line "Specific service hotspots:"
Write-Matches "class SIEngineService|class DataHygieneScheduler|class SessionRecoveryService|class PaywallService|class SyncService|class Notification" 120

# ------------------------------------------------------------
# 8. UI complexity audit
# ------------------------------------------------------------
Add-Section "8. UI COMPLEXITY AUDIT"

Add-Line "Largest Dart files:"
Get-ChildItem .\lib -Recurse -Filter "*.dart" |
  ForEach-Object {
    [PSCustomObject]@{
      Path = $_.FullName
      Lines = Safe-FileLines $_.FullName
    }
  } |
  Sort-Object Lines -Descending |
  Select-Object -First 50 |
  ForEach-Object {
    Add-Line "$($_.Lines) lines - $($_.Path)"
  }

Add-Line ""
Add-Line "ref.watch hotspots:"
Get-ChildItem .\lib -Recurse -Filter "*.dart" |
  ForEach-Object {
    $matches = Select-String -Path $_.FullName -Pattern "ref\.watch\(" -ErrorAction SilentlyContinue
    if ($matches) {
      [PSCustomObject]@{
        Path = $_.FullName
        Count = $matches.Count
      }
    }
  } |
  Sort-Object Count -Descending |
  Select-Object -First 40 |
  ForEach-Object {
    Add-Line "$($_.Count) ref.watch calls - $($_.Path)"
  }

Add-Line ""
Add-Line "Build method hotspots:"
Get-ChildItem .\lib -Recurse -Filter "*.dart" |
  ForEach-Object {
    $matches = Select-String -Path $_.FullName -Pattern "Widget build\(BuildContext context\)" -ErrorAction SilentlyContinue
    if ($matches) {
      [PSCustomObject]@{
        Path = $_.FullName
        Count = $matches.Count
      }
    }
  } |
  Sort-Object Count -Descending |
  Select-Object -First 40 |
  ForEach-Object {
    Add-Line "$($_.Count) build methods - $($_.Path)"
  }

# ------------------------------------------------------------
# 9. Pubspec and assets audit
# ------------------------------------------------------------
Add-Section "9. PUBSPEC AND ASSET AUDIT"

if (Test-Path ".\pubspec.yaml") {
  Add-Line "pubspec.yaml dependencies/assets snippets:"
  Select-String -Path ".\pubspec.yaml" -Pattern "dependencies:|dev_dependencies:|flutter:|assets:|fonts:|path:|sdk:|version:" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Add-Line "$($_.LineNumber) $($_.Line.Trim())"
    }

  Add-Line ""
  Add-Line "Asset paths declared in pubspec:"
  Select-String -Path ".\pubspec.yaml" -Pattern "^\s*-\s*assets/" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Add-Line "$($_.LineNumber) $($_.Line.Trim())"
    }
} else {
  Add-Line "pubspec.yaml missing."
}

Add-Line ""
Add-Line "Referenced asset constants/usages:"
Write-Matches "AppAssets\.|SvgPicture\.asset|Image\.asset|AssetImage\(" 220

Add-Line ""
Add-Line "Potential missing asset paths from code:"
$assetStrings = Select-String -Path .\lib\**\*.dart -Pattern "assets/" -ErrorAction SilentlyContinue
if ($assetStrings) {
  $assetStrings | Select-Object -First 180 | ForEach-Object {
    Add-Line "$($_.Path):$($_.LineNumber) $($_.Line.Trim())"
  }
} else {
  Add-Line "No direct assets/ strings found."
}

# ------------------------------------------------------------
# 10. Logic and wiring audit
# ------------------------------------------------------------
Add-Section "10. LOGIC AND WIRING AUDIT"

Add-Line "Critical controller/action methods:"
Write-Matches "class .*Controller|class .*Actions|Future<void> .*Task|Future<void> .*Entry|createEntry|updateCreatorEntry|completeTask|delayTask|skipTask|createTask" 260

Add-Line ""
Add-Line "Event bus and lifecycle events:"
Write-Matches "eventBusProvider|TaskLifecycleEvent|emit\(|TimelineEventEntity|timelineActionsProvider" 260

Add-Line ""
Add-Line "Trajectory-related references:"
Write-Matches "trajectory|Trajectory|timeline|Timeline|SI|SiState|siState|domainSiDecisionProvider|generateSiDecision" 260

# ------------------------------------------------------------
# 11. Performance risk hints
# ------------------------------------------------------------
Add-Section "11. PERFORMANCE RISK HINTS"

Add-Line "Potential async/database calls inside build files:"
Write-Matches "\.future|await .*Provider|ref\.watch\(.*future|getTaskById|\.call\(\)" 260

Add-Line ""
Add-Line "Nested scroll hints:"
Write-Matches "SingleChildScrollView|CustomScrollView|ListView|SliverList|NestedScrollView" 220

# ------------------------------------------------------------
# 12. Security/debug hygiene
# ------------------------------------------------------------
Add-Section "12. SECURITY AND DEBUG HYGIENE"

Add-Line "Debug/logging references:"
Write-Matches "debugPrint|print\(|log\(|developer\.log|StackTrace|catch \(_\)|catch \(e" 220

Add-Line ""
Add-Line "Possible sensitive wording in user-facing errors:"
Write-Matches "Exception|StackTrace|error\.toString|unknown error|Model sync failure|Could not|failed|failure" 220

# ------------------------------------------------------------
# 13. Analyzer summary
# ------------------------------------------------------------
Add-Section "13. ANALYZER SUMMARY"

Add-Line "Running: flutter analyze lib"
Write-Host ""
Write-Host "Running flutter analyze lib..." -ForegroundColor Cyan

$analyzeOutput = & flutter analyze lib 2>&1
$analyzeExit = $LASTEXITCODE

foreach ($line in $analyzeOutput) {
  Add-Line $line.ToString()
}

Add-Line ""
Add-Line "Analyzer exit code: $analyzeExit"

if ($analyzeExit -eq 0) {
  Write-Host "Analyzer clean." -ForegroundColor Green
} else {
  Write-Host "Analyzer found issues. See report." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# 14. Pub get / outdated hints
# ------------------------------------------------------------
Add-Section "14. PUBSPEC HEALTH COMMANDS TO RUN MANUALLY"

Add-Line "Recommended manual commands:"
Add-Line "flutter pub get"
Add-Line "flutter pub outdated"
Add-Line "flutter pub deps --style=compact"
Add-Line "flutter build apk --release"

# ------------------------------------------------------------
# Final output
# ------------------------------------------------------------
Write-Host ""
Write-Host "Full audit complete." -ForegroundColor Green
Write-Host "Report file: $reportPath" -ForegroundColor Green

Add-Line ""
Add-Line "FULL AUDIT COMPLETE"
Add-Line "Report file: $reportPath"
