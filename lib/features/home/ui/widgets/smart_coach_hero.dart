import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/theme/widgets/prism_metric_card.dart';

class SmartCoachHero extends ConsumerWidget {
  const SmartCoachHero({
    super.key,
    required this.coachMessage,
    required this.nextAction,
    required this.taskCount,
    required this.coachOnline,
    required this.executionCompletedToday,
    required this.executionDeferralsToday,
    required this.executionStabilityPercent,
  });

  final String coachMessage;
  final String nextAction;
  final int taskCount;
  final bool coachOnline;
  final int executionCompletedToday;
  final int executionDeferralsToday;
  final int executionStabilityPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool actionReady = nextAction.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(color: AppColors.glowCyan, blurRadius: 14, spreadRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('smart_coach_back_button'),
                onPressed: () => ref.read(appFlowProvider.notifier).toNexus(),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.neonCyan,
                  size: 18,
                ),
              ),
              const Text(
                'Smart Planner',
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Today\'s focus',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Tasks',
                  value: taskCount.toString(),
                  color: AppColors.neonCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Status',
                  value: coachOnline ? 'Ready' : 'Offline',
                  color: coachOnline ? AppColors.neonCyan : AppColors.recallRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Action',
                  value: actionReady ? 'Ready' : 'Waiting',
                  color: AppColors.neonViolet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderPill(
                label: 'Done',
                value: '$executionCompletedToday',
                color: const Color(0xFF7AF7C4),
              ),
              _HeaderPill(
                label: 'Defers',
                value: '$executionDeferralsToday',
                color: const Color(0xFFFFB86B),
              ),
              _HeaderPill(
                label: 'Stability',
                value: '$executionStabilityPercent%',
                color: AppColors.neonViolet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coachMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionReady) ...[
            const SizedBox(height: 8),
            const Text(
              'Next action',
              style: TextStyle(
                color: AppColors.neonViolet,
                fontSize: 11,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(nextAction, style: const TextStyle(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PrismMetricCard(label: label, value: value, color: color);
  }
}
