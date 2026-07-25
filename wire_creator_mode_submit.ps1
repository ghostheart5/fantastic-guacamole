$ErrorActionPreference = "Stop"

Write-Host "Wiring Creator mode into real submit flow..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path ".\lib\features\creator\state" | Out-Null

# ------------------------------------------------------------
# Create shared Creator workspace mode provider
# ------------------------------------------------------------
$providerPath = ".\lib\features\creator\state\creator_workspace_provider.dart"

$providerContent = @"
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creatorWorkspaceModeProvider = StateProvider<CreatorWorkspaceMode>(
  (ref) => CreatorWorkspaceMode.tasks,
);
"@

[System.IO.File]::WriteAllText($providerPath, $providerContent, $utf8NoBom)

# ------------------------------------------------------------
# Rebuild Creator unified workbench to use shared provider
# ------------------------------------------------------------
$workbenchPath = ".\lib\features\creator\ui\widgets\creator_unified_workbench.dart"

if (-not (Test-Path $workbenchPath)) {
  throw "Missing workbench file: $workbenchPath"
}

$workbench = Get-Content $workbenchPath -Raw

# Add provider import if missing.
if ($workbench -notmatch "creator_workspace_provider.dart") {
  $workbench = $workbench -replace
    "import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';",
    "import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';`r`nimport 'package:fantastic_guacamole/features/creator/state/creator_workspace_provider.dart';"
}

# Add Riverpod import if missing.
if ($workbench -notmatch "flutter_riverpod") {
  $workbench = $workbench -replace
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';`r`nimport 'package:flutter_riverpod/flutter_riverpod.dart';"
}

# Replace StatefulWidget implementation with ConsumerWidget implementation.
$pattern = "(?s)class CreatorUnifiedWorkbench extends StatefulWidget \{.*?class _CreatorWorkspaceDashboard extends StatelessWidget"
$replacement = @"
class CreatorUnifiedWorkbench extends ConsumerWidget {
  const CreatorUnifiedWorkbench({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatorWorkspaceMode mode = ref.watch(creatorWorkspaceModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CreatorWorkspaceHeader(
          title: 'Unified Creator Workspace',
          subtitle:
              'Tasks, goals, milestones, and planning now operate through one command surface.',
        ),
        const SizedBox(height: 16),
        const _CreatorWorkspaceDashboard(),
        const SizedBox(height: 16),
        CreatorSectionCard(
          label: 'Mode Selector',
          title: 'Choose what to forge',
          description:
              'Switch between task, goal, milestone, and plan creation without leaving Creator.',
          child: CreatorModeSelector(
            selected: mode,
            onSelected: (selectedMode) {
              ref.read(creatorWorkspaceModeProvider.notifier).state =
                  selectedMode;
            },
          ),
        ),
        const SizedBox(height: 16),
        _CreatorModeForge(mode: mode),
        const SizedBox(height: 16),
        const _CreatorConnectedObjects(),
        const SizedBox(height: 16),
        const _CreatorActivityFeed(),
      ],
    );
  }
}

class _CreatorWorkspaceDashboard extends StatelessWidget
"@

$workbench = [System.Text.RegularExpressions.Regex]::Replace($workbench, $pattern, $replacement)

[System.IO.File]::WriteAllText($workbenchPath, $workbench, $utf8NoBom)

# ------------------------------------------------------------
# Update Creator barrel exports
# ------------------------------------------------------------
$barrelPath = ".\lib\features\creator\creator.dart"

if (Test-Path $barrelPath) {
  $barrel = Get-Content $barrelPath -Raw
} else {
  $barrel = ""
}

if ($barrel -notmatch "state/creator_workspace_provider.dart") {
  $barrel = $barrel.TrimEnd() + "`r`nexport 'state/creator_workspace_provider.dart';`r`n"
}

[System.IO.File]::WriteAllText($barrelPath, $barrel, $utf8NoBom)

# ------------------------------------------------------------
# Wire selected mode into CreatorScreen submit
# ------------------------------------------------------------
$screenPath = ".\lib\features\creator\ui\creator_screen.dart"

if (-not (Test-Path $screenPath)) {
  throw "Missing CreatorScreen file: $screenPath"
}

$screen = Get-Content $screenPath -Raw

if ($screen -notmatch "creator_workspace_mode.dart") {
  $screen = $screen -replace
    "import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';",
    "import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';`r`nimport 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';`r`nimport 'package:fantastic_guacamole/features/creator/state/creator_workspace_provider.dart';"
}

# Fix bad old encoded label if it exists.
$screen = $screen.Replace("TASK � GOAL � PLAN FORGE", "TASK - GOAL - PLAN FORGE")
$screen = $screen.Replace("TASK ? GOAL ? PLAN FORGE", "TASK - GOAL - PLAN FORGE")

# Replace submit call with mode-aware payload.
$oldSubmit = "await ref.read(creatorActionsProvider).createTask(data);"
$newSubmit = @"
final CreatorWorkspaceMode mode = ref.read(
                      creatorWorkspaceModeProvider,
                    );
                    final Map<String, dynamic> payload =
                        Map<String, dynamic>.from(data);
                    payload['creatorMode'] = mode.name;
                    payload['creatorSurface'] = 'creator';
                    await ref.read(creatorActionsProvider).createTask(payload);
"@

if ($screen.Contains($oldSubmit)) {
  $screen = $screen.Replace($oldSubmit, $newSubmit)
}

# Replace generic snack text with mode-aware message.
$screen = $screen.Replace(
  "content: Text('Creator updated.')",
  "content: Text('Creator entry saved.')"
)

[System.IO.File]::WriteAllText($screenPath, $screen, $utf8NoBom)

Write-Host "Formatting Creator..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator mode submit wiring complete." -ForegroundColor Green
