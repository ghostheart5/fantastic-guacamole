Write-Host "🧠 ChronoSpark Audit Checklist"
Write-Host "====================================="

$root = "lib"

$emptyFiles = 0
$placeholderHits = 0
$missingCore = 0
$missingSymbols = 0
$violations = 0

if (!(Test-Path $root)) {
  Write-Host "❌ Missing root folder: $root"
  exit 1
}

$dartFiles = Get-ChildItem -Path $root -Recurse -Filter *.dart -File

Write-Host "`n🔍 Empty file check"
$empty = $dartFiles | Where-Object { $_.Length -eq 0 }
foreach ($file in $empty) {
  Write-Host "❌ Empty file: $($file.FullName)"
  $emptyFiles++
}
if ($emptyFiles -eq 0) {
  Write-Host "✅ No empty Dart files"
}

Write-Host "`n🧩 TODO/placeholder scan"
$markers = $dartFiles | Select-String -Pattern "\bTODO\b|\bplaceholder\b|\bnot implemented\b" -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($markers) {
  foreach ($marker in $markers) {
    Write-Host "⚠️ $($marker.Path):$($marker.LineNumber) -> $($marker.Line.Trim())"
    $placeholderHits++
  }
} else {
  Write-Host "✅ No TODO/placeholder markers found"
}

Write-Host "`n⚙️ Core file checks"
$coreChecks = @(
  @{ Name = "SI Core"; Paths = @("lib/engine/si/si_core.dart") },
  @{ Name = "SI Engine"; Paths = @("lib/engine/si/si_engine.dart") },
  @{ Name = "SI AI Service"; Paths = @("lib/engine/si/si_ai_service.dart") },
  @{ Name = "SI Response Engine"; Paths = @("lib/engine/si/si_response_engine.dart") },
  @{ Name = "Adaptive Learning"; Paths = @("lib/engine/learning/adaptive_learning.dart") },
  @{ Name = "AI Controller"; Paths = @("lib/state/controllers/ai_controller.dart") },
  @{ Name = "Learning Controller"; Paths = @("lib/state/controllers/learning_controller.dart") },
  @{ Name = "Insight Controller"; Paths = @("lib/state/controllers/insight_controller.dart") },
  @{ Name = "Smart Coach Screen"; Paths = @("lib/features/home/ui/smart_coach_screen.dart") },
  @{ Name = "Insight Screen"; Paths = @("lib/features/insights/ui/insight_screen.dart", "lib/features/insights/insight_screen.dart") },
  @{ Name = "SI Console Screen"; Paths = @("lib/features/si_console/ui/si_console_screen.dart") }
)

foreach ($check in $coreChecks) {
  $existing = $check.Paths | Where-Object { Test-Path $_ }
  if ($existing.Count -gt 0) {
    Write-Host "✅ Found ($($check.Name)): $($existing[0])"
  } else {
    Write-Host "❌ Missing core file ($($check.Name)): $($check.Paths -join ' OR ')"
    $missingCore++
  }
}

Write-Host "`n🔌 Core symbol checks"
$symbolChecks = @(
  "aiResponseProvider",
  "SIAIService",
  "SIEngine"
)

foreach ($symbol in $symbolChecks) {
  $match = $dartFiles | Select-String -Pattern "\b$symbol\b" -ErrorAction SilentlyContinue
  if ($match) {
    Write-Host "✅ Connected: $symbol"
  } else {
    Write-Host "❌ Missing symbol: $symbol"
    $missingSymbols++
  }
}

Write-Host "`n🏗️ Architecture boundary scan"
foreach ($file in $dartFiles) {
  $relative = [IO.Path]::GetRelativePath((Resolve-Path .).Path, $file.FullName).Replace('\', '/')
  $text = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
  if ([string]::IsNullOrWhiteSpace($text)) {
    continue
  }

  if ($relative -like "lib/features/*" -and $text -match "import\s+'package:[^']+/engine/") {
    Write-Host "🔥 Possible UI -> ENGINE import: $relative"
    $violations++
  }
  if ($relative -like "lib/engine/*" -and $text -match "import\s+'package:[^']+/state/") {
    Write-Host "🔥 Possible ENGINE -> STATE import: $relative"
    $violations++
  }
}

if ($violations -eq 0) {
  Write-Host "✅ No boundary violations detected by heuristic scan"
}

Write-Host "`n📊 Logging presence"
$logs = $dartFiles | Select-String -Pattern "Logger\.log" -ErrorAction SilentlyContinue
if ($logs) {
  Write-Host "✅ Logger.log usage found ($($logs.Count) hits)"
} else {
  Write-Host "⚠️ Logger.log usage not found"
}

Write-Host "`n🧪 Flutter analyze"
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutter) {
  flutter analyze
} else {
  Write-Host "⚠️ flutter not available in PATH; skipped analyze"
}

Write-Host "`n====================================="
Write-Host "📌 AUDIT SUMMARY"
Write-Host "Empty files: $emptyFiles"
Write-Host "TODO/placeholder hits: $placeholderHits"
Write-Host "Missing core files: $missingCore"
Write-Host "Missing symbols: $missingSymbols"
Write-Host "Boundary violations: $violations"
Write-Host "====================================="

if (($emptyFiles + $missingCore + $missingSymbols + $violations) -gt 0) {
  exit 1
}

Write-Host "✅ AUDIT COMPLETE"
