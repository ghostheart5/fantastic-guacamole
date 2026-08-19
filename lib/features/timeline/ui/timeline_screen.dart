import 'package:fantastic_guacamole/app/router/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _TimelineWindow { today, week, month, year, all }

enum _TimelineFilter {
  all,
  overdue,
  upcoming,
  milestones,
  risks,
  recommendations,
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  _TimelineWindow _window = _TimelineWindow.week;
  _TimelineFilter _filter = _TimelineFilter.all;
  String _query = '';
  List<TimelineEventEntity>? _cachedCombined;
  int? _cachedCombinedKey;
  DateTime? _cachedCombinedDay;

  @override
  Widget build(BuildContext context) {
    final List<TimelineEventEntity> baseEvents = ref.watch(timelineProvider);
    final List<GoalEntity> goals = ref.watch(goalsProvider);
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final DateTime now = DateTime.now();

    final int combinedKey = Object.hash(
      identityHashCode(baseEvents),
      identityHashCode(tasks),
      identityHashCode(goals),
    );
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<TimelineEventEntity> combined;
    if (_cachedCombined != null &&
        _cachedCombinedKey == combinedKey &&
        _cachedCombinedDay == today) {
      combined = _cachedCombined!;
    } else {
      final List<TimelineEventEntity> projected = _buildProjectedEvents(
        now: now,
        tasks: tasks,
        goals: goals,
      );
      combined = <TimelineEventEntity>[
        ...baseEvents,
        ...projected,
        ..._buildIntelligenceEvents(
          now: now,
          events: <TimelineEventEntity>[...baseEvents, ...projected],
        ),
      ]..sort((a, b) => _eventMoment(b).compareTo(_eventMoment(a)));
      _cachedCombined = combined;
      _cachedCombinedKey = combinedKey;
      _cachedCombinedDay = today;
    }

    final List<TimelineEventEntity> filtered = combined
        .where((TimelineEventEntity event) {
          final DateTime moment = _eventMoment(event);
          final bool inWindow = _inWindow(
            moment: moment,
            now: now,
            window: _window,
          );
          if (!inWindow) {
            return false;
          }
          final bool matchesFilter = switch (_filter) {
            _TimelineFilter.all => true,
            _TimelineFilter.overdue => event.isOverdue,
            _TimelineFilter.upcoming => event.isUpcoming,
            _TimelineFilter.milestones => event.isMilestone,
            _TimelineFilter.risks => event.isRisk,
            _TimelineFilter.recommendations => event.isRecommendation,
          };
          if (!matchesFilter) {
            return false;
          }
          final String q = _query.trim().toLowerCase();
          if (q.isEmpty) {
            return true;
          }
          return event.title.toLowerCase().contains(q) ||
              event.detail.toLowerCase().contains(q);
        })
        .toList(growable: false);

    final Map<String, List<TimelineEventEntity>> grouped =
        <String, List<TimelineEventEntity>>{};
    for (final TimelineEventEntity event in filtered) {
      final String key = DateTimeFormats.timelineDay(_eventMoment(event));
      grouped.putIfAbsent(key, () => <TimelineEventEntity>[]).add(event);
    }
    final List<String> days = grouped.keys.toList(growable: false);
    String? tutorialEventId;
    for (final TimelineEventEntity event in filtered) {
      if (event.phase == 'task') {
        tutorialEventId = event.id;
        break;
      }
    }

    final int overdueCount = filtered
        .where((TimelineEventEntity event) => event.isOverdue)
        .length;
    final int upcomingCount = filtered
        .where((TimelineEventEntity event) => event.isUpcoming)
        .length;
    final int milestoneCount = filtered
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;
    final int riskCount = filtered
        .where((TimelineEventEntity event) => event.isRisk)
        .length;
    final int recommendationCount = filtered
        .where((TimelineEventEntity event) => event.isRecommendation)
        .length;

    final int healthScore = _computeHealthScore(
      overdueCount: overdueCount,
      riskCount: riskCount,
      milestoneCount: milestoneCount,
      upcomingCount: upcomingCount,
    );
    final int riskScore = 100 - healthScore;
    final TimelineEventEntity? nextDeadline = _nearestUpcoming(filtered, now);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgTimelineThreads,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      SmartPressable(
                        onTap: () => goToAppView(context, ref, AppView.nexus),
                        semanticLabel: 'Back to Nexus',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.neonViolet.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.neonViolet.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.neonViolet,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                AppColors.neonViolet,
                                AppColors.neonCyan,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'TIMELINE',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'EVENT CHRONOLOGY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _TimelineIntelligenceStrip(
                    healthScore: healthScore,
                    riskScore: riskScore,
                    overdueCount: overdueCount,
                    upcomingCount: upcomingCount,
                    milestoneCount: milestoneCount,
                    riskCount: riskCount,
                    recommendationCount: recommendationCount,
                    nextDeadline: nextDeadline,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: TextField(
                    onChanged: (String value) => setState(() => _query = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search timeline...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white38,
                      ),
                      filled: true,
                      fillColor: const Color(0xAA091427),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.neonViolet.withValues(alpha: 0.25),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.neonCyan),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _WindowChips(
                    selected: _window,
                    onSelect: (_TimelineWindow value) =>
                        setState(() => _window = value),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _FilterChips(
                    selected: _filter,
                    onSelect: (_TimelineFilter value) =>
                        setState(() => _filter = value),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No Timeline evidence matches this window or filter.\nTry another view, reduce filters, or create an item in Creator to establish a baseline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final String day = days[i];
                      final List<TimelineEventEntity> dayEvents = grouped[day]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              day,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...dayEvents.map(
                            (TimelineEventEntity event) => _TimelineEventTile(
                              event: event,
                              tutorialTarget: event.id == tutorialEventId,
                            ),
                          ),
                        ],
                      );
                    }, childCount: days.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({required this.event, required this.tutorialTarget});
  final TimelineEventEntity event;
  final bool tutorialTarget;

  Color get _color {
    switch (event.type) {
      case TimelineEventType.reflection:
        return AppColors.neonViolet;
      case TimelineEventType.levelUp:
        return AppColors.memoryAmber;
      case TimelineEventType.goalComplete:
        return const Color(0xFF4CAF50);
      case TimelineEventType.streak:
        return Colors.deepOrangeAccent;
      case TimelineEventType.task:
        return AppColors.neonCyan;
      case TimelineEventType.goal:
        return const Color(0xFF7AF7C4);
      case TimelineEventType.habit:
        return const Color(0xFFFFB86B);
      case TimelineEventType.project:
        return const Color(0xFFC2A1FF);
      case TimelineEventType.milestone:
        return const Color(0xFFFFD166);
      case TimelineEventType.deadline:
        return event.isOverdue ? AppColors.recallRed : const Color(0xFF59C8FF);
      case TimelineEventType.forecast:
        return const Color(0xFF8CA0FF);
      case TimelineEventType.snapshot:
        return Colors.white70;
      case TimelineEventType.risk:
        return AppColors.recallRed;
      case TimelineEventType.recommendation:
        return AppColors.neonCyan;
      case TimelineEventType.noteCreated:
      case TimelineEventType.noteUpdated:
      case TimelineEventType.noteArchived:
      case TimelineEventType.noteDeleted:
        return AppColors.memoryAmber;
    }
  }

  IconData get _icon {
    switch (event.type) {
      case TimelineEventType.reflection:
        return Icons.edit_note_rounded;
      case TimelineEventType.levelUp:
        return Icons.bolt_rounded;
      case TimelineEventType.goalComplete:
        return Icons.flag_rounded;
      case TimelineEventType.streak:
        return Icons.local_fire_department_rounded;
      case TimelineEventType.task:
        return Icons.checklist_rounded;
      case TimelineEventType.goal:
        return Icons.flag_rounded;
      case TimelineEventType.habit:
        return Icons.repeat_rounded;
      case TimelineEventType.project:
        return Icons.account_tree_rounded;
      case TimelineEventType.milestone:
        return Icons.emoji_events_rounded;
      case TimelineEventType.deadline:
        return Icons.schedule_rounded;
      case TimelineEventType.forecast:
        return Icons.query_stats_rounded;
      case TimelineEventType.snapshot:
        return Icons.camera_alt_outlined;
      case TimelineEventType.risk:
        return Icons.warning_amber_rounded;
      case TimelineEventType.recommendation:
        return Icons.tips_and_updates_rounded;
      case TimelineEventType.noteCreated:
        return Icons.note_add_rounded;
      case TimelineEventType.noteUpdated:
        return Icons.edit_note_rounded;
      case TimelineEventType.noteArchived:
        return Icons.archive_rounded;
      case TimelineEventType.noteDeleted:
        return Icons.delete_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: tutorialTarget ? FirstRunTutorialTargets.timelineEvidence : null,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color.withValues(alpha: 0.4)),
                ),
                child: Icon(_icon, color: _color, size: 13),
              ),
              Container(
                width: 1,
                height: 20,
                color: _color.withValues(alpha: 0.15),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF050D1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _color.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Titles are user-entered, so the title has to yield space
                      // to the fixed-width time label instead of overflowing.
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: _color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateTimeFormats.timelineTime(_eventMoment(event)),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (event.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.detail,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (event.dueAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.isOverdue
                          ? 'Overdue since ${DateTimeFormats.dateShort(event.dueAt!)}'
                          : 'Due ${DateTimeFormats.dateShort(event.dueAt!)}',
                      style: TextStyle(
                        color: event.isOverdue
                            ? AppColors.recallRed
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  _TimelineEventActions(event: event),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventActions extends ConsumerStatefulWidget {
  const _TimelineEventActions({required this.event});

  final TimelineEventEntity event;

  @override
  ConsumerState<_TimelineEventActions> createState() =>
      _TimelineEventActionsState();
}

class _TimelineEventActionsState extends ConsumerState<_TimelineEventActions> {
  bool _busy = false;
  String? _error;

  bool get _isProjectedTask =>
      widget.event.relatedId != null &&
      widget.event.id.startsWith('timeline-projected-task-');

  bool get _canComplete =>
      widget.event.status != TimelineEventStatus.completed &&
      widget.event.status != TimelineEventStatus.canceled &&
      (widget.event.type == TimelineEventType.task ||
          widget.event.type == TimelineEventType.deadline);

  bool get _canSkip =>
      widget.event.status != TimelineEventStatus.skipped &&
      widget.event.status != TimelineEventStatus.completed &&
      widget.event.status != TimelineEventStatus.canceled &&
      (widget.event.type == TimelineEventType.task ||
          widget.event.type == TimelineEventType.deadline);

  bool get _canMove =>
      !_isProjectedTask &&
      (widget.event.status == TimelineEventStatus.overdue ||
          widget.event.status == TimelineEventStatus.skipped);

  @override
  Widget build(BuildContext context) {
    if (!_canComplete && !_canSkip && !_canMove) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_canComplete)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_complete),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Complete'),
              ),
            if (_canSkip)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_skip),
                icon: const Icon(Icons.redo_rounded, size: 16),
                label: const Text('Skip'),
              ),
            if (_canMove)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_moveTomorrow),
                icon: const Icon(Icons.event_repeat_rounded, size: 16),
                label: Text(
                  widget.event.status == TimelineEventStatus.skipped
                      ? 'Recover Tomorrow'
                      : 'Move Tomorrow',
                ),
              ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.recallRed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstTimelineReview);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Timeline action failed. Refresh and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _complete() {
    final String? taskId = widget.event.relatedId;
    if (_isProjectedTask && taskId != null) {
      return ref.read(taskActionsProvider).completeTask(taskId);
    }
    return ref.read(timelineActionsProvider).complete(widget.event.id);
  }

  Future<void> _skip() {
    final String? taskId = widget.event.relatedId;
    if (_isProjectedTask && taskId != null) {
      return ref.read(taskActionsProvider).skipTask(taskId);
    }
    return ref.read(timelineActionsProvider).skip(widget.event.id);
  }

  Future<void> _moveTomorrow() {
    final DateTime nextDue = DateTime.now().add(const Duration(days: 1));
    return ref.read(timelineActionsProvider).recover(widget.event.id, nextDue);
  }
}

class _TimelineIntelligenceStrip extends StatelessWidget {
  const _TimelineIntelligenceStrip({
    required this.healthScore,
    required this.riskScore,
    required this.overdueCount,
    required this.upcomingCount,
    required this.milestoneCount,
    required this.riskCount,
    required this.recommendationCount,
    required this.nextDeadline,
  });

  final int healthScore;
  final int riskScore;
  final int overdueCount;
  final int upcomingCount;
  final int milestoneCount;
  final int riskCount;
  final int recommendationCount;
  final TimelineEventEntity? nextDeadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xAA07111F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(label: 'HEALTH', value: '$healthScore%'),
              _StatPill(label: 'RISK', value: '$riskScore%'),
              _StatPill(label: 'OVERDUE', value: '$overdueCount'),
              _StatPill(label: 'UPCOMING', value: '$upcomingCount'),
              _StatPill(label: 'MILESTONES', value: '$milestoneCount'),
              _StatPill(label: 'RISKS', value: '$riskCount'),
              _StatPill(label: 'RECS', value: '$recommendationCount'),
            ],
          ),
          if (nextDeadline != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next deadline: ${nextDeadline!.title} (${DateTimeFormats.dateShort(nextDeadline!.dueAt ?? nextDeadline!.timestamp)})',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WindowChips extends StatelessWidget {
  const _WindowChips({required this.selected, required this.onSelect});

  final _TimelineWindow selected;
  final ValueChanged<_TimelineWindow> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TimelineWindow.values
            .map(
              (_TimelineWindow value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: _windowLabel(value),
                  selected: selected == value,
                  onTap: () => onSelect(value),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final _TimelineFilter selected;
  final ValueChanged<_TimelineFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TimelineFilter.values
            .map(
              (_TimelineFilter value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: _filterLabel(value),
                  selected: selected == value,
                  onTap: () => onSelect(value),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonCyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.neonCyan.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.neonCyan : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

DateTime _eventMoment(TimelineEventEntity event) =>
    event.dueAt ?? event.timestamp;

bool _inWindow({
  required DateTime moment,
  required DateTime now,
  required _TimelineWindow window,
}) {
  switch (window) {
    case _TimelineWindow.today:
      return moment.year == now.year &&
          moment.month == now.month &&
          moment.day == now.day;
    case _TimelineWindow.week:
      final DateTime start = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1),
      );
      final DateTime end = start.add(const Duration(days: 7));
      return !moment.isBefore(start) && moment.isBefore(end);
    case _TimelineWindow.month:
      return moment.year == now.year && moment.month == now.month;
    case _TimelineWindow.year:
      return moment.year == now.year;
    case _TimelineWindow.all:
      return true;
  }
}

String _windowLabel(_TimelineWindow value) {
  return switch (value) {
    _TimelineWindow.today => 'Today',
    _TimelineWindow.week => 'Week',
    _TimelineWindow.month => 'Month',
    _TimelineWindow.year => 'Year',
    _TimelineWindow.all => 'All',
  };
}

String _filterLabel(_TimelineFilter value) {
  return switch (value) {
    _TimelineFilter.all => 'All',
    _TimelineFilter.overdue => 'Overdue',
    _TimelineFilter.upcoming => 'Upcoming',
    _TimelineFilter.milestones => 'Milestones',
    _TimelineFilter.risks => 'Risks',
    _TimelineFilter.recommendations => 'Recommendations',
  };
}

List<TimelineEventEntity> _buildProjectedEvents({
  required DateTime now,
  required List<Task> tasks,
  required List<GoalEntity> goals,
}) {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  for (final Task task in tasks) {
    final DateTime? due = task.scheduledFor ?? task.dueDate;
    if (due == null) {
      continue;
    }
    final bool overdue = due.isBefore(now);
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-task-${task.id}',
        type: TimelineEventType.deadline,
        title: task.title,
        detail: overdue
            ? 'Task deadline missed. Re-plan this task immediately.'
            : 'Task is scheduled and approaching deadline.',
        timestamp: now,
        status: overdue
            ? TimelineEventStatus.overdue
            : TimelineEventStatus.planned,
        dueAt: due,
        phase: 'task',
        relatedId: task.id,
      ),
    );
  }

  for (final GoalEntity goal in goals) {
    final DateTime? target = goal.targetDate;
    if (target == null) {
      continue;
    }
    final bool overdue = target.isBefore(now);
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-goal-${goal.id}',
        type: TimelineEventType.goal,
        title: goal.title,
        detail: overdue
            ? 'Goal target date has passed. Recovery plan needed.'
            : 'Goal target date is upcoming.',
        timestamp: now,
        status: overdue
            ? TimelineEventStatus.overdue
            : TimelineEventStatus.active,
        dueAt: target,
        phase: 'goal',
        relatedId: goal.id,
      ),
    );
  }

  return events;
}

List<TimelineEventEntity> _buildIntelligenceEvents({
  required DateTime now,
  required List<TimelineEventEntity> events,
}) {
  final int overdue = events
      .where((TimelineEventEntity event) => event.isOverdue)
      .length;
  final int upcoming = events
      .where((TimelineEventEntity event) => event.isUpcoming)
      .length;
  final int risk = overdue > 0 ? 1 : 0;
  final List<TimelineEventEntity> out = <TimelineEventEntity>[
    TimelineEventEntity(
      id: 'timeline-snapshot-${now.millisecondsSinceEpoch}',
      type: TimelineEventType.snapshot,
      title: 'Timeline Snapshot',
      detail:
          'Overdue: $overdue · Upcoming: $upcoming · Total events: ${events.length}',
      timestamp: now,
      status: TimelineEventStatus.info,
      phase: 'snapshot',
    ),
  ];
  if (risk > 0) {
    out.add(
      TimelineEventEntity(
        id: 'timeline-risk-${now.millisecondsSinceEpoch}',
        type: TimelineEventType.risk,
        title: 'Timeline Risk Detected',
        detail:
            'You have $overdue overdue items. Prioritize overdue resolution first.',
        timestamp: now,
        status: TimelineEventStatus.atRisk,
        phase: 'risk',
      ),
    );
    out.add(
      TimelineEventEntity(
        id: 'timeline-rec-${now.millisecondsSinceEpoch}',
        type: TimelineEventType.recommendation,
        title: 'Recommended Action',
        detail: 'Complete overdue tasks before adding new commitments.',
        timestamp: now,
        status: TimelineEventStatus.info,
        phase: 'recommendation',
      ),
    );
  }
  return out;
}

int _computeHealthScore({
  required int overdueCount,
  required int riskCount,
  required int milestoneCount,
  required int upcomingCount,
}) {
  final int penalty =
      (overdueCount * 12) + (riskCount * 10) + (upcomingCount > 6 ? 8 : 0);
  final int bonus = (milestoneCount * 3).clamp(0, 18);
  return (100 - penalty + bonus).clamp(0, 100);
}

TimelineEventEntity? _nearestUpcoming(
  List<TimelineEventEntity> events,
  DateTime now,
) {
  final List<TimelineEventEntity> candidates =
      events
          .where((TimelineEventEntity event) {
            final DateTime? due = event.dueAt;
            return due != null && due.isAfter(now) && !event.isOverdue;
          })
          .toList(growable: false)
        ..sort(
          (a, b) => (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp),
        );
  return candidates.isEmpty ? null : candidates.first;
}
