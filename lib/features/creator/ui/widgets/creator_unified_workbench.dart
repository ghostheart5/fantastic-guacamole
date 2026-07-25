import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_empty_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/widgets/creator_entry_lists.dart';
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
        const CreatorEntryLists(),
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
                BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 8),
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
          description: 'The form below will forge a task entry for execution.',
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
            child: Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
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
              style: const TextStyle(color: Colors.white60, fontSize: 11),
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
  const _CreatorActivityItem({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.bolt, color: AppColors.memoryAmber, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            ' - ',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}
