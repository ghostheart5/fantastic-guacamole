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
      ],
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
        return const SizedBox.shrink();
    }
  }
}
