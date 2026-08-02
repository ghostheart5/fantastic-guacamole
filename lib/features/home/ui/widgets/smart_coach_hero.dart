import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';

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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(color: AppColors.glowCyan, blurRadius: 6, spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  key: const Key('smart_coach_back_button'),
                  onPressed: () => ref.read(appFlowProvider.notifier).toNexus(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  splashRadius: 16,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.neonCyan,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Smart Planner',
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _HeaderPill(
                label: 'Status',
                value: coachOnline ? 'Ready' : 'Offline',
                color: coachOnline ? AppColors.neonCyan : AppColors.recallRed,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Today\'s focus',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetricTile(
                label: 'Tasks',
                value: taskCount.toString(),
                color: AppColors.neonCyan,
              ),
              _MetricTile(
                label: 'Action',
                value: actionReady ? 'Ready' : 'Waiting',
                color: AppColors.neonViolet,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
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
          const SizedBox(height: 6),
          Text(
            coachMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (actionReady) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.neonViolet.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.neonViolet.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next action',
                    style: TextStyle(
                      color: AppColors.neonViolet,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextAction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
