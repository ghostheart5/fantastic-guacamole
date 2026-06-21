import 'package:flutter/material.dart';

class EmotionsPanel extends StatelessWidget {
  final double level;
  final String label;
  final List<double> trend;

  const EmotionsPanel({
    super.key,
    required this.level,
    required this.label,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('State: $label (${(level * 100).toStringAsFixed(0)}%)'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: level.clamp(0, 1)),
        const SizedBox(height: 10),
        Row(
          children: trend
              .map(
                (double v) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 8 + (v * 24),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
