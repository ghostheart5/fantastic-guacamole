import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/progression/widgets/level_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/streak_card.dart';
import 'package:fantastic_guacamole/features/progression/widgets/weekly_summary_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  Future<bool> _confirmShare(
    BuildContext context, {
    required String title,
    required String preview,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(
              'Review before sharing. This summary contains progress metrics, not your task or note text.\n\n$preview',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Share'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _shareProgressCard(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final trajectory = ref.read(trajectorySummaryProvider);
    final String text =
        'ChronoSpark Progress Snapshot\n'
        'Level ${profile.level} • XP ${profile.xp} • Streak ${profile.streak}d\n'
        'Momentum ${(trajectory.momentum * 100).round()}% • Completed tasks ${trajectory.completedTasks}\n'
        'Building consistency with ChronoSpark: ${AppUrls.website}';

    if (!await _confirmShare(
      context,
      title: 'Review progress snapshot',
      preview: text,
    )) {
      return;
    }

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

    if (!await _confirmShare(
      context,
      title: 'Review achievement snapshot',
      preview: text,
    )) {
      return;
    }

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
  Widget build(BuildContext context) {
    final progression = ref.watch(progressionProvider);
    final progress = progression.progress;

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgProgressionAscension,
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
                      onTap: () => goToAppView(context, ref, AppView.nexus),
                      semanticLabel: 'Back to Nexus',
                      child: Container(
                        width: 48,
                        height: 48,
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
                            'CAPABILITY BUILT THROUGH ACTION',
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
                'CAPABILITY SIGNALS',
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
          _SignalRow(label: 'Follow-through', value: signals.momentum),
          const SizedBox(height: 10),
          _SignalRow(label: 'Planning reliability', value: signals.consistency),
          const SizedBox(height: 10),
          _SignalRow(label: 'Recovery load', value: signals.load),
          const SizedBox(height: 10),
          _SignalRow(label: 'Recent direction', value: signals.direction),
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
            'WHAT YOUR ACTIONS ARE CHANGING',
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
    final action = _ProgressionAdvisorAction.from(ref);
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
            'NEXT CAPABILITY TO PRACTICE',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2.5,
              color: AppColors.memoryAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          summaryAsync.when(
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    _recordProgressionReview(ref);
                    action.navigate(context, ref);
                  },
                  icon: Icon(action.icon, size: 18),
                  label: Text(action.label),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.memoryAmber,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            loading: () => const Text(
              'Building a progress view from your saved Timeline and completed actions...',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Not enough saved evidence yet. Add or complete an item, then return to see a grounded progression signal.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    _recordProgressionReview(ref);
                    goToAppView(context, ref, AppView.creator);
                  },
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: const Text('Open Creator'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.memoryAmber,
                    side: BorderSide(
                      color: AppColors.memoryAmber.withValues(alpha: 0.7),
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _recordProgressionReview(WidgetRef ref) {
  unawaited(
    ref
        .read(adaptiveGuidanceProvider.notifier)
        .record(GuidanceMilestone.firstProgressionReview),
  );
}

enum _ProgressionAdvisorTarget { creator, timeline }

class _ProgressionAdvisorAction {
  const _ProgressionAdvisorAction({
    required this.target,
    required this.label,
    required this.icon,
  });

  final _ProgressionAdvisorTarget target;
  final String label;
  final IconData icon;

  static _ProgressionAdvisorAction from(WidgetRef ref) {
    final int overdueCount = ref.watch(timelineOverdueProvider).length;
    final int activeTasks = ref.watch(tasksProvider).asData?.value.length ?? 0;

    if (overdueCount > 0) {
      return const _ProgressionAdvisorAction(
        target: _ProgressionAdvisorTarget.timeline,
        label: 'Open Timeline',
        icon: Icons.event_repeat_rounded,
      );
    }
    if (activeTasks > 0) {
      return const _ProgressionAdvisorAction(
        target: _ProgressionAdvisorTarget.timeline,
        label: 'Open Timeline',
        icon: Icons.check_circle_outline_rounded,
      );
    }
    return const _ProgressionAdvisorAction(
      target: _ProgressionAdvisorTarget.creator,
      label: 'Open Creator',
      icon: Icons.add_task_rounded,
    );
  }

  void navigate(BuildContext context, WidgetRef ref) {
    switch (target) {
      case _ProgressionAdvisorTarget.creator:
        goToAppView(context, ref, AppView.creator);
      case _ProgressionAdvisorTarget.timeline:
        goToAppView(context, ref, AppView.timeline);
    }
  }
}

class _ProgressPoint {
  const _ProgressPoint(this.day, this.completed);

  final DateTime day;
  final int completed;
}

class _XpProgressChartCard extends ConsumerWidget {
  const _XpProgressChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(learningHistorySnapshotsProvider);
    final List<_ProgressPoint> points = _buildProgressPoints(history);
    final int start = points.isEmpty ? 0 : points.first.completed;
    final int end = points.isEmpty ? 0 : points.last.completed;

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
            'COMPLETION MOMENTUM',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.memoryAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Last ${points.length} checkpoints • ${end - start >= 0 ? '+' : ''}${end - start} completed',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Text(
              'Complete activity to establish a real progress history.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          else
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _ProgressLineChartPainter(points: points),
              ),
            ),
        ],
      ),
    );
  }

  List<_ProgressPoint> _buildProgressPoints(
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

    if (completedByDay.isEmpty) return <_ProgressPoint>[];

    final List<MapEntry<String, int>> sorted = completedByDay.entries.toList(
      growable: true,
    )..sort((a, b) => a.key.compareTo(b.key));

    final List<_ProgressPoint> points = <_ProgressPoint>[];
    int lastCompleted = 0;
    for (final MapEntry<String, int> entry in sorted) {
      final DateTime day = DateTime.parse(entry.key);
      lastCompleted = math.max(lastCompleted, entry.value);
      points.add(_ProgressPoint(day, lastCompleted));
    }

    final DateTime today = DateTime(now.year, now.month, now.day);
    if (points.isEmpty || points.last.day != today) {
      points.add(_ProgressPoint(today, lastCompleted));
    } else {
      points[points.length - 1] = _ProgressPoint(today, lastCompleted);
    }

    return points.length > 10 ? points.sublist(points.length - 10) : points;
  }
}

class _ProgressLineChartPainter extends CustomPainter {
  _ProgressLineChartPainter({required this.points});

  final List<_ProgressPoint> points;

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

    final int minCompleted = points.map((p) => p.completed).reduce(math.min);
    final int maxCompleted = points.map((p) => p.completed).reduce(math.max);
    final int span = math.max(1, maxCompleted - minCompleted);

    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final double x = (i / (points.length - 1)) * size.width;
      final double normalized = (points[i].completed - minCompleted) / span;
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
  bool shouldRepaint(covariant _ProgressLineChartPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) {
      return true;
    }
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i].completed != points[i].completed ||
          oldDelegate.points[i].day != points[i].day) {
        return true;
      }
    }
    return false;
  }
}
