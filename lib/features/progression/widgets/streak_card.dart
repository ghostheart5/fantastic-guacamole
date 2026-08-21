import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/state/models/user_progress.dart';
import 'package:flutter/material.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.progress});

  final UserProgress progress;

  @override
  Widget build(BuildContext context) {
    final String detail = progress.longestStreak > 0
        ? '${progress.streakMessage}  Best streak: ${progress.longestStreak} days.'
        : progress.streakMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.neonViolet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.neonViolet.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: AppColors.neonViolet,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${progress.streak}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonViolet,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'DAY STREAK',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        color: Color(0xFFD7DFF0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFFC6D0E2),
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
