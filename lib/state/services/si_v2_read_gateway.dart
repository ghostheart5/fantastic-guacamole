import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';

typedef SIV2TaskReader = Future<List<TaskEntity>> Function();
typedef SIV2GoalReader = Future<List<GoalEntity>> Function();
typedef SIV2MilestoneReader = Future<List<MilestoneEntity>> Function();
typedef SIV2TimelineReader = Future<List<TimelineEventEntity>> Function();
typedef SIV2HabitReader = Future<List<HabitEntity>> Function();
typedef SIV2HabitOccurrenceReader =
    Future<List<HabitOccurrenceEntity>> Function();
typedef SIV2PersonContextReader = PersonContextView? Function();

/// The only domain capability available to SI V2.
///
/// This adapter intentionally exposes no save, update, delete, analytics,
/// Timeline-write, memory-write, XP, or proposal capability. It also strips
/// descriptions, notes, reflections, and Timeline detail before analysis so
/// retrieved user text cannot become an instruction channel. Person context is
/// copied into a bounded evidence DTO; the raw projection and governance history
/// never cross into SI V2.
final class SIV2ReadGateway {
  const SIV2ReadGateway({
    required this.accountScopeId,
    required this.readTasks,
    required this.readGoals,
    required this.readMilestones,
    required this.readTimeline,
    this.readPersonContext,
    this.readHabits,
    this.readHabitOccurrences,
  });

  static const Set<PersonContextPurpose> personContextPurposes =
      operationalPersonContextPurposes;

  final String accountScopeId;
  final SIV2TaskReader readTasks;
  final SIV2GoalReader readGoals;
  final SIV2MilestoneReader readMilestones;
  final SIV2TimelineReader readTimeline;
  final SIV2PersonContextReader? readPersonContext;

  /// Optional: habits and their check-ins, read for the on-device one-tap
  /// questions only. Absent means "not read", not "none".
  final SIV2HabitReader? readHabits;
  final SIV2HabitOccurrenceReader? readHabitOccurrences;

  /// [includeActivity] also reads habits and check-ins and the last 14 days of
  /// finished or skipped tasks, for the on-device one-tap questions. Nothing
  /// else (paid packets, the older console) asks for them, so they are not
  /// read for those.
  Future<SIV2EvidenceSnapshot> read({
    required DateTime observedAt,
    String decisionText = '',
    bool includeActivity = false,
  }) async {
    final Set<SIV2Source> unavailable = <SIV2Source>{};
    List<TaskEntity> taskEntities = const <TaskEntity>[];
    List<GoalEntity> goalEntities = const <GoalEntity>[];
    List<MilestoneEntity> milestoneEntities = const <MilestoneEntity>[];
    List<TimelineEventEntity> timelineEntities = const <TimelineEventEntity>[];
    PersonContextView? personContextView;
    List<HabitEntity> habitEntities = const <HabitEntity>[];
    List<HabitOccurrenceEntity> occurrenceEntities =
        const <HabitOccurrenceEntity>[];
    bool habitsUnavailable = false;

    try {
      taskEntities = await readTasks().timeout(const Duration(seconds: 3));
    } on Object {
      unavailable.add(SIV2Source.tasks);
    }
    try {
      goalEntities = await readGoals().timeout(const Duration(seconds: 3));
    } on Object {
      unavailable.add(SIV2Source.goals);
    }
    try {
      milestoneEntities = await readMilestones().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      unavailable.add(SIV2Source.milestones);
    }
    try {
      timelineEntities = await readTimeline().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      unavailable.add(SIV2Source.timeline);
    }
    if (includeActivity && readHabits != null) {
      try {
        habitEntities = await readHabits!().timeout(const Duration(seconds: 3));
        occurrenceEntities =
            await (readHabitOccurrences?.call() ??
                    Future<List<HabitOccurrenceEntity>>.value(
                      const <HabitOccurrenceEntity>[],
                    ))
                .timeout(const Duration(seconds: 3));
      } on Object {
        habitsUnavailable = true;
        habitEntities = const <HabitEntity>[];
      }
    }
    try {
      personContextView = readPersonContext?.call();
    } on Object {
      personContextView = null;
    }

    final List<SIV2TaskEvidence> tasks =
        taskEntities
            .where(
              (TaskEntity item) =>
                  !item.isCompleted &&
                  !item.isSkipped &&
                  !item.isCanceled &&
                  item.title.trim().isNotEmpty,
            )
            .map(
              (TaskEntity item) => SIV2TaskEvidence(
                id: item.id,
                title: item.title.trim(),
                createdAt: item.createdAt.toUtc(),
                priority: item.priority,
                scheduledFor: item.scheduledFor?.toUtc(),
                dueDate: item.dueDate?.toUtc(),
                dueDay: _wholeDay(item.dueDate),
                goalId: _trimToNull(item.goalId),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2TaskEvidence left, SIV2TaskEvidence right) =>
                left.id.compareTo(right.id),
          );
    final List<SIV2GoalEvidence> goals =
        goalEntities
            .where(
              (GoalEntity item) =>
                  item.isActive && item.title.trim().isNotEmpty,
            )
            .map(
              (GoalEntity item) =>
                  _goalEvidence(item, taskEntities, milestoneEntities),
            )
            .toList(growable: false)
          ..sort(
            (SIV2GoalEvidence left, SIV2GoalEvidence right) =>
                left.id.compareTo(right.id),
          );
    final List<SIV2MilestoneEvidence> milestones =
        milestoneEntities
            .where((MilestoneEntity item) => item.title.trim().isNotEmpty)
            .map(
              (MilestoneEntity item) => SIV2MilestoneEvidence(
                id: item.id,
                title: item.title.trim(),
                createdAt: item.createdAt.toUtc(),
                updatedAt: item.updatedAt.toUtc(),
                completionPercent: item.completionPercent.clamp(0, 100),
                completed: item.isCompleted,
                archived: item.isArchived,
                goalId: _trimToNull(item.goalId),
                targetDate: item.targetDate?.toUtc(),
                targetDay: _wholeDay(item.targetDate),
                dependencies: List<String>.unmodifiable(
                  item.dependencies
                      .map((String value) => value.trim())
                      .where((String value) => value.isNotEmpty),
                ),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2MilestoneEvidence left, SIV2MilestoneEvidence right) =>
                left.id.compareTo(right.id),
          );
    final List<SIV2TimelineEvidence> timeline =
        timelineEntities
            .where((TimelineEventEntity item) => item.title.trim().isNotEmpty)
            .map(
              (TimelineEventEntity item) => SIV2TimelineEvidence(
                id: item.id,
                title: item.title.trim(),
                timestamp: item.timestamp.toUtc(),
                type: item.type.name,
                status: item.status.name,
                dueAt: item.dueAt?.toUtc(),
                relatedId: _trimToNull(item.relatedId),
                sourceFeature: _trimToNull(item.sourceFeature),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2TimelineEvidence left, SIV2TimelineEvidence right) =>
                right.timestamp.compareTo(left.timestamp),
          );
    final List<SIV2HabitEvidence> habits = includeActivity
        ? _habitEvidence(habitEntities, occurrenceEntities, observedAt)
        : const <SIV2HabitEvidence>[];
    final List<SIV2RecentTaskEvidence> recentTasks = includeActivity
        ? _recentTaskEvidence(taskEntities, observedAt)
        : const <SIV2RecentTaskEvidence>[];
    final SIV2PersonContextEvidence? personContext = decisionText.trim().isEmpty
        ? siV2PersonContextEvidenceOrNull(
            personContextView,
            accountScopeId: accountScopeId,
          )
        : _decisionPersonContextEvidenceOrNull(
            personContextView,
            accountScopeId: accountScopeId,
            tasks: taskEntities,
            decisionText: decisionText,
            observedAt: observedAt,
          );

    return SIV2EvidenceSnapshot(
      accountScopeId: accountScopeId,
      observedAt: observedAt.toUtc(),
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      timeline: timeline,
      personContext: personContext,
      unavailableSources: unavailable,
      habits: habits,
      recentTasks: recentTasks,
      habitsUnavailable: habitsUnavailable,
    );
  }
}

/// The calendar day of a date saved without a time of day (midnight), as year,
/// month and day at local midnight; null for a deadline with a time. Mirrors
/// TaskEntity.hasDateOnlyDeadline and effectiveDueAt: the stored components are
/// the day the person chose, even when the value is marked UTC.
DateTime? _wholeDay(DateTime? value) {
  if (value == null ||
      value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    return null;
  }
  return DateTime(value.year, value.month, value.day);
}

/// Window the on-device one-tap questions look back over.
const int _recentWindowDays = 14;

SIV2GoalEvidence _goalEvidence(
  GoalEntity goal,
  List<TaskEntity> tasks,
  List<MilestoneEntity> milestones,
) {
  int tasksDone = 0;
  int tasksOpen = 0;
  for (final TaskEntity task in tasks) {
    if (task.goalId?.trim() != goal.id || task.isCanceled) continue;
    if (task.isCompleted) {
      tasksDone++;
    } else if (!task.isSkipped) {
      tasksOpen++;
    }
  }
  int milestonesDone = 0;
  int milestonesOpen = 0;
  for (final MilestoneEntity milestone in milestones) {
    if (milestone.goalId?.trim() != goal.id || milestone.isArchived) continue;
    milestone.isCompleted ? milestonesDone++ : milestonesOpen++;
  }
  return SIV2GoalEvidence(
    id: goal.id,
    title: goal.title.trim(),
    createdAt: goal.createdAt.toUtc(),
    targetDate: goal.targetDate?.toUtc(),
    targetDay: _wholeDay(goal.targetDate),
    linkedTasksDone: tasksDone,
    linkedTasksOpen: tasksOpen,
    milestonesDone: milestonesDone,
    milestonesOpen: milestonesOpen,
  );
}

List<SIV2HabitEvidence> _habitEvidence(
  List<HabitEntity> habits,
  List<HabitOccurrenceEntity> occurrences,
  DateTime observedAt,
) {
  final DateTime now = observedAt.toLocal();
  final DateTime windowStart = observedAt.subtract(
    const Duration(days: _recentWindowDays),
  );
  final List<SIV2HabitEvidence> result = <SIV2HabitEvidence>[];
  for (final HabitEntity habit in habits) {
    if (habit.status != HabitStatus.active ||
        habit.id.trim().isEmpty ||
        habit.title.trim().isEmpty) {
      continue;
    }
    final List<HabitOccurrenceEntity> completed = occurrences
        .where(
          (HabitOccurrenceEntity item) =>
              item.habitId == habit.id &&
              item.outcome == HabitOccurrenceOutcome.completed,
        )
        .toList(growable: false);
    final Set<String> keys = <String>{
      for (final HabitOccurrenceEntity item in completed) item.occurrenceKey,
    };
    String keyAt(DateTime day) =>
        RhythmPlanningContext.occurrenceKey(habit, day);
    DateTime previous(DateTime day) => switch (habit.cadence) {
      HabitCadence.daily => DateTime(day.year, day.month, day.day - 1),
      HabitCadence.weekly => DateTime(day.year, day.month, day.day - 7),
      HabitCadence.monthly => DateTime(day.year, day.month - 1, 1),
    };
    final bool checkedIn = keys.contains(keyAt(now));
    // The period that is still open does not break a streak.
    DateTime cursor = checkedIn ? now : previous(now);
    int streak = 0;
    while (streak < 400 && keys.contains(keyAt(cursor))) {
      streak++;
      cursor = previous(cursor);
    }
    result.add(
      SIV2HabitEvidence(
        id: habit.id,
        title: habit.title.trim(),
        createdAt: habit.createdAt.toUtc(),
        cadence: habit.cadence,
        targetCount: habit.targetCount,
        checkInsInWindow: completed
            .where(
              (HabitOccurrenceEntity item) =>
                  !item.recordedAt.isBefore(windowStart) &&
                  !item.recordedAt.isAfter(observedAt),
            )
            .length,
        currentStreak: streak,
        checkedInThisPeriod: checkedIn,
        windowDays: _recentWindowDays,
        trackedSince: (habit.frequencyStartedAt ?? habit.createdAt).toUtc(),
      ),
    );
  }
  result.sort(
    (SIV2HabitEvidence left, SIV2HabitEvidence right) =>
        left.id.compareTo(right.id),
  );
  return result.length <= 40 ? result : result.sublist(0, 40);
}

List<SIV2RecentTaskEvidence> _recentTaskEvidence(
  List<TaskEntity> tasks,
  DateTime observedAt,
) {
  final DateTime windowStart = observedAt.subtract(
    const Duration(days: _recentWindowDays),
  );
  final DateTime windowEnd = observedAt.add(const Duration(days: 1));
  final List<SIV2RecentTaskEvidence> result = <SIV2RecentTaskEvidence>[];
  for (final TaskEntity task in tasks) {
    if (task.isCanceled || task.title.trim().isEmpty) continue;
    final bool completed = task.isCompleted;
    final DateTime? at = completed ? task.completedAt : task.skippedAt;
    if ((!completed && !task.isSkipped) || at == null) continue;
    if (at.isBefore(windowStart) || at.isAfter(windowEnd)) continue;
    result.add(
      SIV2RecentTaskEvidence(
        id: task.id,
        title: task.title.trim(),
        outcome: completed
            ? SIV2RecentTaskOutcome.completed
            : SIV2RecentTaskOutcome.skipped,
        at: at.toUtc(),
        goalId: _trimToNull(task.goalId),
      ),
    );
  }
  result.sort(
    (SIV2RecentTaskEvidence left, SIV2RecentTaskEvidence right) =>
        right.at.compareTo(left.at),
  );
  return result.length <= 200 ? result : result.sublist(0, 200);
}

SIV2PersonContextEvidence? _decisionPersonContextEvidenceOrNull(
  PersonContextView? view, {
  required String accountScopeId,
  required List<TaskEntity> tasks,
  required String decisionText,
  required DateTime observedAt,
}) {
  if (view == null || view.accountScopeId != accountScopeId) return null;
  final Set<PersonContextKind> relevantKinds = _relevantUnknownKinds(
    decisionText,
  );
  final GovernedDecisionContext context = GovernedDecisionContext.resolve(
    view: view,
    accountScopeId: accountScopeId,
    tasks: <TaskEntity>[
      TaskEntity(id: 'si-question', title: decisionText, createdAt: observedAt),
      ...tasks.where(
        (TaskEntity task) => _textOverlaps(task.title, decisionText),
      ),
    ],
    now: observedAt,
    surface: PersonContextSurface.siConsole,
    ignoredSignalIds: <String>{
      for (final PersonContextSignal signal in view.signals)
        if (signal.kind == PersonContextKind.presentCapacity &&
            !relevantKinds.contains(PersonContextKind.presentCapacity))
          signal.id,
    },
  );
  if (context.status == GovernedDecisionContextStatus.unavailable) return null;
  final List<SIV2PersonContextSignalEvidence> signals =
      view.signals
          .where(
            (PersonContextSignal signal) =>
                context.appliedSignalIds.contains(signal.id),
          )
          .map(
            (PersonContextSignal signal) => SIV2PersonContextSignalEvidence(
              id: signal.id,
              kind: signal.kind,
              userReportedValue: signal.value,
              source: signal.source,
              purpose: signal.purpose,
              recordedAt: signal.recordedAt.toUtc(),
              freshUntil: signal.freshUntil.toUtc(),
              expiresAt: signal.expiresAt.toUtc(),
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.id.compareTo(right.id));
  return SIV2PersonContextEvidence(
    observedAt: view.observedAt.toUtc(),
    purposes: SIV2ReadGateway.personContextPurposes,
    signals: signals,
    unknownKinds: view.unknownKinds.intersection(relevantKinds),
    behaviorTrace: context.trace?.toJson() ?? const <String, Object?>{},
  );
}

Set<PersonContextKind> _relevantUnknownKinds(String decisionText) {
  final Set<String> words = _meaningfulWords(decisionText);
  return <PersonContextKind>{
    if (words.contains('next') ||
        words.contains('priority') ||
        words.contains('first'))
      PersonContextKind.currentPriority,
    if (words.contains('time') ||
        RegExp(
          r'\b(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten|fifteen|twenty|thirty|forty|sixty|an?|half)[ -]*(?:minutes?|mins?|hours?|hrs?)\b',
          caseSensitive: false,
        ).hasMatch(decisionText) ||
        words.contains('capacity') ||
        words.contains('workload') ||
        words.contains('schedule'))
      PersonContextKind.presentCapacity,
    if (words.contains('schedule') || words.contains('plan'))
      PersonContextKind.boundary,
    if (words.contains('commitment') ||
        words.contains('schedule') ||
        words.contains('next'))
      PersonContextKind.commitment,
  };
}

bool _textOverlaps(String left, String right) =>
    _meaningfulWords(left).intersection(_meaningfulWords(right)).isNotEmpty;

Set<String> _meaningfulWords(String value) => RegExp(r'[a-z0-9]+')
    .allMatches(value.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where((String word) => word.length >= 4)
    .toSet();

SIV2PersonContextEvidence? siV2PersonContextEvidenceOrNull(
  PersonContextView? view, {
  required String accountScopeId,
}) {
  if (view == null ||
      view.accountScopeId != accountScopeId ||
      view.surface != PersonContextSurface.siConsole ||
      !_samePurposes(view.purposes, SIV2ReadGateway.personContextPurposes)) {
    return null;
  }
  try {
    final PersonContextBehaviorTrace evaluated =
        PersonContextBehaviorPolicy.evaluate(
          signals: view.signals,
          surface: PersonContextSurface.siConsole,
          purposes: view.purposes,
          relevance: <String, PersonContextRelevanceBasis>{
            for (final PersonContextSignal signal in view.signals)
              signal.id: PersonContextRelevanceBasis.typedReviewEvidence,
          },
          now: view.observedAt,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{
            PersonContextBehaviorField.supportingEvidence: 'none',
          },
          maxUsedSignals: SIV2PersonContextEvidence.maxSignals,
        );
    final Set<String> approvedSignalIds = evaluated.used
        .map((PersonContextBehaviorDecision decision) => decision.signalId)
        .toSet();
    final List<SIV2PersonContextSignalEvidence> signals =
        view.signals
            .where(
              (PersonContextSignal signal) =>
                  approvedSignalIds.contains(signal.id),
            )
            .map(
              (PersonContextSignal signal) => SIV2PersonContextSignalEvidence(
                id: signal.id,
                kind: signal.kind,
                userReportedValue: signal.value,
                source: signal.source,
                purpose: signal.purpose,
                recordedAt: signal.recordedAt.toUtc(),
                freshUntil: signal.freshUntil.toUtc(),
                expiresAt: signal.expiresAt.toUtc(),
              ),
            )
            .toList(growable: false)
          ..sort(
            (
              SIV2PersonContextSignalEvidence left,
              SIV2PersonContextSignalEvidence right,
            ) => left.id.compareTo(right.id),
          );
    final Set<PersonContextKind> knownKinds = signals
        .map((SIV2PersonContextSignalEvidence signal) => signal.kind)
        .toSet();
    return SIV2PersonContextEvidence(
      observedAt: view.observedAt.toUtc(),
      purposes: SIV2ReadGateway.personContextPurposes,
      signals: signals,
      unknownKinds: PersonContextKind.values.toSet().difference(knownKinds),
    );
  } on Object {
    return null;
  }
}

bool _samePurposes(
  Set<PersonContextPurpose> left,
  Set<PersonContextPurpose> right,
) => left.length == right.length && left.containsAll(right);

String? _trimToNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
