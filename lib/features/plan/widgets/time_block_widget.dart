import 'package:fantastic_guacamole/features/plan/widgets/time_slot.dart';
import 'package:flutter/material.dart';

class TimeBlockWidget extends StatelessWidget {
  const TimeBlockWidget({
    super.key,
    required this.title,
    required this.start,
    required this.end,
    required this.accent,
  });

  final String title;
  final String start;
  final String end;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: TimeSlot(start: start, end: end),
          ),
        ],
      ),
    );
  }
}
