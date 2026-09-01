import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

enum _ProgressionShareAction { progress, achievement }

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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      label: 'Back to Nexus',
                      button: true,
                      onTap: () => goToAppView(context, ref, AppView.nexus),
                      child: IconButton(
                        tooltip: 'Back to Nexus',
                        onPressed: () =>
                            goToAppView(context, ref, AppView.nexus),
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TemporalScreenHeader(
                        title: 'PROGRESSION',
                        subtitle: 'See what your actions are building.',
                        eyebrow: 'Observed continuity',
                        accent: AppColors.memoryAmber,
                        trailing: PopupMenuButton<_ProgressionShareAction>(
                          tooltip: 'Share progression',
                          color: const Color(0xFF101827),
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: AppColors.memoryAmber,
                          ),
                          onSelected: (_ProgressionShareAction action) async {
                            switch (action) {
                              case _ProgressionShareAction.progress:
                                await _shareProgressCard(context, ref);
                              case _ProgressionShareAction.achievement:
                                await _shareAchievementCard(context, ref);
                            }
                          },
                          itemBuilder: (BuildContext context) => const [
                            PopupMenuItem<_ProgressionShareAction>(
                              value: _ProgressionShareAction.progress,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insights_rounded,
                                    color: AppColors.memoryAmber,
                                  ),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Progress snapshot',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<_ProgressionShareAction>(
                              value: _ProgressionShareAction.achievement,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.emoji_events_outlined,
                                    color: AppColors.neonCyan,
                                  ),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Achievement',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProgressionOverview(
                  level: progress.level,
                  levelTitle: progress.levelTitle,
                  levelProgress: progress.levelProgress,
                  xpToNext: progress.xpToNext,
                  streak: progress.streak,
                  streakMessage: progress.streakMessage,
                ),
                const SizedBox(height: 18),
                const TemporalDivider(color: AppColors.memoryAmber),
                const SizedBox(height: 18),
                const TemporalGlassSurface(
                  accent: AppColors.memoryAmber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ObservedContinuitySummary(),
                      SizedBox(height: 18),
                      Divider(color: Colors.white12),
                      SizedBox(height: 18),
                      _XpProgressChartCard(),
                      SizedBox(height: 18),
                      Divider(color: Colors.white12),
                      SizedBox(height: 18),
                      _ProgressSignalsCard(),
                      SizedBox(height: 18),
                      Divider(color: Colors.white12),
                      SizedBox(height: 18),
                      _NarrativeCard(),
                      SizedBox(height: 18),
                      Divider(color: Colors.white12),
                      SizedBox(height: 18),
                      _AdvisorSummaryCard(),
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

class _ProgressionOverview extends StatelessWidget {
  const _ProgressionOverview({
    required this.level,
    required this.levelTitle,
    required this.levelProgress,
    required this.xpToNext,
    required this.streak,
    required this.streakMessage,
  });

  final int level;
  final String levelTitle;
  final double levelProgress;
  final int xpToNext;
  final int streak;
  final String streakMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox.square(
          dimension: 88,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox.square(
                dimension: 78,
                child: CircularProgressIndicator(
                  value: levelProgress,
                  strokeWidth: 5,
                  backgroundColor: AppColors.memoryAmber.withValues(
                    alpha: 0.14,
                  ),
                  color: AppColors.memoryAmber,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$level',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.memoryAmber,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const Text(
                    'LEVEL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'LEVEL $level · ${levelTitle.toUpperCase()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.memoryAmber,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$xpToNext XP until Level ${level + 1}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.local_fire_department_outlined,
                    color: AppColors.memoryAmber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$streak day streak · $streakMessage',
                      style: const TextStyle(
                        color: Color(0xFFD7DFF0),
                        fontSize: 12,
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ObservedContinuitySummary extends ConsumerWidget {
  const _ObservedContinuitySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final trajectory = ref.watch(trajectorySummaryProvider);
    final milestoneSummary = ref.watch(milestoneSummaryProvider);
    final int timelineMilestones = ref
        .watch(timelineProvider)
        .where((event) => event.isMilestone)
        .length;
    final String milestoneText =
        milestoneSummary.total == 0 && timelineMilestones == 0
        ? 'No milestones recorded yet.'
        : 'Milestones completed: ${milestoneSummary.completed}/${milestoneSummary.total} · Timeline milestones: $timelineMilestones';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'OBSERVED CONTINUITY',
          style: TextStyle(
            color: AppColors.memoryAmber,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            _ProgressMetric(
              label: 'COMPLETED',
              value: '${trajectory.completedTasks}',
              color: AppColors.neonCyan,
            ),
            const _ProgressMetricDivider(),
            _ProgressMetric(
              label: 'STREAK',
              value: '${profile.streak}d',
              color: AppColors.neonViolet,
            ),
            const _ProgressMetricDivider(),
            _ProgressMetric(
              label: 'PRESSURE',
              value: '${trajectory.pressureIndex}%',
              color: AppColors.memoryAmber,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          milestoneText,
          style: const TextStyle(
            color: Color(0xFFC6D0E2),
            fontSize: 12,
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
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
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetricDivider extends StatelessWidget {
  const _ProgressMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white12,
    );
  }
}

class _ProgressSignalsCard extends ConsumerWidget {
  const _ProgressSignalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(progressSignalsProvider);

    return Column(
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
                fontSize: 11,
                letterSpacing: 0,
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7DFF0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: _valueColor(),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WHAT YOUR ACTIONS ARE CHANGING',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0,
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
            color: Color(0xFFC6D0E2),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AdvisorSummaryCard extends ConsumerWidget {
  const _AdvisorSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(weeklySummaryProvider);
    final action = _ProgressionAdvisorAction.from(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT CAPABILITY TO PRACTICE',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0,
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
                  color: Color(0xFFD7DFF0),
                  fontSize: 13,
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
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Text(
            'Building a progress view from your saved Timeline and completed actions...',
            style: TextStyle(color: Color(0xFFC6D0E2), fontSize: 13),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Not enough saved evidence yet. Add or complete an item, then return to see a grounded progression signal.',
                style: TextStyle(
                  color: Color(0xFFC6D0E2),
                  fontSize: 13,
                  height: 1.45,
                ),
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
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPLETION MOMENTUM',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0,
            color: AppColors.memoryAmber,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (points.isNotEmpty) ...[
          Text(
            'Last ${points.length} checkpoints • ${end - start >= 0 ? '+' : ''}${end - start} completed',
            style: const TextStyle(
              color: Color(0xFFC6D0E2),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (points.isEmpty)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.show_chart_rounded,
                color: AppColors.memoryAmber,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your momentum trend will appear after you complete an item.',
                  style: TextStyle(
                    color: Color(0xFFD7DFF0),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
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
