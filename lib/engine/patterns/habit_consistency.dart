import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/engine/si/si_one_tap_engine.dart'
    show oneTapAddDays, oneTapDaysBetween;

/// What happened in one period (day, week or month) of a habit.
enum HabitPeriodState {
  /// A check-in was recorded.
  completed,

  /// The person skipped the period on purpose.
  skipped,

  /// The period is over and nothing was recorded.
  missed,

  /// The current period: nothing is recorded yet and it is not over.
  open,
}

/// One period of a habit, newest first in [HabitConsistency.periods].
class HabitPeriod {
  const HabitPeriod({
    required this.key,
    required this.start,
    required this.state,
  });

  /// The stored occurrence key (includes the frequency revision).
  final String key;

  /// A local calendar day inside the period (the day it was reached from).
  final DateTime start;
  final HabitPeriodState state;
}

/// How consistently one habit was checked in, by its own cadence.
///
/// Pure and read-only. Definitions match the on-device read gateway: periods
/// are judged by [RhythmPlanningContext.occurrenceKey] (so a habit whose
/// frequency was edited is judged only on the periods since the edit), the
/// period still open never breaks the current streak, and only a check-in
/// counts toward a streak. Calendar-day arithmetic is used throughout so a
/// clock change never shifts a day.
class HabitConsistency {
  const HabitConsistency._({
    required this.habitId,
    required this.cadence,
    required this.trackedSince,
    required this.periods,
    required this.windowPeriods,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.checkedInThisPeriod,
    required this.currentStreak,
    required this.longestStreak,
  });

  final String habitId;
  final HabitCadence cadence;

  /// `frequencyStartedAt ?? createdAt`: where judging begins.
  final DateTime trackedSince;

  /// Every period from the one containing [trackedSince] to the current one,
  /// newest first. The first entry is the current period.
  final List<HabitPeriod> periods;

  /// How many periods the window judges (the current one included), fewer
  /// than requested when the habit is newer than the window.
  final int windowPeriods;
  final int completed;
  final int skipped;
  final int missed;

  /// Whether the current period has a check-in.
  final bool checkedInThisPeriod;
  final int currentStreak;
  final int longestStreak;

  /// Periods that are over since tracking began (everything but the current
  /// one).
  int get closedPeriodsSinceTracked => periods.length - 1;

  /// The current period has nothing recorded yet. It is not counted as missed.
  bool get currentPeriodOpen => periods.first.state == HabitPeriodState.open;

  /// The most periods one read looks back over.
  static const int maxPeriods = 5000;

  static int defaultWindowPeriods(HabitCadence cadence) => switch (cadence) {
    HabitCadence.daily => 7,
    HabitCadence.weekly => 4,
    HabitCadence.monthly => 3,
  };

  /// Whole calendar days tracked up to [now], today included.
  int daysTracked(DateTime now) =>
      oneTapDaysBetween(trackedSince.toLocal(), now.toLocal()) + 1;

  /// Null for a paused or archived habit (excluded).
  static HabitConsistency? compute({
    required HabitEntity habit,
    required Iterable<HabitOccurrenceEntity> occurrences,
    required DateTime now,
    int? windowPeriods,
  }) {
    if (habit.status != HabitStatus.active) return null;
    final DateTime today = now.toLocal();
    final Set<String> completedKeys = <String>{};
    final Set<String> skippedKeys = <String>{};
    for (final HabitOccurrenceEntity item in occurrences) {
      if (item.habitId != habit.id) continue;
      if (item.outcome == HabitOccurrenceOutcome.completed) {
        completedKeys.add(item.occurrenceKey);
      } else {
        skippedKeys.add(item.occurrenceKey);
      }
    }
    final DateTime trackedSince = (habit.frequencyStartedAt ?? habit.createdAt)
        .toUtc();
    final String firstKey = RhythmPlanningContext.periodKey(
      habit.cadence,
      trackedSince,
    );
    DateTime previous(DateTime day) => switch (habit.cadence) {
      HabitCadence.daily => oneTapAddDays(day, -1),
      HabitCadence.weekly => oneTapAddDays(day, -7),
      HabitCadence.monthly => DateTime(day.year, day.month - 1, 1),
    };

    final List<HabitPeriod> periods = <HabitPeriod>[];
    DateTime day = today;
    while (periods.length < maxPeriods) {
      final bool current = periods.isEmpty;
      // Plain period keys sort in time order, so this stops after the period
      // the habit was first tracked in (the current one is always judged).
      final String plain = RhythmPlanningContext.periodKey(habit.cadence, day);
      if (!current && plain.compareTo(firstKey) < 0) break;
      final String key = RhythmPlanningContext.occurrenceKey(habit, day);
      periods.add(
        HabitPeriod(
          key: key,
          start: day,
          state: completedKeys.contains(key)
              ? HabitPeriodState.completed
              : skippedKeys.contains(key)
              ? HabitPeriodState.skipped
              : current
              ? HabitPeriodState.open
              : HabitPeriodState.missed,
        ),
      );
      day = previous(day);
    }

    final int wanted = (windowPeriods ?? defaultWindowPeriods(habit.cadence))
        .clamp(1, maxPeriods);
    final int judged = wanted < periods.length ? wanted : periods.length;
    int completed = 0;
    int skipped = 0;
    int missed = 0;
    for (final HabitPeriod p in periods.take(judged)) {
      switch (p.state) {
        case HabitPeriodState.completed:
          completed++;
        case HabitPeriodState.skipped:
          skipped++;
        case HabitPeriodState.missed:
          missed++;
        case HabitPeriodState.open:
          break;
      }
    }

    final bool checkedIn = periods.first.state == HabitPeriodState.completed;
    // The same walk the read gateway does: the open period never breaks it, a
    // skipped or missed one does, and it stops at 400 periods.
    DateTime cursor = checkedIn ? today : previous(today);
    int streak = 0;
    while (streak < 400 &&
        completedKeys.contains(
          RhythmPlanningContext.occurrenceKey(habit, cursor),
        )) {
      streak++;
      cursor = previous(cursor);
    }
    int longest = 0;
    int run = 0;
    for (final HabitPeriod p in periods.reversed) {
      run = p.state == HabitPeriodState.completed ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    return HabitConsistency._(
      habitId: habit.id,
      cadence: habit.cadence,
      trackedSince: trackedSince,
      periods: List<HabitPeriod>.unmodifiable(periods),
      windowPeriods: judged,
      completed: completed,
      skipped: skipped,
      missed: missed,
      checkedInThisPeriod: checkedIn,
      currentStreak: streak,
      longestStreak: longest > streak ? longest : streak,
    );
  }
}
