import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklySummaryCard extends ConsumerWidget {
  const WeeklySummaryCard({super.key});

  String _pressureLabel(int index) {
    if (index >= 70) return 'High';
    if (index >= 40) return 'Balanced';
    return 'Light';
  }

  Color _pressureColor(int index) {
    if (index >= 70) return AppColors.recallRed;
    if (index >= 40) return AppColors.memoryAmber;
    return AppColors.neonCyan;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final traj = ref.watch(trajectorySummaryProvider);
    final milestoneSummary = ref.watch(milestoneSummaryProvider);
    final timelineMilestones = ref
        .watch(timelineProvider)
        .where((event) => event.isMilestone)
        .length;
    final String milestoneText =
        milestoneSummary.total == 0 && timelineMilestones == 0
        ? 'No milestones recorded yet.'
        : 'Milestones completed: ${milestoneSummary.completed}/${milestoneSummary.total}  •  Timeline milestones: $timelineMilestones';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonViolet,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'WEEK IN REVIEW',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppColors.neonViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neonViolet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level ${profile.level}',
                  style: const TextStyle(
                    color: AppColors.neonViolet,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatColumn(
                label: 'TOTAL COMPLETED',
                value: '${traj.completedTasks}',
                color: AppColors.neonCyan,
              ),
              _StatDivider(),
              _StatColumn(
                label: 'STREAK',
                value: '${profile.streak}d',
                color: Colors.deepOrangeAccent,
              ),
              _StatDivider(),
              _StatColumn(
                label: 'LOAD',
                value: _pressureLabel(traj.pressureIndex),
                color: _pressureColor(traj.pressureIndex),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            milestoneText,
            style: const TextStyle(
              color: Color(0xFFC6D0E2),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD7DFF0),
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFF344056),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
