$ErrorActionPreference = "Stop"

Write-Host "Making Creator real: unified workbench integration..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path ".\lib\features\creator\ui\widgets" | Out-Null

# ------------------------------------------------------------
# Create unified Creator workbench widget
# ------------------------------------------------------------
$workbenchPath = ".\lib\features\creator\ui\widgets\creator_unified_workbench.dart"

$workbenchContent = @"
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_empty_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_mode_selector.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_section_card.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_workspace_header.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

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

          final cards = [
            const _CreatorStatTile(
              label: 'Tasks',
              value: 'Forge',
              accent: AppColors.neonCyan,
            ),
            const _CreatorStatTile(
              label: 'Goals',
              value: 'Align',
              accent: AppColors.neonViolet,
            ),
            const _CreatorStatTile(
              label: 'Milestones',
              value: 'Track',
              accent: AppColors.memoryAmber,
            ),
            const _CreatorStatTile(
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
              'Use the main form below to create concrete tasks that can be connected to goals and plans.',
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
              'Goals live inside Creator now. This section prepares goal creation and relationship mapping.',
          accent: AppColors.neonViolet,
          child: CreatorEmptyState(
            title: 'Goal forge ready',
            message:
                'Next step: wire goal creation into this mode and link goals to tasks.',
            icon: Icons.track_changes,
          ),
        );
      case CreatorWorkspaceMode.milestones:
        return const CreatorSectionCard(
          label: 'Milestone Forge',
          title: 'Define checkpoints',
          description:
              'Milestones become progress checkpoints inside the Creator workflow.',
          accent: AppColors.memoryAmber,
          child: CreatorEmptyState(
            title: 'Milestone forge ready',
            message:
                'Next step: create milestone records and attach them to goals.',
            icon: Icons.flag_outlined,
          ),
        );
      case CreatorWorkspaceMode.plan:
        return const CreatorSectionCard(
          label: 'Plan Forge',
          title: 'Arrange execution',
          description:
              'Planning becomes the layout layer for tasks, goals, and milestones.',
          accent: Colors.greenAccent,
          child: CreatorEmptyState(
            title: 'Plan forge ready',
            message:
                'Next step: build today view, priority ordering, and schedule blocks.',
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
          'Creator should link every created item into a useful execution chain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreatorConnectionRow(
            source: 'Task',
            target: 'Goal',
            detail: 'Actions should support measurable outcomes.',
          ),
          SizedBox(height: 8),
          _CreatorConnectionRow(
            source: 'Goal',
            target: 'Milestone',
            detail: 'Outcomes should break into checkpoints.',
          ),
          SizedBox(height: 8),
          _CreatorConnectionRow(
            source: 'Milestone',
            target: 'Plan',
            detail: 'Checkpoints should shape daily execution.',
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
# Update Creator barrel file
# ------------------------------------------------------------
$barrelPath = ".\lib\features\creator\creator.dart"

if (Test-Path $barrelPath) {
  $barrel = Get-Content $barrelPath -Raw
} else {
  $barrel = ""
}

if ($barrel -notmatch "creator_unified_workbench.dart") {
  $barrel = $barrel.TrimEnd() + "`r`nexport 'ui/widgets/creator_unified_workbench.dart';`r`n"
  [System.IO.File]::WriteAllText($barrelPath, $barrel, $utf8NoBom)
}

# ------------------------------------------------------------
# Wire into CreatorScreen
# ------------------------------------------------------------
$screenPath = ".\lib\features\creator\ui\creator_screen.dart"

if (-not (Test-Path $screenPath)) {
  throw "Missing CreatorScreen: $screenPath"
}

$screen = Get-Content $screenPath -Raw

if ($screen -notmatch "creator_unified_workbench.dart") {
  $screen = $screen -replace
    "import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';",
    "import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';`r`nimport 'package:fantastic_guacamole/features/creator/ui/widgets/creator_unified_workbench.dart';"
}

if ($screen -notmatch "CreatorUnifiedWorkbench") {
  $target = "const _CreatorPurposeCard(),`r`n                const SizedBox(height: 16),"
  $insert = "const _CreatorPurposeCard(),`r`n                const SizedBox(height: 16),`r`n                const CreatorUnifiedWorkbench(),`r`n                const SizedBox(height: 16),"

  if ($screen.Contains($target)) {
    $screen = $screen.Replace($target, $insert)
  } else {
    throw "Could not find CreatorPurposeCard insertion point."
  }
}

# Clean known bad text artifacts if they appear again.
$screen = $screen.Replace("�", "-")
$screen = $screen.Replace("<br>", "")
$screen = $screen.Replace("&gt;", ">")
$screen = $screen.Replace("&lt;", "<")

[System.IO.File]::WriteAllText($screenPath, $screen, $utf8NoBom)

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator unified workbench is now real." -ForegroundColor Green
