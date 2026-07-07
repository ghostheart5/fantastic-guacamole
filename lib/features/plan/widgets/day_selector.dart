import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
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
      child: Row(
        children: List.generate(_days.length, (i) {
          final bool selected = selectedIndex == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _days.length - 1 ? 6 : 0),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.neonViolet.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.neonViolet.withValues(alpha: 0.6)
                          : Colors.white12,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.neonViolet.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _days[i],
                    style: TextStyle(
                      color: selected ? AppColors.neonViolet : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
