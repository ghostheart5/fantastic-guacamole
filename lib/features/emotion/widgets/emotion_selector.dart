import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter/material.dart';

class EmotionSelector extends StatelessWidget {
  const EmotionSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final EmotionalState selected;
  final ValueChanged<EmotionalState> onSelect;

  static Color _colorFor(EmotionalState state) {
    switch (state) {
      case EmotionalState.positive:
      case EmotionalState.energized:
        return AppColors.neonCyan;
      case EmotionalState.negative:
      case EmotionalState.anxious:
        return AppColors.recallRed;
      case EmotionalState.fatigued:
      case EmotionalState.scattered:
        return AppColors.memoryAmber;
      case EmotionalState.focused:
        return AppColors.neonViolet;
      case EmotionalState.calm:
      case EmotionalState.neutral:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EmotionalState.values.map((state) {
        final isSelected = state == selected;
        final color = _colorFor(state);
        return SmartPressable(
          onTap: () => onSelect(state),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              state.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : Colors.white38,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
