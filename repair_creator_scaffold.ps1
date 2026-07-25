$ErrorActionPreference = "Stop"

Write-Host "Repairing missing Creator scaffold files..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path ".\lib\features\creator\models" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\features\creator\ui\widgets" | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ------------------------------------------------------------
# creator_workspace_mode.dart
# ------------------------------------------------------------
[System.IO.File]::WriteAllText(
  ".\lib\features\creator\models\creator_workspace_mode.dart",
@"
enum CreatorWorkspaceMode {
  tasks,
  goals,
  milestones,
  plan,
}

extension CreatorWorkspaceModeLabel on CreatorWorkspaceMode {
  String get label {
    switch (this) {
      case CreatorWorkspaceMode.tasks:
        return 'Tasks';
      case CreatorWorkspaceMode.goals:
        return 'Goals';
      case CreatorWorkspaceMode.milestones:
        return 'Milestones';
      case CreatorWorkspaceMode.plan:
        return 'Plan';
    }
  }

  String get subtitle {
    switch (this) {
      case CreatorWorkspaceMode.tasks:
        return 'Forge actionable task entries.';
      case CreatorWorkspaceMode.goals:
        return 'Shape measurable goal outcomes.';
      case CreatorWorkspaceMode.milestones:
        return 'Define checkpoint progress.';
      case CreatorWorkspaceMode.plan:
        return 'Arrange the day into motion.';
    }
  }
}
"@,
  $utf8NoBom
)

# ------------------------------------------------------------
# creator_workspace_header.dart
# ------------------------------------------------------------
[System.IO.File]::WriteAllText(
  ".\lib\features\creator\ui\widgets\creator_workspace_header.dart",
@"
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CreatorWorkspaceHeader extends StatelessWidget {
  const CreatorWorkspaceHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.neonCyan.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.neonCyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
"@,
  $utf8NoBom
)

# ------------------------------------------------------------
# creator_section_card.dart
# ------------------------------------------------------------
[System.IO.File]::WriteAllText(
  ".\lib\features\creator\ui\widgets\creator_section_card.dart",
@"
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CreatorSectionCard extends StatelessWidget {
  const CreatorSectionCard({
    super.key,
    required this.label,
    required this.title,
    required this.description,
    required this.child,
    this.accent = AppColors.neonCyan,
  });

  final String label;
  final String title;
  final String description;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
"@,
  $utf8NoBom
)

# ------------------------------------------------------------
# creator_mode_selector.dart
# ------------------------------------------------------------
[System.IO.File]::WriteAllText(
  ".\lib\features\creator\ui\widgets\creator_mode_selector.dart",
@"
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CreatorModeSelector extends StatelessWidget {
  const CreatorModeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CreatorWorkspaceMode selected;
  final ValueChanged<CreatorWorkspaceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CreatorWorkspaceMode.values.map((mode) {
        final bool active = mode == selected;

        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onSelected(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.neonCyan.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active
                    ? AppColors.neonCyan.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              mode.label,
              style: TextStyle(
                color: active ? AppColors.neonCyan : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
"@,
  $utf8NoBom
)

# ------------------------------------------------------------
# recreate clean barrel file
# ------------------------------------------------------------
[System.IO.File]::WriteAllText(
  ".\lib\features\creator\creator.dart",
@"
export 'models/creator_workspace_mode.dart';
export 'ui/widgets/creator_empty_state.dart';
export 'ui/widgets/creator_mode_selector.dart';
export 'ui/widgets/creator_section_card.dart';
export 'ui/widgets/creator_workspace_header.dart';
"@,
  $utf8NoBom
)

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator scaffold repaired." -ForegroundColor Green
