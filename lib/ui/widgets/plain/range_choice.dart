import 'package:flutter/material.dart';

/// Row of choice chips for a small set of ranges. Exactly one is selected.
/// Labels come from the caller, in the right language. Chip labels never wrap,
/// so callers pass short labels such as "7 days"; the chips wrap onto further
/// lines instead. Each chip's tap area is padded to 48 dp.
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
      children: <Widget>[
        for (int i = 0; i < labels.length; i++)
          ChoiceChip(
            label: Text(labels[i]),
            selected: i == selectedIndex,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onSelected(i),
          ),
      ],
    );
  }
}
