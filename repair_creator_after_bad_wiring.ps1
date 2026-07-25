$ErrorActionPreference = "Stop"

Write-Host "Repairing Creator after bad mode wiring..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$screenPath = ".\lib\features\creator\ui\creator_screen.dart"
$workbenchPath = ".\lib\features\creator\ui\widgets\creator_unified_workbench.dart"
$providerPath = ".\lib\features\creator\state\creator_workspace_provider.dart"
$barrelPath = ".\lib\features\creator\creator.dart"

if (Test-Path $screenPath) {
  Copy-Item $screenPath "$screenPath.bak" -Force
}

if (Test-Path $workbenchPath) {
  Copy-Item $workbenchPath "$workbenchPath.bak" -Force
}

if (Test-Path $providerPath) {
  Remove-Item $providerPath -Force
  Write-Host "Removed bad creator_workspace_provider.dart" -ForegroundColor Yellow
}

# Rebuild creator barrel without the bad provider export.
$barrelContent = @"
export 'models/creator_workspace_mode.dart';
export 'ui/widgets/creator_empty_state.dart';
export 'ui/widgets/creator_mode_selector.dart';
export 'ui/widgets/creator_section_card.dart';
export 'ui/widgets/creator_unified_workbench.dart';
export 'ui/widgets/creator_workspace_header.dart';
"@

[System.IO.File]::WriteAllText($barrelPath, $barrelContent, $utf8NoBom)

# Rebuild CreatorScreen cleanly.
$screenContent = @"
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_unified_workbench.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/widgets/micro_tutorial_card.dart';
import 'package:fantastic_guacamole/tutorial/widgets/show_me_again_button.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorScreen extends ConsumerWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/creator_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartPressable(
                      onTap: () => ref.read(appFlowProvider.notifier).toNexus(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                AppColors.neonCyan,
                                AppColors.neonViolet,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'CREATOR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'TASK - GOAL - PLAN FORGE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _CreatorTutorialPanel(),
                const SizedBox(height: 16),
                const _CreatorPurposeCard(),
                const SizedBox(height: 16),
                const CreatorUnifiedWorkbench(),
                const SizedBox(height: 16),
                DynamicForm(
                  onSubmit: (data) async {
                    await ref.read(creatorActionsProvider).createTask(data);
                    await ref
                        .read(localMetricsAccumulatorProvider)
                        .recordTaskCreated();
                    ref.invalidate(tasksProvider);
                    ref.invalidate(goalProgressProvider);
                    ref
                        .read(tutorialControllerProvider)
                        .updateState('has_created_task', true);

                    if (context.mounted) {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Creator entry saved.'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorTutorialPanel extends ConsumerWidget {
  const _CreatorTutorialPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);
    final TutorialStepContent step = TutorialContent.steps.firstWhere(
      (TutorialStepContent content) => content.id == 'creator_workbench',
      orElse: () => TutorialContent.steps.first,
    );

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (progress) {
        if (progress.isStepCompleted(step.id)) {
          return const SizedBox.shrink();
        }

        if (progress.isStepDismissed(step.id)) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ShowMeAgainButton(
              stepId: step.id,
              label: 'Show Creator Tutorial Again',
            ),
          );
        }

        return MicroTutorialCard(
          step: step,
          onComplete: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
          onDismiss: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
        );
      },
    );
  }
}

class _CreatorPurposeCard extends StatelessWidget {
  const _CreatorPurposeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.14)),
      ),
      child: const Text(
        'Creator is the unified workbench for tasks, goals, milestones, and planning. Use it to forge new entries, connect them to goals, and shape your plan from one future-facing command surface.',
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
      ),
    );
  }
}
"@

[System.IO.File]::WriteAllText($screenPath, $screenContent, $utf8NoBom)

# Make sure the workbench is local StatefulWidget, not provider based.
$workbenchText = Get-Content $workbenchPath -Raw

$workbenchText = $workbenchText -replace "import 'package:flutter_riverpod/flutter_riverpod.dart';\r?\n", ""
$workbenchText = $workbenchText -replace "import 'package:fantastic_guacamole/features/creator/state/creator_workspace_provider.dart';\r?\n", ""

$workbenchText = $workbenchText -replace "class CreatorUnifiedWorkbench extends ConsumerWidget \{[\s\S]*?class _CreatorWorkspaceDashboard extends StatelessWidget", @"
class CreatorUnifiedWorkbench extends StatefulWidget {
  const CreatorUnifiedWorkbench({super.key});

  @override
  State<CreatorUnifiedWorkbench> createState() =>
      _CreatorUnifiedWorkbenchState();
}

class _CreatorUnifiedWorkbenchState extends State<CreatorUnifiedWorkbench> {
  CreatorWorkspaceMode _mode = CreatorWorkspaceMode.tasks;

  @override
  Widget build(BuildContext context) {
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
            selected: _mode,
            onSelected: (mode) {
              setState(() {
                _mode = mode;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        _CreatorModeForge(mode: _mode),
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

[System.IO.File]::WriteAllText($workbenchPath, $workbenchText, $utf8NoBom)

Write-Host "Checking for HTML or encoding corruption..." -ForegroundColor Cyan
$bad = Select-String -Path ".\lib\features\creator\**\*.dart" -Pattern "<br>|&gt;|&lt;|�|?" -ErrorAction SilentlyContinue
if ($bad) {
  $bad | Select-Object Path,LineNumber,Line
  throw "Creator still has corruption."
}

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator repaired and stable." -ForegroundColor Green
