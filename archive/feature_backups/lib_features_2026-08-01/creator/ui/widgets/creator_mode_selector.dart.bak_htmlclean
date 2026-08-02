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
