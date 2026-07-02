import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/features/insights/models/insight_model.dart';
import 'package:flutter/material.dart';

class InsightsList extends StatelessWidget {
  const InsightsList({super.key, required this.items});

  final List<Insight> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No insights yet',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final Insight insight = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF050D1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                style: const TextStyle(
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                insight.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
