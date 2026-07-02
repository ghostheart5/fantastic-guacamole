import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 2),
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final bool selected = selectedIndex == i;
          return InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.neonViolet.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.neonViolet.withValues(alpha: 0.55)
                      : Colors.white12,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _days[i],
                style: TextStyle(
                  color: selected ? AppColors.neonViolet : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
