import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/si/si_one_tap_engine.dart'
    show oneTapAddDays;

enum ActivityKind { task, habit }

enum ActivityOutcome { done, skipped }

/// One thing the person did, derived from saved tasks and habit check-ins so
/// both can be read side by side. Never stored.
class ActivityRecord {
  const ActivityRecord({
    required this.kind,
    required this.subjectId,
    required this.title,
    required this.outcome,
    required this.at,
    this.periodKey,
  });

  final ActivityKind kind;

  /// The task id or the habit id.
  final String subjectId;
  final String title;
  final ActivityOutcome outcome;

  /// When it was recorded (time of day comes from here).
  final DateTime at;

  /// The habit period it counts for (null for a task).
  final String? periodKey;

  @override
  bool operator ==(Object other) =>
      other is ActivityRecord &&
      other.kind == kind &&
      other.subjectId == subjectId &&
      other.title == title &&
      other.outcome == outcome &&
      other.at == at &&
      other.periodKey == periodKey;

  @override
  int get hashCode =>
      Object.hash(kind, subjectId, title, outcome, at, periodKey);

  /// Newest first; records at the same moment order by kind, then subject id,
  /// then period key, so the order never depends on input order.
  static int newestFirst(ActivityRecord a, ActivityRecord b) {
    final int byTime = b.at.compareTo(a.at);
    if (byTime != 0) return byTime;
    final int byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    final int bySubject = a.subjectId.compareTo(b.subjectId);
    return bySubject != 0
        ? bySubject
        : (a.periodKey ?? '').compareTo(b.periodKey ?? '');
  }
}

/// The record for a finished or skipped task; null for a canceled task, one
/// with no title or one without a recorded time.
ActivityRecord? activityFromTask(TaskEntity task) {
  final String title = task.title.trim();
  if (task.isCanceled || title.isEmpty) return null;
  final bool done = task.isCompleted;
  if (!done && !task.isSkipped) return null;
  final DateTime? at = done ? task.completedAt : task.skippedAt;
  if (at == null) return null;
  return ActivityRecord(
    kind: ActivityKind.task,
    subjectId: task.id,
    title: title,
    outcome: done ? ActivityOutcome.done : ActivityOutcome.skipped,
    at: at,
  );
}

/// The record for one check-in of [habit]; null when it belongs to another
/// habit or the habit has no title.
ActivityRecord? activityFromHabitOccurrence(
  HabitEntity habit,
  HabitOccurrenceEntity occurrence,
) {
  final String title = habit.title.trim();
  if (occurrence.habitId != habit.id || title.isEmpty) return null;
  return ActivityRecord(
    kind: ActivityKind.habit,
    subjectId: habit.id,
    title: title,
    outcome: occurrence.outcome == HabitOccurrenceOutcome.completed
        ? ActivityOutcome.done
        : ActivityOutcome.skipped,
    at: occurrence.recordedAt,
    periodKey: occurrence.occurrenceKey,
  );
}

/// Every record of [habit] from [occurrences] (those of other habits are
/// ignored).
List<ActivityRecord> activityFromHabit(
  HabitEntity habit,
  Iterable<HabitOccurrenceEntity> occurrences,
) => <ActivityRecord>[
  for (final HabitOccurrenceEntity item in occurrences)
    ?activityFromHabitOccurrence(habit, item),
];

/// Task and habit records from the last [days] calendar days up to the end of
/// today ([now]'s local day), newest first. Habit history is kept whatever the
/// habit's status is now. Check-ins of a habit that is no longer saved are
/// dropped (there is no title to show). A task id, or a habit and period, is
/// listed once: of its records inside the window, a check-in over a skip,
/// then the newest.
List<ActivityRecord> activityRecords({
  required Iterable<TaskEntity> tasks,
  required Iterable<HabitEntity> habits,
  required Iterable<HabitOccurrenceEntity> occurrences,
  required DateTime now,
  int days = 7,
}) {
  final DateTime today = now.toLocal();
  final DateTime start = oneTapAddDays(today, -(days - 1));
  final DateTime end = oneTapAddDays(today, 1);
  final Map<String, HabitEntity> byId = <String, HabitEntity>{
    for (final HabitEntity h in habits) h.id: h,
  };
  final List<ActivityRecord> all = <ActivityRecord>[
    for (final TaskEntity t in tasks) ?activityFromTask(t),
    for (final HabitOccurrenceEntity o in occurrences)
      if (byId[o.habitId] case final HabitEntity h)
        ?activityFromHabitOccurrence(h, o),
  ];
  // The window first, so a record outside it never hides one inside it.
  final Iterable<ActivityRecord> inWindow = all.where((ActivityRecord r) {
    final DateTime at = r.at.toLocal();
    return !at.isBefore(start) && at.isBefore(end);
  });
  // One record per task, or per habit and period: a check-in over a skip
  // (as habit consistency counts it), then the newest.
  final Map<String, ActivityRecord> kept = <String, ActivityRecord>{};
  for (final ActivityRecord r in inWindow) {
    final String key = '${r.kind.name}|${r.subjectId}|${r.periodKey ?? ''}';
    final ActivityRecord? current = kept[key];
    if (current == null || _preferred(r, current)) kept[key] = r;
  }
  final List<ActivityRecord> result = kept.values.toList()
    ..sort(ActivityRecord.newestFirst);
  return List<ActivityRecord>.of(result, growable: false);
}

/// Whether [a] is kept over [b] for the same task or habit period: done over
/// skipped, then the newer one (then the stable record order).
bool _preferred(ActivityRecord a, ActivityRecord b) {
  if (a.outcome != b.outcome) return a.outcome == ActivityOutcome.done;
  return ActivityRecord.newestFirst(a, b) < 0;
}
