import 'dart:math' as math;

import 'package:fantastic_guacamole/features/progression/widgets/level_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/streak_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/weekly_summary_card.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(progressionProvider);
    final momentum = ref.watch(momentumEngineProvider);
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
                      onTap: () => ref.read(appFlowProvider.notifier).toNexus(),
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
                              'Progress',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'Levels, streaks, and momentum',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.6,
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
                const _XpProgressChartCard(),
                const SizedBox(height: 16),
                LevelCard(progress: progress),
                const SizedBox(height: 16),
                StreakCard(progress: progress),
                const SizedBox(height: 16),
                const _ProgressSignalsCard(),
                const SizedBox(height: 12),
                _MomentumEngineCard(momentum: momentum),
                const SizedBox(height: 12),
                const _MilestonesCard(),
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

class _MomentumEngineCard extends StatelessWidget {
  const _MomentumEngineCard({required this.momentum});

  final MomentumEngineState momentum;

  Color get _accent {
    if (momentum.trend == 'Rising') {
      return AppColors.neonCyan;
    }
    if (momentum.trend == 'Stable') {
      return AppColors.memoryAmber;
    }
    return AppColors.recallRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE050D1A),
            _accent.withValues(alpha: 0.12),
            AppColors.neonViolet.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.08), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MOMENTUM ENGINE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.neonCyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${momentum.score}%',
                style: TextStyle(
                  color: _accent,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  momentum.trend.toUpperCase(),
                  style: TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            momentum.forecast,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MomentumChip(
                label: 'ENERGY',
                value: '${momentum.energyPercent}%',
                color: AppColors.neonCyan,
              ),
              _MomentumChip(
                label: 'PRESSURE',
                value: '${momentum.pressurePercent}%',
                color: AppColors.memoryAmber,
              ),
              _MomentumChip(
                label: 'RECOVERY',
                value: momentum.recovery,
                color: _accent,
              ),
              _MomentumChip(
                label: 'TODAY',
                value: '${momentum.completedToday}',
                color: AppColors.neonViolet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MomentumChip extends StatelessWidget {
  const _MomentumChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
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
        gradient: LinearGradient(
          colors: [
            const Color(0xEE050D1A),
            AppColors.neonCyan.withValues(alpha: 0.10),
            AppColors.neonViolet.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.08),
            blurRadius: 18,
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
                'MOMENTUM MATRIX',
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
        gradient: LinearGradient(
          colors: [
            const Color(0xEE050D1A),
            AppColors.neonViolet.withValues(alpha: 0.12),
            AppColors.memoryAmber.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVOLUTION PATH',
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

class _XpPoint {
  const _XpPoint(this.day, this.xp);

  final DateTime day;
  final int xp;
}

class _XpProgressChartCard extends ConsumerWidget {
  const _XpProgressChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final history = ref.watch(learningHistorySnapshotsProvider);
    final List<_XpPoint> points = _buildXpPoints(profile.xp, history);
    final int start = points.isEmpty ? profile.xp : points.first.xp;
    final int end = points.isEmpty ? profile.xp : points.last.xp;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'XP VECTOR',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.memoryAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Last ${points.length} checkpoints | ${end - start >= 0 ? '+' : ''}${end - start} XP',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(painter: _XpLineChartPainter(points: points)),
          ),
        ],
      ),
    );
  }

  List<_XpPoint> _buildXpPoints(
    int currentXp,
    List<LearningHistorySnapshot> history,
  ) {
    final DateTime now = DateTime.now();
    final DateTime windowStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final Map<String, int> completedByDay = <String, int>{};

    for (final LearningHistorySnapshot entry in history) {
      final DateTime timestamp = entry.timestamp;
      final DateTime day = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
      );
      if (day.isBefore(windowStart)) {
        continue;
      }
      final String key = day.toIso8601String().split('T').first;
      final int completed = entry.completed;
      final int existing = completedByDay[key] ?? 0;
      completedByDay[key] = math.max(existing, completed);
    }

    if (completedByDay.isEmpty) {
      final int base = math.max(0, currentXp - 60);
      return List<_XpPoint>.generate(6, (int index) {
        final DateTime day = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: 5 - index));
        final double t = index / 5;
        return _XpPoint(day, (base + ((currentXp - base) * t)).round());
      });
    }

    final List<MapEntry<String, int>> sorted = completedByDay.entries.toList(
      growable: true,
    )..sort((a, b) => a.key.compareTo(b.key));
    final int maxCompleted = sorted.last.value <= 0 ? 1 : sorted.last.value;

    final List<_XpPoint> points = <_XpPoint>[];
    int lastXp = 0;
    for (final MapEntry<String, int> entry in sorted) {
      final DateTime day = DateTime.parse(entry.key);
      final int estimate = ((currentXp * (entry.value / maxCompleted)))
          .round()
          .clamp(0, currentXp);
      lastXp = math.max(lastXp, estimate);
      points.add(_XpPoint(day, lastXp));
    }

    final DateTime today = DateTime(now.year, now.month, now.day);
    if (points.isEmpty || points.last.day != today) {
      points.add(_XpPoint(today, currentXp));
    } else {
      points[points.length - 1] = _XpPoint(today, currentXp);
    }

    return points.length > 10 ? points.sublist(points.length - 10) : points;
  }
}

class _XpLineChartPainter extends CustomPainter {
  _XpLineChartPainter({required this.points});

  final List<_XpPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    final Paint linePaint = Paint()
      ..color = AppColors.memoryAmber
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Paint dotPaint = Paint()
      ..color = AppColors.neonCyan
      ..style = PaintingStyle.fill;

    for (int i = 1; i <= 3; i++) {
      final double y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      return;
    }

    final int minXp = points.map((p) => p.xp).reduce(math.min);
    final int maxXp = points.map((p) => p.xp).reduce(math.max);
    final int span = math.max(1, maxXp - minXp);

    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final double x = (i / (points.length - 1)) * size.width;
      final double normalized = (points[i].xp - minXp) / span;
      final double y = size.height - (normalized * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      if (i == points.length - 1) {
        canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _XpLineChartPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) {
      return true;
    }
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i].xp != points[i].xp ||
          oldDelegate.points[i].day != points[i].day) {
        return true;
      }
    }
    return false;
  }
}

class _MilestonesCard extends ConsumerWidget {
  const _MilestonesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MilestoneEntity> milestones =
        ref.watch(milestonesProvider).asData?.value ??
        const <MilestoneEntity>[];
    final List<MilestoneEntity> active = milestones
        .where(
          (MilestoneEntity m) =>
              m.status != MilestoneStatus.completed &&
              m.status != MilestoneStatus.archived,
        )
        .toList();
    final int completedCount = milestones
        .where((MilestoneEntity m) => m.status == MilestoneStatus.completed)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.15)),
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
                'CHECKPOINT VAULT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: AppColors.neonViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount completed',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No active milestones. Plan your next checkpoint.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            ...active
                .take(3)
                .map(
                  (MilestoneEntity m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (m.description != null &&
                                  m.description!.isNotEmpty)
                                Text(
                                  m.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: m.status == MilestoneStatus.overdue
                                ? AppColors.recallRed.withValues(alpha: 0.1)
                                : AppColors.neonViolet.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: m.status == MilestoneStatus.overdue
                                  ? AppColors.recallRed
                                  : AppColors.neonViolet,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            m.status.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              color: m.status == MilestoneStatus.overdue
                                  ? AppColors.recallRed
                                  : AppColors.neonViolet,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          if (active.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${active.length - 3} more',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
