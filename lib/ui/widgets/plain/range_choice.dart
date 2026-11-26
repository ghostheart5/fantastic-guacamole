import 'package:flutter/material.dart';

/// Row of choice chips for a small set of ranges. Exactly one is selected.
/// Labels come from the caller, in the right language.
class RangeChoice extends StatelessWidget {
  const RangeChoice({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (int i = 0; i < labels.length; i++)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1,
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: i == selectedIndex,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => onSelected(i),
              ),
            ),
          ),
      ],
    );
  }
}
