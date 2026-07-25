import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/theme/widgets/prism_metric_pill.dart';
import 'package:flutter/material.dart';

class DayOverviewCard extends StatelessWidget {
  const DayOverviewCard({
    super.key,
    required this.blocksCount,
    required this.energy,
  });

  final int blocksCount;
  final double energy;

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
          PrismMetricPill(
            label: 'Blocks',
            value: '$blocksCount',
            color: AppColors.neonCyan,
          ),
          PrismMetricPill(
            label: 'Energy',
            value: '${(energy * 100).round()}%',
            color: AppColors.memoryAmber,
          ),
          PrismMetricPill(
            label: 'Mode',
            value: energy > 0.6 ? 'Deep' : 'Steady',
            color: AppColors.neonViolet,
          ),
        ],
      ),
    );
  }
}
