import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Two-segment control for moving between two destinations in one tab.
class DestinationSwitch extends StatelessWidget {
  const DestinationSwitch({
    required this.firstLabel,
    required this.secondLabel,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  }) : assert(selectedIndex == 0 || selectedIndex == 1);

  final String firstLabel;
  final String secondLabel;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _segment(context, 0, firstLabel)),
        const SizedBox(width: 8),
        Expanded(child: _segment(context, 1, secondLabel)),
      ],
    );
  }

  Widget _segment(BuildContext context, int index, String label) {
    final bool selected = index == selectedIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: () => onSelected(index),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.25)
            : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
