import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/features/progression/widgets/level_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/streak_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                // Header with back button
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

                LevelCard(progress: progress),
                const SizedBox(height: 16),

                StreakCard(progress: progress),
                const SizedBox(height: 16),

                // XP breakdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050D1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: 0.06),
                        blurRadius: 16,
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
                              color: AppColors.neonCyan,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'XP BREAKDOWN',
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
                      _XpRow(
                        label: 'Total XP',
                        value: '${progress.xp}',
                        color: AppColors.neonCyan,
                      ),
                      Container(height: 0.5, color: Colors.white10),
                      _XpRow(
                        label: 'This Level',
                        value: '${progress.xpInLevel}/${progress.xpPerLevel}',
                        color: AppColors.neonViolet,
                      ),
                      Container(height: 0.5, color: Colors.white10),
                      _XpRow(
                        label: 'XP to Next',
                        value: '${progress.xpToNext}',
                        color: AppColors.memoryAmber,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XpRow extends StatelessWidget {
  const _XpRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
