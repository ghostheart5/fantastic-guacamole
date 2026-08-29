import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/logic/timeline_projection.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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
  bool _refineExpanded = false;
  late final TextEditingController _searchController;
  AsyncValue<List<Task>> _tasksState = const AsyncData<List<Task>>(<Task>[]);
  ProviderSubscription<AsyncValue<List<Task>>>? _tasksSubscription;
  List<TimelineEventEntity>? _cachedCombined;
  int? _cachedCombinedKey;
  DateTime? _cachedCombinedDay;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AsyncValue<List<Task>> initial = ref.read(tasksProvider);
      _tasksSubscription = ref.listenManual<AsyncValue<List<Task>>>(
        tasksProvider,
        (AsyncValue<List<Task>>? previous, AsyncValue<List<Task>> next) {
          if (!mounted) return;
          setState(() => _tasksState = next);
        },
      );
      setState(() => _tasksState = initial);
    });
  }

  @override
  void dispose() {
    _tasksSubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<TimelineEventEntity> baseEvents = ref.watch(timelineProvider);
    final List<GoalEntity> goals = ref.watch(goalsProvider);
    final List<Task> tasks = _tasksState.asData?.value ?? const <Task>[];
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
      final List<TimelineEventEntity> projected = projectTimelineEvents(
        now: now,
        tasks: tasks,
        goals: goals,
      );
      combined = <TimelineEventEntity>[...baseEvents, ...projected]
        ..sort((a, b) => _eventMoment(b).compareTo(_eventMoment(a)));
      _cachedCombined = combined;
      _cachedCombinedKey = combinedKey;
      _cachedCombinedDay = today;
    }

    final List<TimelineEventEntity> windowEvents = combined
        .where((TimelineEventEntity event) {
          final DateTime moment = _eventMoment(event);
          return _inWindow(moment: moment, now: now, window: _window);
        })
        .toList(growable: false);

    final List<TimelineEventEntity> filtered = windowEvents
        .where((TimelineEventEntity event) {
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

    final int overdueCount = windowEvents
        .where((TimelineEventEntity event) => event.isOverdue)
        .length;
    final int upcomingCount = windowEvents
        .where((TimelineEventEntity event) => event.isUpcoming)
        .length;
    final int milestoneCount = windowEvents
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;
    final int riskCount = windowEvents
        .where((TimelineEventEntity event) => event.isRisk)
        .length;
    final int dueTodayCount = windowEvents.where((TimelineEventEntity event) {
      final DateTime? due = event.dueAt;
      return due != null &&
          due.year == now.year &&
          due.month == now.month &&
          due.day == now.day &&
          event.status != TimelineEventStatus.completed &&
          event.status != TimelineEventStatus.canceled;
    }).length;
    final TimelineEventEntity? nextDeadline = _nearestUpcoming(
      windowEvents,
      now,
    );

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
                  child: _TimelineHeader(
                    eventCount: windowEvents.length,
                    window: _window,
                    onBack: () => goToAppView(context, ref, AppView.nexus),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _TimelineFocusCard(
                    now: now,
                    dueTodayCount: dueTodayCount,
                    overdueCount: overdueCount,
                    upcomingCount: upcomingCount,
                    milestoneCount: milestoneCount,
                    riskCount: riskCount,
                    nextDeadline: nextDeadline,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _TimelineControls(
                    window: _window,
                    filter: _filter,
                    searchController: _searchController,
                    expanded: _refineExpanded,
                    visibleCount: filtered.length,
                    onWindowChanged: (_TimelineWindow value) =>
                        setState(() => _window = value),
                    onFilterChanged: (_TimelineFilter value) =>
                        setState(() => _filter = value),
                    onQueryChanged: (String value) =>
                        setState(() => _query = value),
                    onToggleExpanded: () =>
                        setState(() => _refineExpanded = !_refineExpanded),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TimelineEmptyState(
                    isRefined:
                        _filter != _TimelineFilter.all || _query.isNotEmpty,
                    onReset: () => setState(() {
                      _filter = _TimelineFilter.all;
                      _query = '';
                      _searchController.clear();
                    }),
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
                          _TimelineDayHeader(
                            label: day,
                            eventCount: dayEvents.length,
                          ),
                          ...List<Widget>.generate(
                            dayEvents.length,
                            (int eventIndex) => _TimelineEventTile(
                              event: dayEvents[eventIndex],
                              tutorialTarget:
                                  dayEvents[eventIndex].id == tutorialEventId,
                              emphasized: i == 0 && eventIndex == 0,
                              isLast: eventIndex == dayEvents.length - 1,
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
  const _TimelineEventTile({
    required this.event,
    required this.tutorialTarget,
    required this.emphasized,
    required this.isLast,
  });

  final TimelineEventEntity event;
  final bool tutorialTarget;
  final bool emphasized;
  final bool isLast;

  bool get _isTaskAdded =>
      event.title.trim().toLowerCase() == 'task added' &&
      RegExp(
        r'\s+added to trajectory\.?$',
        caseSensitive: false,
      ).hasMatch(event.detail);

  TimelineEventType get _visualType =>
      event.phase?.trim().toLowerCase() == 'task' || _isTaskAdded
      ? TimelineEventType.task
      : event.type;

  String get _visualLabel =>
      _visualType == TimelineEventType.task ? 'Task' : event.shortLabel;

  Color get _color {
    switch (_visualType) {
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
    switch (_visualType) {
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

  String get _displayTitle {
    if (!_isTaskAdded) return event.title;
    return event.detail.replaceFirst(
      RegExp(r'\s+added to trajectory\.?$', caseSensitive: false),
      '',
    );
  }

  String get _displayDetail =>
      _isTaskAdded ? 'Added to your trajectory' : event.detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: tutorialTarget ? FirstRunTutorialTargets.timelineEvidence : null,
      padding: const EdgeInsets.only(bottom: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 38,
              child: Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  if (!isLast)
                    Positioned(
                      top: 32,
                      bottom: -6,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              _color.withValues(alpha: .42),
                              _color.withValues(alpha: .08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF081325),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.withValues(alpha: emphasized ? .9 : .5),
                        width: emphasized ? 2 : 1,
                      ),
                      boxShadow: emphasized
                          ? <BoxShadow>[
                              BoxShadow(
                                color: _color.withValues(alpha: .28),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(_icon, color: _color, size: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(emphasized ? 16 : 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: emphasized
                        ? <Color>[
                            _color.withValues(alpha: .18),
                            const Color(0xE6091428),
                          ]
                        : const <Color>[Color(0xE6081223), Color(0xD9050D1A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _color.withValues(alpha: emphasized ? .48 : .2),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _visualLabel.toUpperCase(),
                            style: TextStyle(
                              color: _color,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateTimeFormats.timelineTime(_eventMoment(event)),
                          style: const TextStyle(
                            color: Color(0xFF8B99B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _displayTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: emphasized ? 17 : 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_displayDetail.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        _displayDetail,
                        style: const TextStyle(
                          color: Color(0xFFB4C0DA),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: emphasized ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (event.dueAt != null) ...<Widget>[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (event.isOverdue
                                      ? AppColors.recallRed
                                      : AppColors.neonCyan)
                                  .withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.isOverdue
                              ? 'OVERDUE SINCE ${DateTimeFormats.dateShort(event.dueAt!)}'
                              : 'DUE ${DateTimeFormats.dateShort(event.dueAt!)}',
                          style: TextStyle(
                            color: event.isOverdue
                                ? AppColors.recallRed
                                : AppColors.neonCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
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
    if (!_canComplete && !_canSkip && !_canMove && !_isProjectedTask) {
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
            if (_isProjectedTask)
              OutlinedButton.icon(
                onPressed: _busy ? null : _editTask,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            if (_isProjectedTask)
              OutlinedButton.icon(
                onPressed: _busy ? null : _confirmDeleteTask,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.recallRed,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
              ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Task action in progress',
            liveRegion: true,
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            label: _error,
            liveRegion: true,
            excludeSemantics: true,
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.recallRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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

  Future<void> _editTask() async {
    if (_busy) return;
    final String? taskId = widget.event.relatedId;
    if (taskId == null) return;

    String draftTitle = widget.event.title;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final String? nextTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Edit task'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('timeline-task-title-field'),
            initialValue: draftTitle,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Task title'),
            validator: (String? value) => value == null || value.trim().isEmpty
                ? 'Enter a task title.'
                : null,
            onChanged: (String value) => draftTitle = value,
            onFieldSubmitted: (String value) => _submitEdit(
              dialogContext: dialogContext,
              formKey: formKey,
              title: value,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitEdit(
              dialogContext: dialogContext,
              formKey: formKey,
              title: draftTitle,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (nextTitle == null || !mounted) return;

    await _runManagementAction(
      action: () => ref
          .read(taskActionsProvider)
          .updateTask(id: taskId, title: nextTitle),
      successMessage: 'Task updated.',
      errorMessage: 'Task could not be updated. Refresh and try again.',
    );
  }

  void _submitEdit({
    required BuildContext dialogContext,
    required GlobalKey<FormState> formKey,
    required String title,
  }) {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(dialogContext).pop(title.trim());
  }

  Future<void> _confirmDeleteTask() async {
    if (_busy) return;
    final String? taskId = widget.event.relatedId;
    if (taskId == null) return;

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text(
              '"${widget.event.title}" will be permanently deleted. '
              'This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.recallRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete task'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    await _runManagementAction(
      action: () => ref.read(taskActionsProvider).deleteTask(taskId),
      successMessage: 'Task deleted.',
      errorMessage: 'Task could not be deleted. Refresh and try again.',
    );
  }

  Future<void> _runManagementAction({
    required Future<void> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage;
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

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.eventCount,
    required this.window,
    required this.onBack,
  });

  final int eventCount;
  final _TimelineWindow window;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TemporalScreenHeader(
      title: 'TIMELINE',
      subtitle: 'Your time, connected into one readable stream.',
      eyebrow: '${_windowLabel(window)} view',
      accent: AppColors.neonViolet,
      onBack: onBack,
      backTooltip: 'Back to Nexus',
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '$eventCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'EVENTS',
            style: TextStyle(
              color: Color(0xFF8B99B8),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineFocusCard extends StatelessWidget {
  const _TimelineFocusCard({
    required this.now,
    required this.dueTodayCount,
    required this.overdueCount,
    required this.upcomingCount,
    required this.milestoneCount,
    required this.riskCount,
    required this.nextDeadline,
  });

  final DateTime now;
  final int dueTodayCount;
  final int overdueCount;
  final int upcomingCount;
  final int milestoneCount;
  final int riskCount;
  final TimelineEventEntity? nextDeadline;

  @override
  Widget build(BuildContext context) {
    final bool needsAttention = overdueCount > 0 || riskCount > 0;
    final Color accent = needsAttention
        ? AppColors.recallRed
        : AppColors.neonCyan;
    final String headline = overdueCount > 0
        ? '$overdueCount overdue ${overdueCount == 1 ? 'item' : 'items'}'
        : dueTodayCount > 0
        ? '$dueTodayCount due today'
        : nextDeadline != null
        ? 'Next commitment is mapped'
        : 'Nothing needs action now';
    final String supporting = nextDeadline != null
        ? '${nextDeadline!.title} is due ${DateTimeFormats.dateShort(nextDeadline!.dueAt ?? nextDeadline!.timestamp)}.'
        : 'Your recent activity remains available in the chronology below.';

    return TemporalGlassSurface(
      accent: accent,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 62,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xA9081427),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: .42)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${now.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _monthShort(now.month),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      needsAttention ? 'NEEDS ATTENTION' : 'CURRENT PRIORITY',
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      supporting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB8C4DE),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _TimelineMetric(
                  label: 'DUE TODAY',
                  value: '$dueTodayCount',
                  accent: AppColors.neonCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimelineMetric(
                  label: 'NEXT 7 DAYS',
                  value: '$upcomingCount',
                  accent: AppColors.neonViolet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimelineMetric(
                  label: overdueCount > 0 ? 'OVERDUE' : 'MILESTONES',
                  value: '${overdueCount > 0 ? overdueCount : milestoneCount}',
                  accent: overdueCount > 0
                      ? AppColors.recallRed
                      : AppColors.memoryAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineMetric extends StatelessWidget {
  const _TimelineMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8E9BBA),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({
    required this.window,
    required this.filter,
    required this.searchController,
    required this.expanded,
    required this.visibleCount,
    required this.onWindowChanged,
    required this.onFilterChanged,
    required this.onQueryChanged,
    required this.onToggleExpanded,
  });

  final _TimelineWindow window;
  final _TimelineFilter filter;
  final TextEditingController searchController;
  final bool expanded;
  final int visibleCount;
  final ValueChanged<_TimelineWindow> onWindowChanged;
  final ValueChanged<_TimelineFilter> onFilterChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final bool isRefined =
        filter != _TimelineFilter.all ||
        searchController.text.trim().isNotEmpty;

    return TemporalGlassSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: _TimelineWindow.values
                .map(
                  (_TimelineWindow value) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: value == _TimelineWindow.all ? 0 : 5,
                      ),
                      child: _TimelineRangeButton(
                        label: _windowLabel(value),
                        selected: window == value,
                        onTap: () => onWindowChanged(value),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_motion_rounded,
                color: AppColors.neonViolet,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$visibleCount ${visibleCount == 1 ? 'event' : 'events'} shown',
                  style: const TextStyle(
                    color: Color(0xFFB8C4DE),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(
                  expanded ? Icons.expand_less_rounded : Icons.tune_rounded,
                  size: 17,
                ),
                label: Text(isRefined ? 'Refined' : 'Find & filter'),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Find an event, task, goal, or note',
                      hintStyle: const TextStyle(color: Color(0xFF74809A)),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: .18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<_TimelineFilter>(
                    initialValue: filter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Activity type',
                      prefixIcon: const Icon(Icons.filter_alt_outlined),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: .18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _TimelineFilter.values
                        .map(
                          (_TimelineFilter value) => DropdownMenuItem(
                            value: value,
                            child: Text(_filterLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (_TimelineFilter? value) {
                      if (value != null) onFilterChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRangeButton extends StatelessWidget {
  const _TimelineRangeButton({
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
      semanticLabel: 'Show $label timeline',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonCyan.withValues(alpha: .18)
              : Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.neonCyan.withValues(alpha: .55)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: selected ? AppColors.neonCyan : const Color(0xFF8E9AB5),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TimelineDayHeader extends StatelessWidget {
  const _TimelineDayHeader({required this.label, required this.eventCount});

  final String label;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 0, 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.neonCyan,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: AppColors.neonCyan, blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                letterSpacing: 0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$eventCount ${eventCount == 1 ? 'EVENT' : 'EVENTS'}',
            style: const TextStyle(
              color: Color(0xFF77839E),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState({required this.isRefined, required this.onReset});

  final bool isRefined;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.neonViolet.withValues(alpha: .1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neonViolet.withValues(alpha: .3),
                ),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: AppColors.neonViolet,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRefined ? 'No matching moments' : 'This part of time is clear',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              isRefined
                  ? 'Change the search or activity filter to reveal more of your chronology.'
                  : 'New tasks, goals, notes, and completed work will connect here as they happen.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF93A0BA),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (isRefined) ...<Widget>[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset search and filter'),
              ),
            ],
          ],
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

String _monthShort(int month) => const <String>[
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][month - 1];

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
