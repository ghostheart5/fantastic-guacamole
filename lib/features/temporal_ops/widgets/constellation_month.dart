import 'package:flutter/material.dart';

class ConstellationMonth extends StatelessWidget {
  final int activeDays;
  final double averageIntensity;

  const ConstellationMonth({
    super.key,
    required this.activeDays,
    required this.averageIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$activeDays active slots projected this month',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Average day intensity: ${(averageIntensity * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
