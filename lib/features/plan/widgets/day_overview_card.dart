import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
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
          _item('Blocks', '$blocksCount', AppColors.neonCyan),
          _item('Energy', '${(energy * 100).round()}%', AppColors.memoryAmber),
          _item('Mode', energy > 0.6 ? 'Deep' : 'Steady', AppColors.neonViolet),
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
