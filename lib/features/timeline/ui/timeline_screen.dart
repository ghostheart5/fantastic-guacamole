import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/logic/timeline_projection.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
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

part 'timeline_screen.widgets.dart';

enum _TimelineWindow { today, week, month, year, all }

enum _TimelineFilter {
  all,
  overdue,
  upcoming,
  milestones,
  risks,
  recommendations,
}

enum _TimelineSourceIssue { persistence, taskLoading, taskError }

@immutable
final class _TimelineSafetyCopy {
  const _TimelineSafetyCopy({required this.isSpanish});

  factory _TimelineSafetyCopy.of(BuildContext context) => _TimelineSafetyCopy(
    isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
  );

  final bool isSpanish;

  String get repairTitle => isSpanish
      ? '¿Reparar la actividad guardada de la Línea de Tiempo?'
      : 'Repair saved Timeline activity?';
  String get repairBody => isSpanish
      ? 'ChronoSpark conservará primero los datos originales que no se pueden leer y luego mantendrá cada registro de actividad válido que pueda recuperar.'
      : 'ChronoSpark will preserve the original unreadable data first, then keep every valid activity record it can read.';
  String get cancel => isSpanish ? 'Cancelar' : 'Cancel';
  String get preserveAndRepair =>
      isSpanish ? 'Conservar y reparar' : 'Preserve and repair';
  String get repaired => isSpanish
      ? 'La actividad de la Línea de Tiempo se reparó. Se conservaron los datos originales que no se podían leer.'
      : 'Timeline activity repaired. The original unreadable data was preserved.';
  String get notChanged => isSpanish
      ? 'La actividad de la Línea de Tiempo no cambió porque no se pudo conservar su copia de recuperación.'
      : 'Timeline activity was not changed because its recovery copy could not be preserved.';
}

class _TaskEditDraft {
  const _TaskEditDraft({
    required this.title,
    required this.estimatedDuration,
    required this.dueDate,
    required this.goalId,
  });

  final String title;
  final Duration? estimatedDuration;
  final DateTime? dueDate;
  final String? goalId;
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
  AsyncValue<List<Task>> _tasksState = const AsyncLoading<List<Task>>();
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
    final bool timelinePersistenceCorrupted = ref.watch(
      timelinePersistenceCorruptedProvider,
    );
    final List<GoalEntity> goals = ref.watch(goalsProvider);
    final Set<String> expectedTutorialTaskIds =
        ref
            .watch(adaptiveGuidanceProvider)
            .asData
            ?.value
            .expectedFirstRunCreatorTaskIds ??
        const <String>{};
    final List<Task> tasks = _tasksState.asData?.value ?? const <Task>[];
    final bool tasksLoading = _tasksState is AsyncLoading<List<Task>>;
    final Object? tasksError = _tasksState.hasError ? _tasksState.error : null;
    final List<_TimelineSourceIssue> sourceIssues = <_TimelineSourceIssue>[
      if (timelinePersistenceCorrupted) _TimelineSourceIssue.persistence,
      if (tasksError != null)
        _TimelineSourceIssue.taskError
      else if (tasksLoading)
        _TimelineSourceIssue.taskLoading,
    ];
    final DateTime now = ref.watch(timelineClockProvider)();

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
    String? tutorialTaskId;
    for (final TimelineEventEntity event in filtered) {
      if (event.phase == 'task' &&
          event.relatedId != null &&
          expectedTutorialTaskIds.contains(event.relatedId)) {
        tutorialEventId = event.id;
        tutorialTaskId = event.relatedId;
        break;
      }
    }
    final String? publishedTutorialTaskId = ref.watch(
      timelineTutorialEvidenceProvider,
    );
    if (publishedTutorialTaskId != tutorialTaskId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(timelineTutorialEvidenceProvider.notifier)
            .setTaskId(tutorialTaskId);
      });
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
          _isOpenDeadline(event) &&
          due.year == now.year &&
          due.month == now.month &&
          due.day == now.day;
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
              if ((filtered.isNotEmpty ? sourceIssues : sourceIssues.skip(1))
                  .isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      children:
                          (filtered.isNotEmpty
                                  ? sourceIssues
                                  : sourceIssues.skip(1))
                              .map(
                                (_TimelineSourceIssue issue) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _TimelineSourceNotice(
                                    issue: issue,
                                    onRetry: switch (issue) {
                                      _TimelineSourceIssue.persistence =>
                                        _repairTimelinePersistence,
                                      _TimelineSourceIssue.taskError =>
                                        _retryTaskSource,
                                      _TimelineSourceIssue.taskLoading => null,
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                    ),
                  ),
                ),
              if (timelinePersistenceCorrupted && filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TimelineSourceState.persistenceError(
                    onRetry: _repairTimelinePersistence,
                  ),
                )
              else if (tasksLoading && filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TimelineSourceState.loading(),
                )
              else if (tasksError != null && filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TimelineSourceState.taskError(
                    onRetry: _retryTaskSource,
                  ),
                )
              else if (filtered.isEmpty)
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

  void _retryTaskSource() {
    setState(() {
      _tasksState = const AsyncLoading<List<Task>>();
      _cachedCombined = null;
    });
    ref.invalidate(tasksProvider);
  }

  Future<void> _repairTimelinePersistence() async {
    final _TimelineSafetyCopy copy = _TimelineSafetyCopy.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.repairTitle),
            content: Text(copy.repairBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                key: const Key('timeline-confirm-persistence-repair'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.preserveAndRepair),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      _cachedCombined = null;
      await ref
          .read(timelineProvider.notifier)
          .preserveAndRepairCorruptedStorage();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.repaired)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.notChanged)));
    }
  }
}
