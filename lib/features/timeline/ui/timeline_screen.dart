import 'dart:async';

import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_lifecycle_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_event_bridge.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/layout/responsive_layout.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _TimelineWindow { today, week, month, year, all }

enum _TimelineFocus {
  all,
  current,
  completed,
  overdue,
  upcoming,
  milestones,
  risks,
  recommendations,
  history,
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  _TimelineWindow _window = _TimelineWindow.week;
  _TimelineFocus _focus = _TimelineFocus.all;
  String _query = '';
  bool _showMoreFilters = false;
  Timer? _searchDebounce;

  Future<void> _markTimelineViewedForSetup() async {
    if (!ref.read(creatorFirstItemCreatedProvider) ||
        ref.read(timelineFirstActionCompletedProvider)) {
      return;
    }
    final AuthSessionBoundary boundary = ref.read(authSessionBoundaryProvider);
    final AuthSessionLifecycleCoordinator lifecycle = ref.read(
      authSessionLifecycleProvider,
    );
    final int generation = boundary.generation;
    final String? userId = boundary.userId;
    if (!lifecycle.isCurrent(generation, userId)) {
      return;
    }
    final notifier = ref.read(timelineFirstActionCompletedProvider.notifier);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted || !lifecycle.isCurrent(generation, userId)) {
        return;
      }
      notifier.set(true);
      final String key = (userId == null || userId.trim().isEmpty)
          ? timelineFirstActionCompletedStorageKey
          : timelineFirstActionCompletedStorageKeyForUser(userId.trim());
      await prefs.setBool(key, true);
    } on Object {
      // Do not block first-setup completion if local persistence is unavailable.
      if (mounted && lifecycle.isCurrent(generation, userId)) {
        notifier.set(true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_markTimelineViewedForSetup());
      ref.read(missionEventBridgeProvider).reportTimelineOpened();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<TimelineEventEntity> baseEvents = ref.watch(timelineProvider);
    final List<TimelineEventEntity> timelineCompletedEvents = ref.watch(
      timelineCompletedEventsProvider,
    );
    final List<TimelineEventEntity> todayTimelineEvents = ref.watch(
      timelineTodayProvider,
    );
    final List<GoalEntity> goals = ref.watch(goalsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final List<Task> tasks = tasksAsync.asData?.value ?? const <Task>[];
    final bool hasCreatedFirstItem = ref.watch(creatorFirstItemCreatedProvider);
    final bool hasCompletedTimelineFirstAction = ref.watch(
      timelineFirstActionCompletedProvider,
    );
    final bool showFirstActionUnlockBanner =
        hasCreatedFirstItem && !hasCompletedTimelineFirstAction;
    final DateTime now = DateTime.now();
    final Map<String, Task> tasksById = <String, Task>{
      for (final Task task in tasks) task.id: task,
    };
    final List<TimelineEventEntity> visibleBaseEvents = baseEvents
        .map(
          (TimelineEventEntity event) =>
              _withCurrentTaskSchedule(event, tasksById),
        )
        .toList(growable: false);
    final Set<String> linkedTaskIds = visibleBaseEvents
        .where(
          (TimelineEventEntity event) =>
              event.type == TimelineEventType.task ||
              event.type == TimelineEventType.habit ||
              (event.type == TimelineEventType.deadline &&
                  event.phase == 'task'),
        )
        .map((TimelineEventEntity event) => event.relatedId?.trim())
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet();

    final List<TimelineEventEntity> projected = _buildProjectedEvents(
      now: now,
      tasks: tasks,
      goals: goals,
      existingRelatedIds: linkedTaskIds,
    );
    final List<TimelineEventEntity> combined = <TimelineEventEntity>[
      ...visibleBaseEvents,
      ...projected,
      ..._buildIntelligenceEvents(
        now: now,
        events: <TimelineEventEntity>[...baseEvents, ...projected],
      ),
    ]..sort((a, b) => _eventMoment(b).compareTo(_eventMoment(a)));

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
          final bool inFocus = switch (_focus) {
            _TimelineFocus.all => true,
            _TimelineFocus.current =>
              event.isUpcoming ||
                  (event.status != TimelineEventStatus.completed &&
                      !event.isOverdue),
            _TimelineFocus.completed =>
              event.status == TimelineEventStatus.completed,
            _TimelineFocus.overdue => event.isOverdue,
            _TimelineFocus.upcoming => event.isUpcoming,
            _TimelineFocus.milestones => event.isMilestone,
            _TimelineFocus.risks => event.isRisk,
            _TimelineFocus.recommendations => event.isRecommendation,
            _TimelineFocus.history => _eventMoment(event).isBefore(now),
          };
          if (!inFocus) {
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
    final bool hasActionableTimelineItem = filtered.any(
      _isActionableTimelineEvent,
    );

    final Map<DateTime, List<TimelineEventEntity>> grouped =
        <DateTime, List<TimelineEventEntity>>{};
    for (final TimelineEventEntity event in filtered) {
      final DateTime day = _normalizedDay(_eventMoment(event));
      grouped.putIfAbsent(day, () => <TimelineEventEntity>[]).add(event);
    }
    final List<DateTime> days = grouped.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));

    final int overdueCount = filtered
        .where((TimelineEventEntity event) => event.isOverdue)
        .length;
    final int upcomingCount = filtered
        .where((TimelineEventEntity event) => event.isUpcoming)
        .length;

    return Semantics(
      identifier: 'screen-timeline',
      container: true,
      child: AnimatedSystemBackground(
        backgroundAssetPath: AppAssets.bgProgression,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ResponsiveContent(
              maxWidth: 1120,
              child: CustomScrollView(
                slivers: <Widget>[
                  if (tasksAsync.isLoading && !tasksAsync.hasValue)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (tasksAsync.hasError && !tasksAsync.hasValue)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Task projections are unavailable. Timeline events are still shown.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Retry task projections',
                              onPressed: () => ref.invalidate(tasksProvider),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          SmartPressable(
                            onTap: () =>
                                ref.read(appFlowProvider.notifier).toNexus(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.neonViolet.withValues(
                                  alpha: 0.08,
                                ),
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
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        AppColors.neonViolet,
                                        AppColors.neonCyan,
                                      ],
                                    ).createShader(bounds),
                                child: const Text(
                                  'Timeline',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Text(
                                'Review your scheduled items and progress',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 0.5,
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
                  if (showFirstActionUnlockBanner)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _TimelineUnlockBanner(
                          hasActionableTimelineItem: hasActionableTimelineItem,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _TodaySummaryCard(
                        todayCount: todayTimelineEvents.length,
                        upcomingCount: upcomingCount,
                        overdueCount: overdueCount,
                        completedCount: timelineCompletedEvents.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: TextField(
                        onChanged: (String value) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 180),
                            () {
                              if (mounted) setState(() => _query = value);
                            },
                          );
                        },
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
                              color: AppColors.neonViolet.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.neonCyan,
                            ),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Window',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SmartPressable(
                            onTap: () => setState(
                              () => _showMoreFilters = !_showMoreFilters,
                            ),
                            child: Text(
                              _showMoreFilters
                                  ? 'Hide filters'
                                  : 'More filters',
                              style: const TextStyle(
                                color: AppColors.neonCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showMoreFilters) ...<Widget>[
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: _FocusChips(
                          selected: _focus,
                          onSelect: (_TimelineFocus value) =>
                              setState(() => _focus = value),
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xAA091427),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Text(
                            'No items match this view.\n\nTry another window, clear filters, or create something in Creator.\n\nCreate a task, routine, goal, or note in Creator, then schedule it to see it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((ctx, i) {
                          final DateTime day = days[i];
                          final List<TimelineEventEntity> dayEvents =
                              grouped[day]!;
                          final String dayLabel = _timelineDayLabel(day, now);
                          final String itemLabel = dayEvents.length == 1
                              ? '1 item'
                              : '${dayEvents.length} items';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      dayLabel,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      itemLabel,
                                      style: const TextStyle(
                                        color: Colors.white30,
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...dayEvents.map(
                                (TimelineEventEntity event) =>
                                    _TimelineEventTile(event: event),
                              ),
                            ],
                          );
                        }, childCount: days.length),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _TimelineHelperPanel(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineEventTile extends ConsumerStatefulWidget {
  const _TimelineEventTile({required this.event});

  final TimelineEventEntity event;

  @override
  ConsumerState<_TimelineEventTile> createState() => _TimelineEventTileState();
}

class _TimelineEventTileState extends ConsumerState<_TimelineEventTile> {
  bool _isRunningAction = false;
  TimelineEventStatus? _localStatusOverride;
  DateTime? _localDueAt;
  String? _lastActionLabel;

  TimelineEventEntity get event => widget.event;

  TimelineEventStatus get _effectiveStatus =>
      _localStatusOverride ?? event.status;

  bool get _isCompleted => _effectiveStatus == TimelineEventStatus.completed;

  bool get _isOverdue => _effectiveStatus == TimelineEventStatus.overdue;

  DateTime? get _effectiveDueAt => _localDueAt ?? event.dueAt;

  DateTime get _effectiveMoment => _effectiveDueAt ?? event.timestamp;

  String get _typeLabel {
    if (event.type == TimelineEventType.deadline && event.phase == 'task') {
      return 'Scheduled task';
    }
    if (event.type == TimelineEventType.task && event.dueAt != null) {
      return 'Scheduled task';
    }
    return switch (event.type) {
      TimelineEventType.task => 'Task',
      TimelineEventType.goal => 'Goal',
      TimelineEventType.habit => 'Habit',
      TimelineEventType.habitCompleted => 'Habit Completed',
      TimelineEventType.habitSkipped => 'Habit Skipped',
      TimelineEventType.project => 'Project',
      TimelineEventType.milestone => 'Milestone',
      TimelineEventType.deadline => 'Deadline',
      TimelineEventType.forecast => 'Forecast',
      TimelineEventType.snapshot =>
        event.phase == 'snapshot' ? 'Snapshot' : 'Memory',
      TimelineEventType.risk => 'Risk',
      TimelineEventType.recommendation => 'Recommendation',
      TimelineEventType.reflection => 'Reflection',
      TimelineEventType.levelUp => 'Level Up',
      TimelineEventType.streak => 'Streak',
      TimelineEventType.goalComplete => 'Goal Complete',
      TimelineEventType.noteCreated => 'Note Created',
      TimelineEventType.noteUpdated => 'Note Updated',
      TimelineEventType.noteArchived => 'Note Archived',
      TimelineEventType.noteDeleted => 'Note Deleted',
    };
  }

  bool get _canExecuteTaskAction {
    return _isActionableTimelineEvent(event) && !_isCompleted;
  }

  Future<void> _runTaskAction(
    Future<void> Function() action,
    String successMessage,
    TimelineEventStatus nextStatus,
    String actionLabel,
    DateTime? nextDueAt,
  ) async {
    if (_isRunningAction || !_canExecuteTaskAction) {
      return;
    }
    setState(() => _isRunningAction = true);
    try {
      await action();
      if (mounted) {
        setState(() {
          _localStatusOverride = nextStatus;
          _localDueAt = nextDueAt;
          _lastActionLabel = actionLabel;
        });
      }
      await ref.read(missionEventBridgeProvider).reportTimelineOpened();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(successMessage),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to update this item right now.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isRunningAction = false);
      }
    }
  }

  Future<void> _completeTask() async {
    final String id = event.relatedId!.trim();
    await _runTaskAction(
      () {
        return ref
            .read(taskActionsProvider)
            .completeTask(id, actionSource: 'timeline');
      },
      'Marked complete.',
      TimelineEventStatus.completed,
      'Completed',
      null,
    );
  }

  Future<void> _markNotCompleted() async {
    final String id = event.relatedId!.trim();
    await _runTaskAction(
      () {
        // "Not completed" keeps the item active by moving it forward.
        return ref
            .read(taskActionsProvider)
            .delayTask(
              id,
              by: const Duration(days: 1),
              actionSource: 'timeline',
              delayReason: 'not_completed',
            );
      },
      'Marked not completed and moved to tomorrow.',
      TimelineEventStatus.active,
      'Not completed',
      _rescheduledDue(const Duration(days: 1)),
    );
  }

  Future<void> _skipTask() async {
    final String id = event.relatedId!.trim();
    await _runTaskAction(
      () {
        return ref
            .read(taskActionsProvider)
            .skipTask(id, actionSource: 'timeline');
      },
      'Item skipped.',
      TimelineEventStatus.planned,
      'Skipped',
      null,
    );
  }

  Future<void> _rescheduleTask(Duration by) async {
    final String id = event.relatedId!.trim();
    await _runTaskAction(
      () {
        return ref
            .read(taskActionsProvider)
            .delayTask(id, by: by, actionSource: 'timeline');
      },
      'Item rescheduled.',
      TimelineEventStatus.planned,
      'Rescheduled',
      _rescheduledDue(by),
    );
  }

  DateTime _rescheduledDue(Duration by) {
    final DateTime now = DateTime.now();
    final DateTime candidate = (_effectiveDueAt ?? now).add(by);
    return candidate.isBefore(now) ? now.add(by) : candidate;
  }

  Widget _buildStatusFeedback() {
    if (_isRunningAction) {
      return const _TimelineStatusBadge(
        label: 'Updating...',
        color: AppColors.neonCyan,
      );
    }
    if (_lastActionLabel == null) {
      return const SizedBox.shrink();
    }

    final Color statusColor = switch (_effectiveStatus) {
      TimelineEventStatus.completed => const Color(0xFF4CAF50),
      TimelineEventStatus.overdue => AppColors.recallRed,
      TimelineEventStatus.atRisk => AppColors.recallRed,
      TimelineEventStatus.active => AppColors.neonCyan,
      TimelineEventStatus.planned => AppColors.neonViolet,
      TimelineEventStatus.info => Colors.white70,
    };

    return _TimelineStatusBadge(label: _lastActionLabel!, color: statusColor);
  }

  Widget _buildActionRow() {
    if (!_canExecuteTaskAction) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _TimelineActionChip(
              label: 'Complete',
              icon: Icons.check_circle_outline,
              enabled: !_isRunningAction,
              onTap: _completeTask,
            ),
            _TimelineActionChip(
              label: 'Not Completed',
              icon: Icons.remove_circle_outline,
              enabled: !_isRunningAction,
              onTap: _markNotCompleted,
            ),
            _TimelineActionChip(
              label: 'Skip',
              icon: Icons.skip_next_rounded,
              enabled: !_isRunningAction,
              onTap: _skipTask,
            ),
            PopupMenuButton<Duration>(
              enabled: !_isRunningAction,
              onSelected: _rescheduleTask,
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<Duration>>[
                  PopupMenuItem<Duration>(
                    value: Duration(hours: 2),
                    child: Text('Reschedule +2h'),
                  ),
                  PopupMenuItem<Duration>(
                    value: Duration(days: 1),
                    child: Text('Reschedule +1d'),
                  ),
                  PopupMenuItem<Duration>(
                    value: Duration(days: 7),
                    child: Text('Reschedule +1w'),
                  ),
                ];
              },
              child: _TimelineActionChip(
                label: 'Reschedule',
                icon: Icons.schedule,
                enabled: !_isRunningAction,
                onTap: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

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
      case TimelineEventType.habitCompleted:
        return const Color(0xFF4CAF50);
      case TimelineEventType.habitSkipped:
        return Colors.blueGrey;
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
        return const Color(0xFF7AF7C4);
      case TimelineEventType.noteUpdated:
        return const Color(0xFF59C8FF);
      case TimelineEventType.noteArchived:
        return Colors.blueGrey;
      case TimelineEventType.noteDeleted:
        return AppColors.recallRed;
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
      case TimelineEventType.habitCompleted:
        return Icons.check_circle_rounded;
      case TimelineEventType.habitSkipped:
        return Icons.remove_circle_outline_rounded;
      case TimelineEventType.project:
        return Icons.account_tree_rounded;
      case TimelineEventType.milestone:
        return Icons.emoji_events_rounded;
      case TimelineEventType.deadline:
        return Icons.schedule_rounded;
      case TimelineEventType.forecast:
        return Icons.insights_rounded;
      case TimelineEventType.snapshot:
        return Icons.camera_alt_outlined;
      case TimelineEventType.risk:
        return Icons.warning_amber_rounded;
      case TimelineEventType.recommendation:
        return Icons.tips_and_updates_rounded;
      case TimelineEventType.noteCreated:
        return Icons.note_add_outlined;
      case TimelineEventType.noteUpdated:
        return Icons.edit_note_rounded;
      case TimelineEventType.noteArchived:
        return Icons.archive_outlined;
      case TimelineEventType.noteDeleted:
        return Icons.delete_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      Text(
                        event.title,
                        style: TextStyle(
                          color: _color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        DateTimeFormats.timelineTime(_effectiveMoment),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildStatusFeedback(),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        _typeLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
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
                  if (_effectiveDueAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _isOverdue
                          ? 'Overdue since ${DateTimeFormats.dateShort(_effectiveDueAt!)}'
                          : 'Due ${DateTimeFormats.dateShort(_effectiveDueAt!)}',
                      style: TextStyle(
                        color: _isOverdue
                            ? AppColors.recallRed
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  _buildActionRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineActionChip extends StatelessWidget {
  const _TimelineActionChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback tapHandler = enabled && onTap != null ? onTap! : () {};
    return SmartPressable(
      onTap: tapHandler,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.6,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 13, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineUnlockBanner extends StatelessWidget {
  const _TimelineUnlockBanner({required this.hasActionableTimelineItem});

  final bool hasActionableTimelineItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            AppColors.neonCyan.withValues(alpha: 0.14),
            AppColors.neonViolet.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonCyan.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: AppColors.neonCyan,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your item is on Timeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review what you created here. Tasks can be completed, skipped, or rescheduled when those actions are available.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.todayCount,
    required this.upcomingCount,
    required this.overdueCount,
    required this.completedCount,
  });

  final int todayCount;
  final int upcomingCount;
  final int overdueCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xAA091427),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Today at a glance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _SummaryPill(label: 'Today', value: '$todayCount planned'),
              _SummaryPill(label: 'Upcoming', value: '$upcomingCount'),
              _SummaryPill(label: 'Overdue', value: '$overdueCount'),
              _SummaryPill(label: 'Completed', value: '$completedCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineHelperPanel extends ConsumerWidget {
  const _TimelineHelperPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x8A081225),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Need help with Timeline?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Timeline shows scheduled tasks, routines, goals, and notes. Use it to review what is planned, what is overdue, and what has been completed.',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _InlineNavChip(
                label: 'Open Creator',
                onTap: () => ref.read(appFlowProvider.notifier).toCreator(),
              ),
              _InlineNavChip(
                label: 'Open Smart Planner',
                onTap: () => ref.read(appFlowProvider.notifier).toSmartCoach(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineNavChip extends StatelessWidget {
  const _InlineNavChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.neonViolet.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.neonViolet.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

bool _isActionableTimelineEvent(TimelineEventEntity event) {
  final String? relatedId = event.relatedId;
  if (relatedId == null || relatedId.trim().isEmpty) {
    return false;
  }

  return event.type == TimelineEventType.deadline ||
      event.type == TimelineEventType.task ||
      event.phase == 'task';
}

class _TimelineStatusBadge extends StatelessWidget {
  const _TimelineStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
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

class _FocusChips extends StatelessWidget {
  const _FocusChips({required this.selected, required this.onSelect});

  final _TimelineFocus selected;
  final ValueChanged<_TimelineFocus> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TimelineFocus.values
            .map(
              (_TimelineFocus value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: _focusLabel(value),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

TimelineEventEntity _withCurrentTaskSchedule(
  TimelineEventEntity event,
  Map<String, Task> tasksById,
) {
  if (!_isTaskTimelineLink(event)) {
    return event;
  }
  final Task? task = tasksById[event.relatedId?.trim()];
  if (task == null || task.scheduledFor == event.dueAt) {
    return event;
  }
  return TimelineEventEntity(
    id: event.id,
    type: event.type,
    title: event.title,
    detail: event.detail,
    timestamp: event.timestamp,
    status: event.status,
    dueAt: task.scheduledFor,
    phase: event.phase,
    relatedId: event.relatedId,
  );
}

bool _isTaskTimelineLink(TimelineEventEntity event) {
  return event.type == TimelineEventType.task ||
      event.type == TimelineEventType.habit ||
      (event.type == TimelineEventType.deadline && event.phase == 'task');
}

DateTime _normalizedDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _timelineDayLabel(DateTime day, DateTime now) {
  final DateTime today = _normalizedDay(now);
  final DateTime yesterday = today.subtract(const Duration(days: 1));
  final DateTime tomorrow = today.add(const Duration(days: 1));

  if (_isSameDay(day, today)) {
    return 'Today';
  }
  if (_isSameDay(day, yesterday)) {
    return 'Yesterday';
  }
  if (_isSameDay(day, tomorrow)) {
    return 'Tomorrow';
  }

  return DateTimeFormats.timelineDay(day);
}

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

String _focusLabel(_TimelineFocus value) {
  return switch (value) {
    _TimelineFocus.all => 'All',
    _TimelineFocus.current => 'Current',
    _TimelineFocus.completed => 'Completed',
    _TimelineFocus.overdue => 'Overdue',
    _TimelineFocus.upcoming => 'Upcoming',
    _TimelineFocus.milestones => 'Milestones',
    _TimelineFocus.risks => 'Risks',
    _TimelineFocus.recommendations => 'Recommendations',
    _TimelineFocus.history => 'History',
  };
}

List<TimelineEventEntity> _buildProjectedEvents({
  required DateTime now,
  required List<Task> tasks,
  required List<GoalEntity> goals,
  required Set<String> existingRelatedIds,
}) {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  for (final Task task in tasks) {
    if (existingRelatedIds.contains(task.id)) {
      continue;
    }
    final DateTime? due = task.scheduledFor;
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
          'Overdue: $overdue | Upcoming: $upcoming | Total events: ${events.length}',
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
