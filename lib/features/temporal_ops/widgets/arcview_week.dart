import 'package:flutter/material.dart';

class ArcviewWeek extends StatelessWidget {
  final List<int> values;
  const ArcviewWeek({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: values
          .map(
            (int v) => Chip(
              label: Text('D$v'),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.25),
            ),
          )
          .toList(),
    );
  }
}
