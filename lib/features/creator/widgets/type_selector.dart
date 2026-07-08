import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class TypeSelector extends StatelessWidget {
  const TypeSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  static const _types = ['Task', 'Routine', 'Note', 'Goal'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.memoryAmber,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'TYPE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: AppColors.memoryAmber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.map((type) {
            final isSelected = type == selected;
            return SmartPressable(
              onTap: () => onSelect(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.memoryAmber.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.memoryAmber.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.memoryAmber.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.memoryAmber : Colors.white38,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
