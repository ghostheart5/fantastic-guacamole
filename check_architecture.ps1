$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$libRoot = Join-Path $root 'lib'

if (-not (Test-Path $libRoot)) {
  Write-Error "lib directory not found at: $libRoot"
}

$violations = New-Object System.Collections.Generic.List[string]

function Get-Imports {
  param(
    [string]$FilePath
  )

  $lines = @(Get-Content -Path $FilePath)
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match "^import\s+'package:fantastic_guacamole/([^']+)';") {
      [PSCustomObject]@{
        ImportPath = $matches[1]
        LineNumber = $i + 1
      }
    }
  }
}

function Add-Violation {
  param(
    [string]$FilePath,
    [int]$LineNumber,
    [string]$Message,
    [string]$ImportPath
  )

  $relativeFile = $FilePath.Replace($root + '\\', '')
  $violations.Add("${relativeFile}:$LineNumber -> $Message (import: $ImportPath)") | Out-Null
}

$dartFiles = Get-ChildItem -Path $libRoot -Filter '*.dart' -Recurse -File

foreach ($file in $dartFiles) {
  $fullPath = $file.FullName
  $relativePath = $fullPath.Replace($root + '\\', '').Replace('\\', '/')
  $imports = Get-Imports -FilePath $fullPath

  foreach ($imp in $imports) {
    $importPath = $imp.ImportPath

    # Rule 1: data/services cannot depend on orchestration/platform/feature layers.
    if ($relativePath.StartsWith('lib/data/services/')) {
      if (
        $importPath.StartsWith('state/services/') -or
        $importPath.StartsWith('system/') -or
        $importPath.StartsWith('features/') -or
        $importPath.StartsWith('engine/planning/')
      ) {
        Add-Violation -FilePath $fullPath -LineNumber $imp.LineNumber -Message 'data/services must stay infra-only' -ImportPath $importPath
      }
    }

    # Rule 2: state/services is orchestration and must not depend on platform or feature layers.
    if ($relativePath.StartsWith('lib/state/services/')) {
      if (
        $importPath.StartsWith('system/') -or
        $importPath.StartsWith('features/') -or
        $importPath.StartsWith('engine/planning/')
      ) {
        Add-Violation -FilePath $fullPath -LineNumber $imp.LineNumber -Message 'state/services must not depend on system/features/engine' -ImportPath $importPath
      }
    }

    # Rule 3: system/* should be platform wrappers, not app orchestration.
    if ($relativePath.StartsWith('lib/system/')) {
      if (
        $importPath.StartsWith('state/') -or
        $importPath.StartsWith('features/') -or
        $importPath.StartsWith('engine/') -or
        $importPath.StartsWith('app/')
      ) {
        Add-Violation -FilePath $fullPath -LineNumber $imp.LineNumber -Message 'system/* must stay platform/plugin-oriented' -ImportPath $importPath
      }
    }

    # Rule 4: engine/planning should stay domain-centric and isolated.
    if ($relativePath.StartsWith('lib/engine/planning/')) {
      if (
        $importPath.StartsWith('data/') -or
        $importPath.StartsWith('state/') -or
        $importPath.StartsWith('features/') -or
        $importPath.StartsWith('system/') -or
        $importPath.StartsWith('app/')
      ) {
        Add-Violation -FilePath $fullPath -LineNumber $imp.LineNumber -Message 'engine/planning must not depend on app/data/state/system' -ImportPath $importPath
      }
    }
  }
}

# Rule 5: feature services should be rare and local-only.
$featureServiceFiles = Get-ChildItem -Path (Join-Path $libRoot 'features') -Filter '*.dart' -Recurse -File |
  Where-Object { $_.FullName.Replace('\\', '/') -match '/services/' }

foreach ($file in $featureServiceFiles) {
  $relativePath = $file.FullName.Replace($root + '\\', '').Replace('\\', '/')
  $imports = Get-Imports -FilePath $file.FullName
  foreach ($imp in $imports) {
    if (-not $imp.ImportPath.StartsWith('features/')) {
      Add-Violation -FilePath $file.FullName -LineNumber $imp.LineNumber -Message 'features/*/services should be feature-local only' -ImportPath $imp.ImportPath
    }
  }
}

# Rule 6: each domain repository interface must have a concrete data repository
# implementation or an explicit non-data owner.
$explicitOwners = @{
  'IInsightRepository' = 'lib/state/services/insights_service.dart'
  'ILearningRepository' = 'lib/state/services/intelligence_service.dart'
  'IProgressionRepository' = 'lib/state/services/progression_service.dart'
  'IThemeRepository' = 'lib/state/services/theme_service.dart'
}

$implementedInterfaces = New-Object 'System.Collections.Generic.HashSet[string]'
$implScanFiles = Get-ChildItem -Path $libRoot -Filter '*.dart' -Recurse -File |
  Where-Object { -not $_.FullName.Replace('\\', '/').Contains('/domain/interfaces/') }

foreach ($file in $implScanFiles) {
  $lines = @(Get-Content -Path $file.FullName)
  foreach ($line in $lines) {
    if ($line -match 'implements\s+([^\{]+)') {
      $implementsClause = $matches[1]
      $tokens = $implementsClause -split '[,\s]+'
      foreach ($token in $tokens) {
        if ($token -match '^I[A-Za-z0-9]+Repository$') {
          [void]$implementedInterfaces.Add($token)
        }
      }
    }
  }
}

$interfaceFiles = Get-ChildItem -Path (Join-Path $libRoot 'domain/interfaces') -Filter 'i_*_repository.dart' -File
foreach ($interfaceFile in $interfaceFiles) {
  $relativeInterfacePath = $interfaceFile.FullName.Replace($root + '\\', '').Replace('\\', '/')
  $content = Get-Content -Path $interfaceFile.FullName -Raw
  if ($content -match 'abstract class\s+(I[A-Za-z0-9]+Repository)') {
    $interfaceName = $matches[1]
    $hasImplementation = $implementedInterfaces.Contains($interfaceName)
    $hasExplicitOwner = $explicitOwners.ContainsKey($interfaceName)

    if (-not $hasImplementation -and -not $hasExplicitOwner) {
      $violations.Add("${relativeInterfacePath}:1 -> missing ownership for $interfaceName (add data repository implementation or explicit owner mapping)") | Out-Null
      continue
    }

    if ($hasExplicitOwner) {
      $ownerPath = $explicitOwners[$interfaceName]
      $ownerAbsolutePath = Join-Path $root $ownerPath
      if (-not (Test-Path $ownerAbsolutePath)) {
        $violations.Add("${relativeInterfacePath}:1 -> explicit owner path missing for $interfaceName ($ownerPath)") | Out-Null
      }
    }
  }
}

# Rule 7: prevent duplicate domain model pairs (x.dart + x_entity.dart).
$domainEntitiesPath = Join-Path $libRoot 'domain/entities'
if (Test-Path $domainEntitiesPath) {
  $legacyDuplicateAllowlist = @('task', 'calendar_entry')

  $domainEntityFiles = Get-ChildItem -Path $domainEntitiesPath -Filter '*.dart' -File
  $entityFilesByBase = @{}

  foreach ($file in $domainEntityFiles) {
    $name = $file.Name
    if ($name -match '^(.+?)(_entity)?\.dart$') {
      $base = $matches[1]
      if (-not $entityFilesByBase.ContainsKey($base)) {
        $entityFilesByBase[$base] = New-Object System.Collections.Generic.List[string]
      }
      $entityFilesByBase[$base].Add($name) | Out-Null
    }
  }

  foreach ($entry in $entityFilesByBase.GetEnumerator()) {
    $base = $entry.Key
    $names = $entry.Value
    $hasBase = $names -contains "$base.dart"
    $hasEntity = $names -contains "${base}_entity.dart"

    if ($hasBase -and $hasEntity -and -not ($legacyDuplicateAllowlist -contains $base)) {
      $violations.Add("lib/domain/entities/${base}.dart:1 -> duplicate domain model pair detected (${base}.dart + ${base}_entity.dart)") | Out-Null
    }
  }
}

# Rule 8: centralize application state providers under lib/state/providers.
$featureFiles = Get-ChildItem -Path (Join-Path $libRoot 'features') -Filter '*.dart' -Recurse -File
foreach ($file in $featureFiles) {
  $relativeFeaturePath = $file.FullName.Replace($root + '\\', '').Replace('\\', '/')
  $lines = @(Get-Content -Path $file.FullName)

  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match 'final\s+\w+Provider\s*=\s*\w*Provider<') {
      $violations.Add("${relativeFeaturePath}:$($i + 1) -> feature-local provider declaration found; move provider to lib/state/providers") | Out-Null
    }
  }
}

# Rule 9: barrel files must not export across architecture layers.
$barrelRules = @{
  'lib/domain/domain.dart' = @('domain/')
  'lib/state/providers/providers.dart' = @('state/')
  'lib/state/controllers/controllers.dart' = @('state/')
  'lib/ui/widgets/widgets.dart' = @('ui/')
  'lib/theme/theme.dart' = @('theme/')
}

foreach ($barrelRelativePath in $barrelRules.Keys) {
  $barrelPath = Join-Path $root $barrelRelativePath
  if (-not (Test-Path $barrelPath)) {
    continue
  }

  $allowedPrefixes = $barrelRules[$barrelRelativePath]
  $lines = @(Get-Content -Path $barrelPath)
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match "^export\s+'package:fantastic_guacamole/([^']+)';") {
      $exportPath = $matches[1]
      $isAllowed = $false
      foreach ($prefix in $allowedPrefixes) {
        if ($exportPath.StartsWith($prefix)) {
          $isAllowed = $true
          break
        }
      }

      if (-not $isAllowed) {
        $violations.Add("${barrelRelativePath}:$($i + 1) -> cross-layer barrel export is not allowed (export: $exportPath)") | Out-Null
      }
    }
  }
}

# Rule 10: import hygiene constraints.
$importScanRoots = @(
  (Join-Path $root 'lib'),
  (Join-Path $root 'test'),
  (Join-Path $root 'integration_test'),
  (Join-Path $root 'tool')
)

$allDartFiles = @()
foreach ($scanRoot in $importScanRoots) {
  if (Test-Path $scanRoot) {
    $allDartFiles += Get-ChildItem -Path $scanRoot -Filter '*.dart' -Recurse -File
  }
}
foreach ($file in $allDartFiles) {
  $relativePath = $file.FullName.Replace($root + '\\', '').Replace('\\', '/')
  $lines = @(Get-Content -Path $file.FullName)

  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()

    if ($line -match "^import\s+'package:[^']+/src/[^']+';") {
      $violations.Add("${relativePath}:$($i + 1) -> importing package private src/ is not allowed") | Out-Null
    }

    $isTestFile = $relativePath.StartsWith('test/') -or $relativePath.StartsWith('integration_test/')
    if ($isTestFile -and $line -match "^import\s+'\.\./lib/[^']+';") {
      $violations.Add("${relativePath}:$($i + 1) -> tests must import app code via package:fantastic_guacamole/... not ../lib/") | Out-Null
    }
  }
}

# Rule 11: feature UI/widgets dependency direction.
$featureUiRoots = @(
  (Join-Path $libRoot 'features')
)

foreach ($featureRoot in $featureUiRoots) {
  if (-not (Test-Path $featureRoot)) {
    continue
  }

  $uiFiles = Get-ChildItem -Path $featureRoot -Filter '*.dart' -Recurse -File |
    Where-Object {
      $normalized = $_.FullName.Replace('\', '/')
      $normalized.Contains('/ui/') -or $normalized.Contains('/widgets/')
    }

  foreach ($file in $uiFiles) {
    $relativePath = $file.FullName.Replace($root + '\', '').Replace('\', '/')
    $imports = Get-Imports -FilePath $file.FullName
    foreach ($imp in $imports) {
      $importPath = $imp.ImportPath

      if (
        $importPath.StartsWith('data/') -or
        $importPath.StartsWith('system/') -or
        $importPath.StartsWith('engine/') -or
        $importPath.StartsWith('app/')
      ) {
        $violations.Add("${relativePath}:$($imp.LineNumber) -> feature ui/widgets must depend on state/domain/ui/features only (import: $importPath)") | Out-Null
      }
    }
  }
}

# Rule 12: SI chat clean path critical links.
$siConsolePath = Join-Path $root 'lib/features/si_console/ui/si_console_screen.dart'
if (Test-Path $siConsolePath) {
  $siConsoleRaw = Get-Content -Path $siConsolePath -Raw
  if ($siConsoleRaw -notmatch 'aiControllerProvider\)\s*\.sendMessage\(') {
    $violations.Add('lib/features/si_console/ui/si_console_screen.dart:1 -> SI Console must route chat through aiControllerProvider.sendMessage(text)') | Out-Null
  }
  if ($siConsoleRaw -notmatch 'siConsoleQueryControllerProvider\)\s*\.detectsCrisis\(') {
    $violations.Add('lib/features/si_console/ui/si_console_screen.dart:1 -> SI Console must delegate crisis gating through siConsoleQueryControllerProvider.detectsCrisis(text)') | Out-Null
  }
  if ($siConsoleRaw -match 'aiResponseProvider\.notifier\)\s*\.executeConsoleQuery\(') {
    $violations.Add('lib/features/si_console/ui/si_console_screen.dart:1 -> SI Console must not call aiResponseProvider.executeConsoleQuery directly; route through aiControllerProvider.sendMessage(text)') | Out-Null
  }
}

$smartCoachPath = Join-Path $root 'lib/features/home/ui/smart_coach_screen.dart'
if (Test-Path $smartCoachPath) {
  $smartCoachRaw = Get-Content -Path $smartCoachPath -Raw
  if ($smartCoachRaw -notmatch 'coachQueryControllerProvider') {
    $violations.Add('lib/features/home/ui/smart_coach_screen.dart:1 -> Smart Coach must resolve coachQueryControllerProvider for orchestration') | Out-Null
  }
  if ($smartCoachRaw -notmatch '\.detectsCrisis\(') {
    $violations.Add('lib/features/home/ui/smart_coach_screen.dart:1 -> Smart Coach must delegate crisis gating through coachQueryControllerProvider.detectsCrisis(text)') | Out-Null
  }
  if ($smartCoachRaw -notmatch '\.requestCoaching\(') {
    $violations.Add('lib/features/home/ui/smart_coach_screen.dart:1 -> Smart Coach must request coaching through coachQueryControllerProvider.requestCoaching(...)') | Out-Null
  }
  if ($smartCoachRaw -notmatch '\.requestFollowUp\(') {
    $violations.Add('lib/features/home/ui/smart_coach_screen.dart:1 -> Smart Coach follow-ups must route through coachQueryControllerProvider.requestFollowUp(...)') | Out-Null
  }
  if ($smartCoachRaw -match 'CrisisDetectionPolicy\.detects\(') {
    $violations.Add('lib/features/home/ui/smart_coach_screen.dart:1 -> Smart Coach must not call CrisisDetectionPolicy directly; use coachQueryControllerProvider.detectsCrisis(text)') | Out-Null
  }
  if ($smartCoachRaw -match 'aiResponseProvider\.notifier\)\s*\.executeCoachQuery\(') {
    $violations.Add('lib/features/home/ui/smart_coach_screen.dart:1 -> Smart Coach must not call aiResponseProvider.executeCoachQuery directly; route through coachQueryControllerProvider') | Out-Null
  }
}

$aiControllerPath = Join-Path $root 'lib/state/controllers/ai_controller.dart'
if (Test-Path $aiControllerPath) {
  $aiControllerRaw = Get-Content -Path $aiControllerPath -Raw

  if ($aiControllerRaw -notmatch "import\s+'package:fantastic_guacamole/state/controllers/si_state_controller\.dart';") {
    $violations.Add('lib/state/controllers/ai_controller.dart:1 -> AI controller must depend on SI state controller/provider layer') | Out-Null
  }
  if ($aiControllerRaw -notmatch "import\s+'package:fantastic_guacamole/state/providers/intelligence_provider\.dart';") {
    $violations.Add('lib/state/controllers/ai_controller.dart:1 -> AI controller must read intelligence provider for runtime context') | Out-Null
  }
  if ($aiControllerRaw -notmatch "import\s+'package:fantastic_guacamole/state/providers/si_memory_provider\.dart';") {
    $violations.Add('lib/state/controllers/ai_controller.dart:1 -> AI controller must capture SI memory snapshots via si_memory_provider') | Out-Null
  }
  if ($aiControllerRaw -notmatch "import\s+'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator\.dart';") {
    $violations.Add('lib/state/controllers/ai_controller.dart:1 -> AI controller must route chat via agent_orchestrator') | Out-Null
  }
  if ($aiControllerRaw -notmatch 'siMemoryProvider\.notifier\)\s*\.capture\(') {
    $violations.Add('lib/state/controllers/ai_controller.dart:1 -> AI controller must persist SI snapshots through siMemoryProvider') | Out-Null
  }
}

# Rule 13: unified chatbot layer contract presence.
$requiredUnifiedPaths = @(
  'lib/features/si_console/ui/si_console_screen.dart',
  'lib/state/controllers/ai_controller.dart',
  'lib/state/controllers/si_state_controller.dart',
  'lib/state/providers/intelligence_provider.dart',
  'lib/state/providers/si_memory_provider.dart',
  'lib/data/services/ai/orchestration/agent_orchestrator.dart',
  'lib/data/repositories/si_engine_repository.dart',
  'lib/engine/si/si_engine_service.dart',
  'lib/engine/si/si_engine.dart',
  'lib/engine/si/synthetic_intelligence_engine.dart'
)

foreach ($relativePath in $requiredUnifiedPaths) {
  $absolutePath = Join-Path $root $relativePath
  if (-not (Test-Path $absolutePath)) {
    $violations.Add("${relativePath}:1 -> required unified chatbot layer path is missing") | Out-Null
  }
}

$requiredUnifiedDirs = @(
  'lib/data/services/ai/agents',
  'lib/data/services/ai/tools'
)

foreach ($relativeDir in $requiredUnifiedDirs) {
  $absoluteDir = Join-Path $root $relativeDir
  if (-not (Test-Path $absoluteDir)) {
    $violations.Add("${relativeDir}:1 -> required unified chatbot layer directory is missing") | Out-Null
    continue
  }

  $dartCount = @(Get-ChildItem -Path $absoluteDir -Filter '*.dart' -Recurse -File).Count
  if ($dartCount -eq 0) {
    $violations.Add("${relativeDir}:1 -> unified chatbot layer directory must contain Dart files") | Out-Null
  }
}

# Rule 14: SI engine public-vs-internal import boundaries.
$siPublicFacades = @(
  'engine/si/si_engine_service.dart',
  'engine/si/si_engine.dart',
  'engine/si/synthetic_intelligence_engine.dart',
  'engine/si/ai_response.dart',
  'engine/si/si_decision.dart',
  'engine/si/si_output_bundle.dart',
  'engine/si/models/si_state.dart'
)

$siInternalModules = @(
  'engine/si/si_input_fusion.dart',
  'engine/si/si_intent_engine.dart',
  'engine/si/si_reasoning.dart',
  'engine/si/si_meta_reasoning.dart',
  'engine/si/prediction_engine.dart',
  'engine/si/si_memory.dart',
  'engine/si/si_snapshot.dart',
  'engine/si/si_tiered_memory.dart',
  'engine/si/si_user_state_tracker.dart',
  'engine/si/si_adaptive_learning.dart',
  'engine/si/si_cognitive_coherence_validator.dart',
  'engine/si/si_self_consistency_engine.dart',
  'engine/si/si_policy.dart',
  'engine/si/si_ethics_layer.dart'
)

$nonEngineFiles = Get-ChildItem -Path $libRoot -Filter '*.dart' -Recurse -File |
  Where-Object { -not $_.FullName.Replace('\', '/').Contains('/lib/engine/') }

foreach ($file in $nonEngineFiles) {
  $relativePath = $file.FullName.Replace($root + '\', '').Replace('\', '/')
  $imports = Get-Imports -FilePath $file.FullName

  foreach ($imp in $imports) {
    $importPath = $imp.ImportPath
    if ($siInternalModules -contains $importPath) {
      $violations.Add("${relativePath}:$($imp.LineNumber) -> internal SI engine module import is not allowed outside lib/engine (import: $importPath)") | Out-Null
    }
  }
}

$siRepoPath = Join-Path $root 'lib/data/repositories/si_engine_repository.dart'
if (Test-Path $siRepoPath) {
  $repoImports = Get-Imports -FilePath $siRepoPath
  foreach ($imp in $repoImports) {
    if ($imp.ImportPath.StartsWith('engine/si/') -and -not ($siPublicFacades -contains $imp.ImportPath)) {
      $violations.Add("lib/data/repositories/si_engine_repository.dart:$($imp.LineNumber) -> only public SI facade files may be imported here (import: $($imp.ImportPath))") | Out-Null
    }
  }
}

# Rule 15: cohesive SI assistant layer contract.
$assistantUiLayerPaths = @(
  'lib/features/home/ui/smart_coach_screen.dart',
  'lib/features/home/widgets/ai_decision_card.dart',
  'lib/features/si_console/ui/si_console_screen.dart',
  'lib/features/plan/ui/plan_screen.dart',
  'lib/features/tasks/ui/task_screen.dart'
)

$assistantStateLayerPaths = @(
  'lib/state/controllers/ai_controller.dart',
  'lib/state/controllers/si_state_controller.dart',
  'lib/state/controllers/prediction_controller.dart',
  'lib/state/controllers/voice_controller.dart',
  'lib/state/providers/intelligence_provider.dart',
  'lib/state/providers/si_memory_provider.dart',
  'lib/state/providers/trajectory_provider.dart',
  'lib/state/providers/task_provider.dart',
  'lib/state/providers/calendar_provider.dart'
)

$assistantIntelligenceLayerPaths = @(
  'lib/data/services/ai/orchestration/agent_orchestrator.dart',
  'lib/data/repositories/si_engine_repository.dart',
  'lib/engine/si/si_engine_service.dart'
)

foreach ($relativePath in ($assistantUiLayerPaths + $assistantStateLayerPaths + $assistantIntelligenceLayerPaths)) {
  $absolutePath = Join-Path $root $relativePath
  if (-not (Test-Path $absolutePath)) {
    $violations.Add("${relativePath}:1 -> required SI assistant layer contract file is missing") | Out-Null
  }
}

$assistantIntelligenceDirs = @(
  'lib/data/services/ai/agents',
  'lib/data/services/ai/tools'
)

foreach ($relativeDir in $assistantIntelligenceDirs) {
  $absoluteDir = Join-Path $root $relativeDir
  if (-not (Test-Path $absoluteDir)) {
    $violations.Add("${relativeDir}:1 -> required SI assistant intelligence directory is missing") | Out-Null
    continue
  }

  $dartCount = @(Get-ChildItem -Path $absoluteDir -Filter '*.dart' -Recurse -File).Count
  if ($dartCount -eq 0) {
    $violations.Add("${relativeDir}:1 -> SI assistant intelligence directory must contain Dart files") | Out-Null
  }
}

foreach ($relativePath in $assistantStateLayerPaths) {
  $absolutePath = Join-Path $root $relativePath
  if (-not (Test-Path $absolutePath)) {
    continue
  }

  $imports = Get-Imports -FilePath $absolutePath
  foreach ($imp in $imports) {
    if (
      $imp.ImportPath.StartsWith('data/services/ai/agents/') -or
      $imp.ImportPath.StartsWith('data/services/ai/tools/')
    ) {
      $violations.Add("${relativePath}:$($imp.LineNumber) -> state assistant layer must not import agent/tool internals directly (import: $($imp.ImportPath))") | Out-Null
    }
  }
}

# Rule 16: engine/si must remain pure Dart (no Flutter framework imports).
$siEngineFiles = Get-ChildItem -Path (Join-Path $libRoot 'engine/si') -Filter '*.dart' -Recurse -File
foreach ($file in $siEngineFiles) {
  $relativePath = $file.FullName.Replace($root + '\\', '').Replace('\\', '/')
  $lines = @(Get-Content -Path $file.FullName)
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match "^import\s+'package:flutter/" -or $line -match "^import\s+'package:flutter_riverpod/") {
      $violations.Add("${relativePath}:$($i + 1) -> engine/si files must be pure Dart and must not import Flutter or Riverpod") | Out-Null
    }
  }
}

# Rule 17: practical build-order contracts and bridge restrictions.
if (Test-Path $aiControllerPath) {
  $aiControllerRaw = Get-Content -Path $aiControllerPath -Raw
  $requiredControllerMethods = @(
    'sendMessage\(',
    'retryMessage\(',
    'clearConversation\(',
    'acceptSuggestion\(',
    'rejectSuggestion\('
  )

  foreach ($methodPattern in $requiredControllerMethods) {
    if ($aiControllerRaw -notmatch $methodPattern) {
      $violations.Add("lib/state/controllers/ai_controller.dart:1 -> missing required controller method matching pattern: $methodPattern") | Out-Null
    }
  }
}

$engineServicePath = Join-Path $root 'lib/engine/si/si_engine_service.dart'
if (Test-Path $engineServicePath) {
  $engineServiceRaw = Get-Content -Path $engineServicePath -Raw
  $requiredFacadeMethods = @(
    'generateResponse\(',
    'generateDecision\(',
    'updateMemory\(',
    'validateOutput\('
  )

  foreach ($methodPattern in $requiredFacadeMethods) {
    if ($engineServiceRaw -notmatch $methodPattern) {
      $violations.Add("lib/engine/si/si_engine_service.dart:1 -> missing required SI facade method matching pattern: $methodPattern") | Out-Null
    }
  }
}

if (Test-Path $siConsolePath) {
  $siConsoleRaw = Get-Content -Path $siConsolePath -Raw
  if ($siConsoleRaw -match "import\s+'package:fantastic_guacamole/engine/si/") {
    $violations.Add('lib/features/si_console/ui/si_console_screen.dart:1 -> features/si_console must not import engine/si directly; route through AI controller/intelligence/orchestrator/repository/service bridge') | Out-Null
  }
}

# Rule 18: persisted feature providers must go through domain usecases, not SharedPrefs directly.
$persistedProviderPaths = @(
  'lib/state/providers/goals_provider.dart',
  'lib/state/providers/memories_provider.dart',
  'lib/state/providers/timeline_provider.dart'
)

foreach ($relativePath in $persistedProviderPaths) {
  $absolutePath = Join-Path $root $relativePath
  if (-not (Test-Path $absolutePath)) {
    continue
  }

  $raw = Get-Content -Path $absolutePath -Raw
  if ($raw -match "import\s+'package:fantastic_guacamole/data/storage/shared_prefs_service\.dart';") {
    $violations.Add("${relativePath}:1 -> persisted feature providers must not import SharedPrefsService directly; use domain usecase providers") | Out-Null
  }
  if ($raw -notmatch "import\s+'package:fantastic_guacamole/state/providers/domain_usecase_providers\.dart';") {
    $violations.Add("${relativePath}:1 -> persisted feature providers must import domain_usecase_providers.dart to reach domain usecases") | Out-Null
  }
}

# Rule 19: lightweight full-vs-placeholder domain file heuristics.
$domainEntityFiles = Get-ChildItem -Path (Join-Path $libRoot 'domain/entities') -Filter '*.dart' -File
foreach ($file in $domainEntityFiles) {
  $relativePath = $file.FullName.Replace($root + '\', '').Replace('\', '/')
  $raw = Get-Content -Path $file.FullName -Raw

  if ($raw -match "^import\s+'package:(flutter|firebase_|hive|supabase_flutter)" ) {
    $violations.Add("${relativePath}:1 -> domain entities must not import Flutter/Firebase/Hive/Supabase dependencies") | Out-Null
  }
}

$domainInterfaceFiles = Get-ChildItem -Path (Join-Path $libRoot 'domain/interfaces') -Filter '*.dart' -File
foreach ($file in $domainInterfaceFiles) {
  $relativePath = $file.FullName.Replace($root + '\', '').Replace('\', '/')
  $raw = Get-Content -Path $file.FullName -Raw

  if ($raw -match "import\s+'package:fantastic_guacamole/(data/|system/)") {
    $violations.Add("${relativePath}:1 -> domain interfaces must not depend on data or system implementation layers") | Out-Null
  }
  if ($raw -notmatch 'abstract class\s+I[A-Za-z0-9]+Repository') {
    $violations.Add("${relativePath}:1 -> repository interface file looks incomplete; expected abstract class I*Repository") | Out-Null
  }
}

$domainUsecaseFiles = Get-ChildItem -Path (Join-Path $libRoot 'domain/usecases') -Filter '*.dart' -File
foreach ($file in $domainUsecaseFiles) {
  $relativePath = $file.FullName.Replace($root + '\', '').Replace('\', '/')
  $raw = Get-Content -Path $file.FullName -Raw

  if ($raw -match "import\s+'package:fantastic_guacamole/data/repositories/") {
    $violations.Add("${relativePath}:1 -> domain usecases must depend on interfaces, not concrete data repositories") | Out-Null
  }
  if ($raw -match "import\s+'package:(flutter|flutter_riverpod)/") {
    $violations.Add("${relativePath}:1 -> domain usecases must not import Flutter or Riverpod") | Out-Null
  }
}

# Rule 20: theme and identity resolved chains must stay provider/usecase-backed.
$themeProviderPath = Join-Path $root 'lib/state/providers/theme_provider.dart'
if (Test-Path $themeProviderPath) {
  $themeProviderRaw = Get-Content -Path $themeProviderPath -Raw
  if ($themeProviderRaw -notmatch 'getCurrentThemeUseCaseProvider' -or $themeProviderRaw -notmatch 'saveThemeUseCaseProvider') {
    $violations.Add('lib/state/providers/theme_provider.dart:1 -> theme provider must route through theme domain usecases') | Out-Null
  }
}

$identityProviderPath = Join-Path $root 'lib/state/providers/identity_provider.dart'
if (Test-Path $identityProviderPath) {
  $identityProviderRaw = Get-Content -Path $identityProviderPath -Raw
  if ($identityProviderRaw -match 'SharedPrefsService') {
    $violations.Add('lib/state/providers/identity_provider.dart:1 -> identity provider must not persist through SharedPrefsService directly; use identity domain usecases') | Out-Null
  }
  if ($identityProviderRaw -notmatch 'getIdentityProfileUseCaseProvider' -or $identityProviderRaw -notmatch 'saveIdentityProfileUseCaseProvider') {
    $violations.Add('lib/state/providers/identity_provider.dart:1 -> identity provider must route persistence through identity domain usecases') | Out-Null
  }
}

$appRootPath = Join-Path $root 'lib/app/app_root.dart'
if (Test-Path $appRootPath) {
  $appRootRaw = Get-Content -Path $appRootPath -Raw
  if ($appRootRaw -notmatch 'currentThemeProvider') {
    $violations.Add('lib/app/app_root.dart:1 -> app root must consume currentThemeProvider so theme persistence is part of the live app chain') | Out-Null
  }
}

if ($violations.Count -gt 0) {
  Write-Host ''
  Write-Host 'ARCHITECTURE CHECK FAILED' -ForegroundColor Red
  Write-Host 'Layer boundary violations found:' -ForegroundColor Red
  foreach ($v in $violations) {
    Write-Host " - $v" -ForegroundColor Red
  }
  exit 1
}

Write-Host ''
Write-Host 'ARCHITECTURE CHECK PASSED' -ForegroundColor Green
Write-Host 'No service-layer boundary violations detected.' -ForegroundColor Green
exit 0
