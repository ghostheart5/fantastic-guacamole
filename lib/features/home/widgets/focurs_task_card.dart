import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:flutter/material.dart';

class FocusTaskCard extends StatelessWidget {
  const FocusTaskCard({super.key, required this.task});

  final TaskView task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.neonCyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FOCUS TARGET',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
