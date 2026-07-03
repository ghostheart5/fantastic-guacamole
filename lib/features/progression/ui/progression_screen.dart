import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/domain/usecases/get_progress_signals.dart';
import 'package:fantastic_guacamole/engine/si/offline/narrative_engine.dart';
import 'package:fantastic_guacamole/features/progression/widgets/level_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/streak_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/weekly_summary_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final progressSignalsProvider = Provider<ProgressSignals>((ref) {
  final traj = ref.watch(trajectorySummaryProvider);
  return GetProgressSignals()(traj);
});

final narrativeProvider = Provider<UserNarrative>((ref) {
  final profile = ref.watch(profileProvider);
  final signals = ref.watch(progressSignalsProvider);
  final consistency = signals.consistency.startsWith('High')
      ? 0.9
      : signals.consistency.startsWith('Med')
          ? 0.6
          : 0.3;
  return const NarrativeEngine().generate(
    streak: profile.streak,
    completedTasks: profile.xp ~/ 10,
    consistency: consistency,
  );
});

class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(progressionProvider);
    final progress = progression.progress;

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartPressable(
                      onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                AppColors.memoryAmber,
                                AppColors.neonCyan,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'PROGRESSION',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'GROWTH MATRIX',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const WeeklySummaryCard(),
                const SizedBox(height: 16),
                LevelCard(progress: progress),
                const SizedBox(height: 16),
                StreakCard(progress: progress),
                const SizedBox(height: 16),
                const _ProgressSignalsCard(),
                const SizedBox(height: 12),
                const _NarrativeCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressSignalsCard extends ConsumerWidget {
  const _ProgressSignalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(progressSignalsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonCyan,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SIGNALS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: AppColors.neonCyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SignalRow(label: 'Momentum', value: signals.momentum),
          const SizedBox(height: 10),
          _SignalRow(label: 'Consistency', value: signals.consistency),
          const SizedBox(height: 10),
          _SignalRow(label: 'Load', value: signals.load),
          const SizedBox(height: 10),
          _SignalRow(label: 'Direction', value: signals.direction),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.label, required this.value});
  final String label;
  final String value;

  Color _valueColor() {
    switch (value) {
      case 'High':
      case 'On Track':
      case 'Light':
        return AppColors.neonCyan;
      case 'Medium':
      case 'Balanced':
      case 'Slightly Off':
        return AppColors.memoryAmber;
      case 'Low':
      case 'Heavy':
      case 'Off Track':
        return AppColors.recallRed;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _valueColor(),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _NarrativeCard extends ConsumerWidget {
  const _NarrativeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrative = ref.watch(narrativeProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonViolet.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR STORY',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2.5,
              color: AppColors.neonViolet,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            narrative.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            narrative.trajectory,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
