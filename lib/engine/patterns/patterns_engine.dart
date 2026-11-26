import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/patterns/activity_record.dart';
import 'package:fantastic_guacamole/engine/patterns/habit_consistency.dart';
import 'package:fantastic_guacamole/engine/si/si_one_tap_engine.dart'
    show oneTapAddDays;

/// Where a figure comes from: counted straight from saved records, or worked
/// out from them (a streak, a share, a planned total).
enum PatternProvenance { recorded, calculated }

/// Why a figure is not shown yet. Machine-readable: the screen writes the
/// words.
enum PatternEvidenceReason {
  /// Nothing recorded at all for this figure.
  noRecords,

  /// Some records, fewer than the minimum ([PatternEvidence.have] of
  /// [PatternEvidence.need]).
  tooFewRecords,

  /// No active habits.
  noHabits,

  /// Nothing planned in the next seven days.
  noPlannedWork,
}

/// Whether there is enough saved history to show a figure, with the counts a
/// message such as "4 of 5" needs.
class PatternEvidence {
  const PatternEvidence.enough({this.have = 0, this.need = 0})
    : enough = true,
      reason = null;

  const PatternEvidence.notEnough({
    required PatternEvidenceReason this.reason,
    this.have = 0,
    this.need = 1,
  }) : enough = false;

  final bool enough;
  final PatternEvidenceReason? reason;
  final int have;
  final int need;
}

/// One figure of the result: its value, where it comes from and whether the
/// history behind it is enough.
class PatternMetric<T> {
  const PatternMetric({
    required this.value,
    required this.provenance,
    required this.evidence,
  });

  final T value;
  final PatternProvenance provenance;
  final PatternEvidence evidence;
}

/// One habit's consistency over the range.
class HabitPattern {
  const HabitPattern({
    required this.habitId,
    required this.title,
    required this.consistency,
  });

  final String habitId;
  final String title;

  /// Completed, skipped, missed periods, window and both streaks.
  final HabitConsistency consistency;
}

/// Tasks finished and habit check-ins in one stretch of days
/// ([start] inclusive, [end] exclusive), counted separately.
class TrendBucket {
  const TrendBucket({
    required this.start,
    required this.end,
    required this.tasksFinished,
    required this.habitCheckIns,
  });

  final DateTime start;
  final DateTime end;
  final int tasksFinished;
  final int habitCheckIns;
}

class CompletionTrend {
  const CompletionTrend({
    required this.buckets,
    required this.bucketDays,
    required this.coveredDays,
    required this.tasksFinished,
    required this.habitCheckIns,
  });

  /// Oldest first. 7 daily buckets for the 7-day range, 4 weekly buckets (the
  /// last 28 days) for the 30-day range.
  final List<TrendBucket> buckets;

  /// 1 for daily buckets, 7 for weekly ones.
  final int bucketDays;

  /// The days the buckets cover together: 7, or 28 for the 30-day range (the
  /// habit figures and skipped tasks of that range cover 30). The screen says
  /// "last 4 weeks" for the trend when this is 28.
  final int coveredDays;

  /// Tasks finished in the buckets, by when they were marked done.
  final int tasksFinished;

  /// Habit check-ins in the buckets, counted by when each was recorded, not by
  /// the period it counts for (a check-in made late for a past period counts
  /// on the day it was made).
  final int habitCheckIns;
}

/// When finished tasks tend to be marked done. A field is null when no single
/// weekday or part of day stands out.
class WhenThingsGetDone {
  const WhenThingsGetDone({
    required this.finishedTasks,
    required this.windowStart,
    required this.windowDays,
    this.weekday,
    this.weekdayCount = 0,
    this.partOfDay,
    this.partOfDayCount = 0,
  });

  final int finishedTasks;

  /// The look-back used: [windowDays] calendar days ending today, starting at
  /// local midnight [windowStart]. The same whatever range is selected (a
  /// weekday cannot reach 3 finished tasks in 7 days), so the screen says
  /// "last 4 weeks" for 28. The free one-tap answer looks back 14 days, so the
  /// two can name different days on purpose.
  final DateTime windowStart;
  final int windowDays;

  /// ISO weekday, 1 = Monday ... 7 = Sunday.
  final int? weekday;
  final int weekdayCount;
  final PartOfDay? partOfDay;
  final int partOfDayCount;
}

/// The same four parts and hour boundaries as the one-tap "explain my
/// patterns" answer: night 0:00 to 5:59, morning 6:00 to 11:59, afternoon
/// 12:00 to 16:59, evening 17:00 to 23:59.
enum PartOfDay { night, morning, afternoon, evening }

/// Planned work on one day.
///
/// Every workload figure rests on task estimates: an estimate the person chose
/// cannot be told from the app's default (the Creator form always saves 30, a
/// restored task without one reads as 30), so the screen should say "based on
/// your estimates" for all of it. The one thing known is which tasks have no
/// estimate saved at all ([withoutEstimateCount]); those count 25 minutes.
class WorkloadDay {
  const WorkloadDay({
    required this.day,
    required this.plannedMinutes,
    required this.taskCount,
    required this.withoutEstimateCount,
  });

  /// Local midnight of the day.
  final DateTime day;
  final int plannedMinutes;
  final int taskCount;

  /// How many of the tasks have no estimate saved, so their minutes are the
  /// app's fallback and the figure is rougher still.
  final int withoutEstimateCount;

  bool get hasTasksWithoutEstimate => withoutEstimateCount > 0;
}

/// Open tasks that have no day among the next 7: no schedule or deadline, or
/// the date has passed (slipped or overdue). Their minutes are in no day.
class UnplacedWork {
  const UnplacedWork({
    required this.taskCount,
    required this.plannedMinutes,
    required this.withoutEstimateCount,
  });

  final int taskCount;
  final int plannedMinutes;
  final int withoutEstimateCount;
}

/// A habit period that was skipped on purpose or missed.
class HabitPeriodMiss {
  const HabitPeriodMiss({
    required this.habitId,
    required this.title,
    required this.start,
    required this.state,
  });

  final String habitId;
  final String title;

  /// The real start of the period at local midnight: that day, its Monday or
  /// the 1st.
  final DateTime start;

  /// [HabitPeriodState.missed] or [HabitPeriodState.skipped].
  final HabitPeriodState state;
}

class MissedItems {
  const MissedItems({
    required this.skippedTasks,
    required this.overdueTasks,
    required this.habitPeriods,
  });

  /// Tasks skipped in the range, newest first.
  final PatternMetric<List<ActivityRecord>> skippedTasks;

  /// Open tasks whose deadline has passed now. A task due on a whole day is
  /// not overdue until that day ends.
  final PatternMetric<List<TaskEntity>> overdueTasks;

  /// Habit periods in the range that were skipped or missed, newest first.
  /// The period still open is never listed.
  final PatternMetric<List<HabitPeriodMiss>> habitPeriods;
}

/// Everything the Patterns screen shows, from saved records only. Data only:
/// no sentences.
class PatternsResult {
  const PatternsResult({
    required this.now,
    required this.rangeDays,
    required this.habits,
    required this.trend,
    required this.whenDone,
    required this.workload,
    required this.unplaced,
    required this.missed,
  });

  /// The empty account: every figure empty and not enough.
  factory PatternsResult.empty({required DateTime now, int rangeDays = 7}) =>
      PatternsEngine.compute(
        tasks: const <TaskEntity>[],
        habits: const <HabitEntity>[],
        occurrences: const <HabitOccurrenceEntity>[],
        now: now,
        rangeDays: rangeDays,
      );

  final DateTime now;
  final int rangeDays;
  final PatternMetric<List<HabitPattern>> habits;
  final PatternMetric<CompletionTrend> trend;
  final PatternMetric<WhenThingsGetDone> whenDone;

  /// The next 7 days, today first.
  final PatternMetric<List<WorkloadDay>> workload;

  /// Open work with no day among those 7 (undated, slipped or overdue).
  final PatternMetric<UnplacedWork> unplaced;
  final MissedItems missed;
}

/// Pure patterns over saved tasks, habits and habit check-ins. Reuses
/// [HabitConsistency] and [activityRecords]; reads no clock.
class PatternsEngine {
  const PatternsEngine._();

  /// The ranges the screen offers.
  static const List<int> ranges = <int>[7, 30];

  /// Same thresholds as the one-tap "explain my patterns" answer in
  /// lib/engine/si/si_one_tap_engine.review.dart (copied, not shared; a test
  /// runs both on one fixture so they cannot drift apart).
  static const int minimumFinishedTasks = 5;
  static const int minimumOnWeekday = 3;
  static const int minimumInPartOfDay = 3;

  /// "When things get done" looks back four whole weeks whatever the range:
  /// a weekday needs at least 3 finished tasks, which a 7-day range could
  /// never hold (each weekday occurs once).
  static const int whenDoneLookBackDays = 28;

  /// Days of planned work looked at.
  static const int workloadDays = 7;

  static PartOfDay partOfDay(int hour) => hour < 6
      ? PartOfDay.night
      : hour < 12
      ? PartOfDay.morning
      : hour < 17
      ? PartOfDay.afternoon
      : PartOfDay.evening;

  static PatternsResult compute({
    required Iterable<TaskEntity> tasks,
    required Iterable<HabitEntity> habits,
    required Iterable<HabitOccurrenceEntity> occurrences,
    required DateTime now,
    int rangeDays = 7,
  }) {
    if (!ranges.contains(rangeDays)) {
      throw ArgumentError.value(rangeDays, 'rangeDays', 'must be 7 or 30');
    }
    final DateTime today = now.toLocal();
    final List<TaskEntity> allTasks = tasks.toList(growable: false);
    final List<HabitEntity> allHabits = habits.toList(growable: false);
    final List<HabitOccurrenceEntity> allOccurrences = occurrences.toList(
      growable: false,
    );
    // Wide enough for the longest view: the 4 weekly buckets cover 28 days.
    final List<ActivityRecord> records = activityRecords(
      tasks: allTasks,
      habits: allHabits,
      occurrences: allOccurrences,
      now: today,
      days: rangeDays > 28 ? rangeDays : 28,
    );
    final DateTime rangeStart = oneTapAddDays(today, -(rangeDays - 1));
    final DateTime whenDoneStart = oneTapAddDays(
      today,
      -(whenDoneLookBackDays - 1),
    );
    final List<ActivityRecord> inRange = records
        .where((ActivityRecord r) => !r.at.toLocal().isBefore(rangeStart))
        .toList(growable: false);

    final List<HabitPattern> habitPatterns = _habitPatterns(
      allHabits,
      allOccurrences,
      today,
      rangeDays,
    );

    final workload = _workload(allTasks, today);

    return PatternsResult(
      now: today,
      rangeDays: rangeDays,
      habits: PatternMetric<List<HabitPattern>>(
        value: List<HabitPattern>.unmodifiable(habitPatterns),
        provenance: PatternProvenance.calculated,
        evidence: habitPatterns.isEmpty
            ? const PatternEvidence.notEnough(
                reason: PatternEvidenceReason.noHabits,
                need: 1,
              )
            : PatternEvidence.enough(have: habitPatterns.length, need: 1),
      ),
      trend: _trend(records, today, rangeDays),
      whenDone: _whenDone(
        records.where(
          (ActivityRecord r) => !r.at.toLocal().isBefore(whenDoneStart),
        ),
        whenDoneStart,
      ),
      workload: workload.days,
      unplaced: workload.unplaced,
      missed: _missed(allTasks, habitPatterns, inRange, today, rangeStart),
    );
  }

  static int _habitWindow(HabitCadence cadence, int rangeDays) {
    final int base = HabitConsistency.defaultWindowPeriods(cadence);
    final int needed = switch (cadence) {
      HabitCadence.daily => rangeDays,
      HabitCadence.weekly => (rangeDays + 6) ~/ 7,
      HabitCadence.monthly => (rangeDays + 29) ~/ 30,
    };
    return needed > base ? needed : base;
  }

  static List<HabitPattern> _habitPatterns(
    List<HabitEntity> habits,
    List<HabitOccurrenceEntity> occurrences,
    DateTime today,
    int rangeDays,
  ) {
    final List<HabitPattern> out = <HabitPattern>[];
    for (final HabitEntity habit in habits) {
      final HabitConsistency? c = HabitConsistency.compute(
        habit: habit,
        occurrences: occurrences,
        now: today,
        windowPeriods: _habitWindow(habit.cadence, rangeDays),
      );
      if (c == null) continue;
      out.add(
        HabitPattern(habitId: habit.id, title: habit.title, consistency: c),
      );
    }
    return out;
  }

  static PatternMetric<CompletionTrend> _trend(
    List<ActivityRecord> records,
    DateTime today,
    int rangeDays,
  ) {
    final bool daily = rangeDays == 7;
    final int bucketDays = daily ? 1 : 7;
    final int count = daily ? 7 : 4;
    final DateTime first = oneTapAddDays(today, -(count * bucketDays - 1));
    final List<TrendBucket> buckets = <TrendBucket>[];
    int totalTasks = 0;
    int totalHabits = 0;
    for (int i = 0; i < count; i++) {
      final DateTime start = oneTapAddDays(first, i * bucketDays);
      final DateTime end = oneTapAddDays(start, bucketDays);
      int tasks = 0;
      int habits = 0;
      for (final ActivityRecord r in records) {
        if (r.outcome != ActivityOutcome.done) continue;
        final DateTime at = r.at.toLocal();
        if (at.isBefore(start) || !at.isBefore(end)) continue;
        if (r.kind == ActivityKind.task) {
          tasks++;
        } else {
          habits++;
        }
      }
      totalTasks += tasks;
      totalHabits += habits;
      buckets.add(
        TrendBucket(
          start: start,
          end: end,
          tasksFinished: tasks,
          habitCheckIns: habits,
        ),
      );
    }
    final int total = totalTasks + totalHabits;
    return PatternMetric<CompletionTrend>(
      value: CompletionTrend(
        buckets: List<TrendBucket>.unmodifiable(buckets),
        bucketDays: bucketDays,
        coveredDays: count * bucketDays,
        tasksFinished: totalTasks,
        habitCheckIns: totalHabits,
      ),
      provenance: PatternProvenance.recorded,
      evidence: total == 0
          ? const PatternEvidence.notEnough(
              reason: PatternEvidenceReason.noRecords,
            )
          : PatternEvidence.enough(have: total, need: 1),
    );
  }

  static PatternMetric<WhenThingsGetDone> _whenDone(
    Iterable<ActivityRecord> lookBack,
    DateTime windowStart,
  ) {
    final List<ActivityRecord> done = lookBack
        .where(
          (ActivityRecord r) =>
              r.kind == ActivityKind.task && r.outcome == ActivityOutcome.done,
        )
        .toList(growable: false);
    if (done.length < minimumFinishedTasks) {
      return PatternMetric<WhenThingsGetDone>(
        value: WhenThingsGetDone(
          finishedTasks: done.length,
          windowStart: windowStart,
          windowDays: whenDoneLookBackDays,
        ),
        provenance: PatternProvenance.calculated,
        evidence: PatternEvidence.notEnough(
          reason: done.isEmpty
              ? PatternEvidenceReason.noRecords
              : PatternEvidenceReason.tooFewRecords,
          have: done.length,
          need: minimumFinishedTasks,
        ),
      );
    }
    final Map<int, int> byDay = <int, int>{};
    final Map<PartOfDay, int> byPart = <PartOfDay, int>{};
    for (final ActivityRecord r in done) {
      final DateTime at = r.at.toLocal();
      byDay.update(at.weekday, (int v) => v + 1, ifAbsent: () => 1);
      byPart.update(partOfDay(at.hour), (int v) => v + 1, ifAbsent: () => 1);
    }
    // A day counts only with at least 3 and strictly more than any other day.
    final List<MapEntry<int, int>> days = byDay.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final bool dayStands =
        days.first.value >= minimumOnWeekday &&
        (days.length == 1 || days.first.value > days[1].value);
    // A part counts only with at least 3 and more than half.
    final List<MapEntry<PartOfDay, int>> parts = byPart.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final bool partStands =
        parts.first.value >= minimumInPartOfDay &&
        parts.first.value * 2 > done.length;
    return PatternMetric<WhenThingsGetDone>(
      value: WhenThingsGetDone(
        finishedTasks: done.length,
        windowStart: windowStart,
        windowDays: whenDoneLookBackDays,
        weekday: dayStands ? days.first.key : null,
        weekdayCount: dayStands ? days.first.value : 0,
        partOfDay: partStands ? parts.first.key : null,
        partOfDayCount: partStands ? parts.first.value : 0,
      ),
      provenance: PatternProvenance.calculated,
      evidence: PatternEvidence.enough(
        have: done.length,
        need: minimumFinishedTasks,
      ),
    );
  }

  static DateTime _day(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// The day a deadline names: a whole-day deadline owns the day it names.
  static DateTime? _deadlineDay(TaskEntity task) {
    final DateTime? due = task.dueDate;
    if (due == null) return null;
    return task.hasDateOnlyDeadline
        ? DateTime(due.year, due.month, due.day)
        : _day(due);
  }

  /// The day a task's work lands on: its schedule, and once that day has
  /// passed (slipped work) its deadline. Null when there is none; a day before
  /// [today] means the work is overdue.
  static DateTime? _workDay(TaskEntity task, DateTime today) {
    final DateTime? scheduled = task.scheduledFor == null
        ? null
        : _day(task.scheduledFor!);
    if (scheduled != null && !scheduled.isBefore(today)) return scheduled;
    return _deadlineDay(task);
  }

  static ({
    PatternMetric<List<WorkloadDay>> days,
    PatternMetric<UnplacedWork> unplaced,
  })
  _workload(List<TaskEntity> tasks, DateTime now) {
    final DateTime first = DateTime(now.year, now.month, now.day);
    final List<DateTime> days = <DateTime>[
      for (int i = 0; i < workloadDays; i++) oneTapAddDays(first, i),
    ];
    final Map<DateTime, List<TaskEntity>> byDay = <DateTime, List<TaskEntity>>{
      for (final DateTime d in days) d: <TaskEntity>[],
    };
    final List<TaskEntity> unplaced = <TaskEntity>[];
    for (final TaskEntity task in tasks) {
      if (!task.isActionableAt(now)) continue;
      final DateTime? day = _workDay(task, first);
      if (day == null || day.isBefore(first)) {
        unplaced.add(task);
      } else {
        byDay[day]?.add(task);
      }
    }
    int minutesOf(List<TaskEntity> list) => list.fold<int>(
      0,
      (int sum, TaskEntity t) => sum + t.estimateOrDefault.inMinutes,
    );
    int withoutEstimate(List<TaskEntity> list) =>
        list.where((TaskEntity t) => !t.hasEstimate).length;
    int planned = 0;
    final List<WorkloadDay> out = <WorkloadDay>[
      for (final DateTime d in days)
        () {
          final List<TaskEntity> list = byDay[d]!;
          planned += list.length;
          return WorkloadDay(
            day: d,
            plannedMinutes: minutesOf(list),
            taskCount: list.length,
            withoutEstimateCount: withoutEstimate(list),
          );
        }(),
    ];
    return (
      days: PatternMetric<List<WorkloadDay>>(
        value: List<WorkloadDay>.unmodifiable(out),
        provenance: PatternProvenance.calculated,
        evidence: planned == 0
            ? const PatternEvidence.notEnough(
                reason: PatternEvidenceReason.noPlannedWork,
              )
            : PatternEvidence.enough(have: planned, need: 1),
      ),
      unplaced: PatternMetric<UnplacedWork>(
        value: UnplacedWork(
          taskCount: unplaced.length,
          plannedMinutes: minutesOf(unplaced),
          withoutEstimateCount: withoutEstimate(unplaced),
        ),
        provenance: PatternProvenance.calculated,
        evidence: unplaced.isEmpty
            ? const PatternEvidence.notEnough(
                reason: PatternEvidenceReason.noRecords,
              )
            : PatternEvidence.enough(have: unplaced.length, need: 1),
      ),
    );
  }

  static DateTime _periodEnd(HabitCadence cadence, DateTime start) =>
      switch (cadence) {
        HabitCadence.daily => oneTapAddDays(start, 1),
        HabitCadence.weekly => oneTapAddDays(start, 7),
        HabitCadence.monthly => DateTime(start.year, start.month + 1, 1),
      };

  static MissedItems _missed(
    List<TaskEntity> tasks,
    List<HabitPattern> habits,
    List<ActivityRecord> inRange,
    DateTime today,
    DateTime rangeStart,
  ) {
    final List<ActivityRecord> skipped = inRange
        .where(
          (ActivityRecord r) =>
              r.kind == ActivityKind.task &&
              r.outcome == ActivityOutcome.skipped,
        )
        .toList(growable: false);
    final List<TaskEntity> overdue = tasks
        .where(
          (TaskEntity t) => t.isActionableAt(today) && t.isOverdueAt(today),
        )
        .toList(growable: false);
    final List<HabitPeriodMiss> periods = <HabitPeriodMiss>[];
    for (final HabitPattern h in habits) {
      final HabitConsistency c = h.consistency;
      for (final HabitPeriod p in c.periods.take(c.windowPeriods)) {
        // Only periods that overlap the range: the wider window is for the
        // consistency figure, not for this list.
        if ((p.state == HabitPeriodState.missed ||
                p.state == HabitPeriodState.skipped) &&
            _periodEnd(c.cadence, p.start).isAfter(rangeStart)) {
          periods.add(
            HabitPeriodMiss(
              habitId: h.habitId,
              title: h.title,
              start: p.start,
              state: p.state,
            ),
          );
        }
      }
    }
    periods.sort((a, b) => b.start.compareTo(a.start));
    // Evidence counts: how many saved tasks (or habits) were looked at. With
    // none, an empty list says nothing; with some, an empty list is a result.
    PatternEvidence evidence(int looked, PatternEvidenceReason reason) =>
        looked > 0
        ? PatternEvidence.enough(have: looked, need: 1)
        : PatternEvidence.notEnough(reason: reason);
    return MissedItems(
      skippedTasks: PatternMetric<List<ActivityRecord>>(
        value: List<ActivityRecord>.unmodifiable(skipped),
        provenance: PatternProvenance.recorded,
        evidence: evidence(tasks.length, PatternEvidenceReason.noRecords),
      ),
      overdueTasks: PatternMetric<List<TaskEntity>>(
        value: List<TaskEntity>.unmodifiable(overdue),
        provenance: PatternProvenance.calculated,
        evidence: evidence(tasks.length, PatternEvidenceReason.noRecords),
      ),
      habitPeriods: PatternMetric<List<HabitPeriodMiss>>(
        value: List<HabitPeriodMiss>.unmodifiable(periods),
        provenance: PatternProvenance.calculated,
        evidence: evidence(habits.length, PatternEvidenceReason.noHabits),
      ),
    );
  }
}
