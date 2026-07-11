import 'dart:math' as math;

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/features/progression/widgets/level_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/streak_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/weekly_summary_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  Future<void> _shareProgressCard(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final trajectory = ref.read(trajectorySummaryProvider);
    final String text =
        'ChronoSpark Progress Snapshot\n'
        'Level ${profile.level} • XP ${profile.xp} • Streak ${profile.streak}d\n'
        'Momentum ${(trajectory.momentum * 100).round()}% • Completed tasks ${trajectory.completedTasks}\n'
        'Building consistency with ChronoSpark: ${AppUrls.website}';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: 'ChronoSpark Progress Snapshot',
          subject: 'My ChronoSpark progression update',
        ),
      );
      AppAnalytics.track(
        'share_progress',
        params: <String, Object?>{'method': 'share_sheet'},
      );
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      AppAnalytics.track(
        'share_progress',
        params: <String, Object?>{'method': 'clipboard_fallback'},
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Share sheet unavailable. Progress snapshot copied to clipboard.',
        ),
      ),
    );
  }

  Future<void> _shareAchievementCard(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = ref.read(profileProvider);
    final trajectory = ref.read(trajectorySummaryProvider);
    final String text =
        'ChronoSpark Achievement Unlocked\n'
        'Level ${profile.level} achieved\n'
        'Current streak: ${profile.streak} days\n'
        'Momentum ${(trajectory.momentum * 100).round()}%\n'
        'Join me in ChronoSpark: ${AppUrls.website}';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: 'ChronoSpark Achievement',
          subject: 'I hit a new ChronoSpark milestone',
        ),
      );
      AppAnalytics.track(
        'share_achievement',
        params: <String, Object?>{'method': 'share_sheet'},
      );
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      AppAnalytics.track(
        'share_achievement',
        params: <String, Object?>{'method': 'clipboard_fallback'},
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Share sheet unavailable. Achievement summary copied to clipboard.',
        ),
      ),
    );
  }

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
                            'MOMENTUM INTEL + HISTORY',
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
                    IconButton(
                      tooltip: 'Share progress snapshot',
                      onPressed: () => _shareProgressCard(context, ref),
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: AppColors.memoryAmber,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Share achievement',
                      onPressed: () => _shareAchievementCard(context, ref),
                      icon: const Icon(
                        Icons.emoji_events_outlined,
                        color: AppColors.neonCyan,
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
                const _NarrativeCard(),
                const SizedBox(height: 12),
                const _AdvisorSummaryCard(),
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
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.15)),
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
                'TACTICAL SIGNALS',
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
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAJECTORY NARRATIVE',
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

class _AdvisorSummaryCard extends ConsumerWidget {
  const _AdvisorSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(weeklySummaryProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEM INTEL',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2.5,
              color: AppColors.memoryAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          summaryAsync.when(
            data: (summary) => Text(
              summary,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.55,
              ),
            ),
            loading: () => const Text(
              'Scanning signal matrix...',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            error: (_, _) => const Text(
              'Insufficient signal data.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
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
    final history = ref.watch(learningHistoryProvider);
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
            'XP PROGRESSION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.memoryAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Last ${points.length} checkpoints • ${end - start >= 0 ? '+' : ''}${end - start} XP',
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
    List<LearningHistoryEntry> history,
  ) {
    final DateTime now = DateTime.now();
    final DateTime windowStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final Map<String, int> completedByDay = <String, int>{};

    for (final LearningHistoryEntry entry in history) {
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
