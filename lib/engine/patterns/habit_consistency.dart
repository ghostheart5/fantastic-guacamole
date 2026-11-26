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

  /// The real start of the period at local midnight: that day (daily), its
  /// Monday (weekly) or the 1st (monthly).
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
///
/// Judging starts at the period containing `frequencyStartedAt ?? createdAt`
/// and that first period is always judged, however late in it the habit was
/// made (a habit created at 23:50 with no check-in has that day missed), as in
/// the one-tap goals engine. The streaks are walked over the judged periods
/// only, so a streak can never exceed the periods judged. The gateway's own
/// streak is not clipped, so the two differ only for a habit with check-ins
/// older than its recorded start and no frequency edit.
///
/// A habit that was paused and resumed counts the paused periods as missed:
/// the habit has no pause history to exclude them with.
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

  /// The current period was skipped on purpose. It does not break the streak
  /// (as in the gateway) but it adds no day to it, so a screen can say so.
  bool get currentPeriodSkipped =>
      periods.first.state == HabitPeriodState.skipped;

  /// The most periods one read looks back over.
  static const int maxPeriods = 5000;

  static int defaultWindowPeriods(HabitCadence cadence) => switch (cadence) {
    HabitCadence.daily => 7,
    HabitCadence.weekly => 4,
    HabitCadence.monthly => 3,
  };

  /// Whole calendar days tracked up to [now], today included; at least 1 even
  /// when the recorded start is later than [now] (a clock that disagrees).
  int daysTracked(DateTime now) {
    final int days =
        oneTapDaysBetween(trackedSince.toLocal(), now.toLocal()) + 1;
    return days < 1 ? 1 : days;
  }

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
          start: _periodStart(habit.cadence, day),
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
    // Like the gateway, the open (or skipped) current period never breaks the
    // streak and a skipped or missed past one does, but the walk stops at the
    // first judged period and at 400 periods.
    int streak = 0;
    for (int i = checkedIn ? 0 : 1; i < periods.length && streak < 400; i++) {
      if (periods[i].state != HabitPeriodState.completed) break;
      streak++;
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
      longestStreak: longest,
    );
  }

  static DateTime _periodStart(HabitCadence cadence, DateTime day) =>
      switch (cadence) {
        HabitCadence.daily => DateTime(day.year, day.month, day.day),
        HabitCadence.weekly => DateTime(
          day.year,
          day.month,
          day.day - (day.weekday - DateTime.monday),
        ),
        HabitCadence.monthly => DateTime(day.year, day.month, 1),
      };
}
