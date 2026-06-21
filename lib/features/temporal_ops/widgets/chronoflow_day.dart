import 'package:flutter/material.dart';

class ChronoflowDay extends StatelessWidget {
  final List<double> values;
  const ChronoflowDay({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values
          .map(
            (double v) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 40 + (v * 30),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
