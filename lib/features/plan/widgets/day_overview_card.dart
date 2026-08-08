import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class DayOverviewCard extends StatelessWidget {
  const DayOverviewCard({
    super.key,
    required this.blocksCount,
    required this.energy,
    this.plannedMinutes = 0,
    this.unplannedTaskCount = 0,
  });

  final int blocksCount;
  final double energy;

  /// Minutes scheduled on the selected day, from AnalyzePlanContext.
  final int plannedMinutes;

  /// Tasks with no block anywhere in the plan, from AnalyzePlanContext.
  final int unplannedTaskCount;

  static String formatMinutes(int minutes) {
    if (minutes <= 0) {
      return '0m';
    }
    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;
    if (hours == 0) {
      return '${remainder}m';
    }
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        children: [
          _item('Blocks', '$blocksCount', AppColors.neonCyan),
          _item(
            'Planned',
            formatMinutes(plannedMinutes),
            AppColors.pulseNeonBlue,
          ),
          _item('Energy', '${(energy * 100).round()}%', AppColors.memoryAmber),
          _item('Mode', energy > 0.6 ? 'Deep' : 'Steady', AppColors.neonViolet),
          if (unplannedTaskCount > 0)
            _item('Unplanned', '$unplannedTaskCount', AppColors.recallRed),
        ],
      ),
    );
  }

  Widget _item(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
