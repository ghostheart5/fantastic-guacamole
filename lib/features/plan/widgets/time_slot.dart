import 'package:flutter/material.dart';

class TimeSlot extends StatelessWidget {
  const TimeSlot({super.key, required this.start, required this.end});

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          start,
          // Without an explicit colour this inherited the ambient default and
          // could render near-invisible on the plan surface.
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '→ $end',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
