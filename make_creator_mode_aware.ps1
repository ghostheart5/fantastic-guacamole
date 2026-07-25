$ErrorActionPreference = "Stop"

Write-Host "Making Creator mode-aware without provider wiring..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$screenPath = ".\lib\features\creator\ui\creator_screen.dart"
$workbenchPath = ".\lib\features\creator\ui\widgets\creator_unified_workbench.dart"
$formPath = ".\lib\features\creator\widgets\dynamic_form.dart"

if (-not (Test-Path $screenPath)) {
  throw "Missing CreatorScreen: $screenPath"
}

if (-not (Test-Path $workbenchPath)) {
  throw "Missing CreatorUnifiedWorkbench: $workbenchPath"
}

if (-not (Test-Path $formPath)) {
  throw "Missing DynamicForm: $formPath"
}

Copy-Item $screenPath "$screenPath.bak_mode" -Force
Copy-Item $workbenchPath "$workbenchPath.bak_mode" -Force
Copy-Item $formPath "$formPath.bak_mode" -Force

# ------------------------------------------------------------
# Rebuild CreatorUnifiedWorkbench as controlled widget
# ------------------------------------------------------------
$workbenchContent = @"
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_empty_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_mode_selector.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_section_card.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_workspace_header.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CreatorUnifiedWorkbench extends StatelessWidget {
  const CreatorUnifiedWorkbench({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final CreatorWorkspaceMode selectedMode;
  final ValueChanged<CreatorWorkspaceMode> onModeChanged;

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
            selected: selectedMode,
            onSelected: onModeChanged,
          ),
        ),
        const SizedBox(height: 16),
        _CreatorModeForge(mode: selectedMode),
        const SizedBox(height: 16),
        const _CreatorConnectedObjects(),
        const SizedBox(height: 16),
        const _CreatorActivityFeed(),
      ],
    );
  }
}

class _CreatorWorkspaceDashboard extends StatelessWidget {
  const _CreatorWorkspaceDashboard();

  @override
  Widget build(BuildContext context) {
    return CreatorSectionCard(
      label: 'Workspace Overview',
      title: 'Creator Command Surface',
      description:
          'A single view for building tasks, shaping goals, defining milestones, and planning execution.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 420;

          const cards = [
            _CreatorStatTile(
              label: 'Tasks',
              value: 'Forge',
              accent: AppColors.neonCyan,
            ),
            _CreatorStatTile(
              label: 'Goals',
              value: 'Align',
              accent: AppColors.neonViolet,
            ),
            _CreatorStatTile(
              label: 'Milestones',
              value: 'Track',
              accent: AppColors.memoryAmber,
            ),
            _CreatorStatTile(
              label: 'Plan',
              value: 'Execute',
              accent: Colors.greenAccent,
            ),
          ];

          if (compact) {
            return Column(
              children: cards
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: card,
                    ),
                  )
                  .toList(),
            );
          }

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: card,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _CreatorStatTile extends StatelessWidget {
  const _CreatorStatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorModeForge extends StatelessWidget {
  const _CreatorModeForge({required this.mode});

  final CreatorWorkspaceMode mode;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case CreatorWorkspaceMode.tasks:
        return const CreatorSectionCard(
          label: 'Task Forge',
          title: 'Create actionable work',
          description:
              'The form below will forge a task entry for execution.',
          child: CreatorEmptyState(
            title: 'Task forge active',
            message:
                'Create focused actions, assign intent, and move them into execution.',
            icon: Icons.check_circle_outline,
          ),
        );
      case CreatorWorkspaceMode.goals:
        return const CreatorSectionCard(
          label: 'Goal Forge',
          title: 'Shape measurable outcomes',
          description:
              'The form below will save the entry as a goal-shaped Creator item.',
          accent: AppColors.neonViolet,
          child: CreatorEmptyState(
            title: 'Goal forge active',
            message:
                'Capture goal intent now. Dedicated goal persistence can be wired next.',
            icon: Icons.track_changes,
          ),
        );
      case CreatorWorkspaceMode.milestones:
        return const CreatorSectionCard(
          label: 'Milestone Forge',
          title: 'Define checkpoints',
          description:
              'The form below will save the entry as a milestone-shaped Creator item.',
          accent: AppColors.memoryAmber,
          child: CreatorEmptyState(
            title: 'Milestone forge active',
            message:
                'Capture checkpoint progress now. Dedicated milestone persistence can be wired next.',
            icon: Icons.flag_outlined,
          ),
        );
      case CreatorWorkspaceMode.plan:
        return const CreatorSectionCard(
          label: 'Plan Forge',
          title: 'Arrange execution',
          description:
              'The form below will save the entry as a plan-shaped Creator item.',
          accent: Colors.greenAccent,
          child: CreatorEmptyState(
            title: 'Plan forge active',
            message:
                'Capture planning intent now. Dedicated planner persistence can be wired next.',
            icon: Icons.view_timeline_outlined,
          ),
        );
    }
  }
}

class _CreatorConnectedObjects extends StatelessWidget {
  const _CreatorConnectedObjects();

  @override
  Widget build(BuildContext context) {
    return const CreatorSectionCard(
      label: 'Connected Objects',
      title: 'Task to Goal to Milestone to Plan',
      description:
          'Creator links every created item into a useful execution chain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreatorConnectionRow(
            source: 'Task',
            target: 'Goal',
            detail: 'Actions support measurable outcomes.',
          ),
          SizedBox(height: 8),
          _CreatorConnectionRow(
            source: 'Goal',
            target: 'Milestone',
            detail: 'Outcomes break into checkpoints.',
          ),
          SizedBox(height: 8),
          _CreatorConnectionRow(
            source: 'Milestone',
            target: 'Plan',
            detail: 'Checkpoints shape daily execution.',
          ),
        ],
      ),
    );
  }
}

class _CreatorConnectionRow extends StatelessWidget {
  const _CreatorConnectionRow({
    required this.source,
    required this.target,
    required this.detail,
  });

  final String source;
  final String target;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Text(
            source.toUpperCase(),
            style: const TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward,
              color: Colors.white38,
              size: 14,
            ),
          ),
          Text(
            target.toUpperCase(),
            style: const TextStyle(
              color: AppColors.neonViolet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorActivityFeed extends StatelessWidget {
  const _CreatorActivityFeed();

  @override
  Widget build(BuildContext context) {
    return const CreatorSectionCard(
      label: 'Recent Activity',
      title: 'Creator continuity',
      description:
          'This feed will show recent task, goal, milestone, and plan changes.',
      child: Column(
        children: [
          _CreatorActivityItem(
            label: 'Task Created',
            detail: 'New entries appear here after creation.',
          ),
          SizedBox(height: 8),
          _CreatorActivityItem(
            label: 'Goal Updated',
            detail: 'Goal edits will surface in this timeline.',
          ),
          SizedBox(height: 8),
          _CreatorActivityItem(
            label: 'Plan Changed',
            detail: 'Planning updates will be tracked here.',
          ),
        ],
      ),
    );
  }
}

class _CreatorActivityItem extends StatelessWidget {
  const _CreatorActivityItem({
    required this.label,
    required this.detail,
  });

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.bolt,
          color: AppColors.memoryAmber,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label - $detail',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
"@

[System.IO.File]::WriteAllText($workbenchPath, $workbenchContent, $utf8NoBom)

# ------------------------------------------------------------
# Patch DynamicForm for workspace mode
# ------------------------------------------------------------
$form = Get-Content $formPath -Raw

if ($form -notmatch "creator_workspace_mode.dart") {
  $form = $form -replace
    "import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';",
    "import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';`r`nimport 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';"
}

$form = $form -replace
  "const DynamicForm\(\{super\.key, required this\.onSubmit\}\);",
  "const DynamicForm({super.key, required this.onSubmit, this.workspaceMode = CreatorWorkspaceMode.tasks});"

$form = $form -replace
  "final Future<void> Function\(CreatorFormData data\) onSubmit;",
  "final Future<void> Function(CreatorFormData data) onSubmit;`r`n  final CreatorWorkspaceMode workspaceMode;"

$form = $form -replace
  "setState\(\(\) => _errorMessage = 'Add a title before creating the task\.'\);",
  "setState(() => _errorMessage = 'Add a title before creating the entry.');"

$form = $form -replace
  "type: _selectedType,",
  "type: _entryType,"

$form = $form -replace
  "'The task could not be saved\. Your entry is still here.*?retry\.';",
  "'The entry could not be saved. Your entry is still here. Retry.';"

$form = $form -replace
  "_sectionLabel\('ENTRY DETAILS', AppColors\.memoryAmber\),",
  "_sectionLabel(_sectionTitle, AppColors.memoryAmber),"

$form = $form -replace
  "_buildTextField\(_titleController, 'Title \*', maxLines: 1\),",
  "_buildTextField(_titleController, _titleHint, maxLines: 1),"

$form = $form -replace
  "const Text\(\s*'FORGE TASK',",
  "Text(`r`n                      _submitLabel,"

# Insert helper getters inside _DynamicFormState before build.
if ($form -notmatch "String get _entryType") {
  $helperBlock = @"

  String get _modeLabel {
    switch (widget.workspaceMode) {
      case CreatorWorkspaceMode.tasks:
        return 'Task';
      case CreatorWorkspaceMode.goals:
        return 'Goal';
      case CreatorWorkspaceMode.milestones:
        return 'Milestone';
      case CreatorWorkspaceMode.plan:
        return 'Plan';
    }
  }

  String get _entryType {
    if (widget.workspaceMode == CreatorWorkspaceMode.tasks) {
      return _selectedType;
    }

    return _modeLabel;
  }

  String get _sectionTitle {
    return '${_modeLabel.toUpperCase()} DETAILS';
  }

  String get _titleHint {
    return '${_modeLabel} title *';
  }

  String get _submitLabel {
    switch (widget.workspaceMode) {
      case CreatorWorkspaceMode.tasks:
        return 'FORGE TASK';
      case CreatorWorkspaceMode.goals:
        return 'FORGE GOAL';
      case CreatorWorkspaceMode.milestones:
        return 'FORGE MILESTONE';
      case CreatorWorkspaceMode.plan:
        return 'FORGE PLAN ITEM';
    }
  }
"@

  $form = $form -replace
    "  @override\r?\n  Widget build\(BuildContext context\) \{",
    "$helperBlock`r`n  @override`r`n  Widget build(BuildContext context) {"
}

[System.IO.File]::WriteAllText($formPath, $form, $utf8NoBom)

# ------------------------------------------------------------
# Rebuild CreatorScreen as ConsumerStatefulWidget with selected mode
# ------------------------------------------------------------
$screenContent = @"
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
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

class CreatorScreen extends ConsumerStatefulWidget {
  const CreatorScreen({super.key});

  @override
  ConsumerState<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends ConsumerState<CreatorScreen> {
  CreatorWorkspaceMode _mode = CreatorWorkspaceMode.tasks;

  @override
  Widget build(BuildContext context) {
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
                            'TASK - GOAL - MILESTONE - PLAN FORGE',
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
                CreatorUnifiedWorkbench(
                  selectedMode: _mode,
                  onModeChanged: (mode) {
                    setState(() {
                      _mode = mode;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DynamicForm(
                  workspaceMode: _mode,
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
                          SnackBar(
                            content: Text('${_mode.name} entry saved.'),
                            duration: const Duration(seconds: 2),
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

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator mode-aware form is complete." -ForegroundColor Green
