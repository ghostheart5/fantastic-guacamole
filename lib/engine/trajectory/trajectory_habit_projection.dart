import 'dart:math' as math;

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/patterns/habit_consistency.dart';

/// Habits in the forecast: one projected line per active habit. Pure.
///
/// Rules (stated so the screen can say them plainly):
/// - Rate: check-ins over the habit's most recent closed periods under its
///   current frequency revision: the last 28 closed days (daily), the last 4
///   closed weeks, 28 days (weekly), or the last 3 closed months (monthly,
///   because 28 days hold fewer than 3 months). The open current period is
///   never judged. Skipped and missed periods count as not done.
/// - At least [minimumClosedPeriods] closed periods are needed; with fewer the
///   line says "not enough history" with have / need and projects nothing.
/// - Periods in the range: daily H, weekly ceil(H / 7), monthly ceil(H / 30).
/// - Projected check-ins: mid = round(rate x periods) (halves round up),
///   low / high = mid -/+ ceil(sqrt(mid)), kept within 0..periods. An
///   estimate, never a promise.
///
/// Paused and archived habits are left out (HabitConsistency returns null).
/// These lines never feed workload, momentum, risk, the ranking or the
/// recommendation.
abstract final class TrajectoryHabitProjection {
  static const int minimumClosedPeriods = 3;

  /// How many of the most recent closed periods the rate looks at.
  static int lookBackPeriods(HabitCadence cadence) => switch (cadence) {
    HabitCadence.daily => 28,
    HabitCadence.weekly => 4,
    HabitCadence.monthly => 3,
  };

  /// The habit's periods in a range of [horizonDays] days.
  static int expectedPeriods(HabitCadence cadence, int horizonDays) {
    final int days = math.max(1, horizonDays);
    return switch (cadence) {
      HabitCadence.daily => days,
      HabitCadence.weekly => (days / 7).ceil(),
      HabitCadence.monthly => (days / 30).ceil(),
    };
  }

  /// The line for one habit, or null when it is paused or archived.
  static TrajectoryHabitNode? node({
    required HabitEntity habit,
    required Iterable<HabitOccurrenceEntity> occurrences,
    required DateTime now,
    required int horizonDays,
  }) {
    final HabitConsistency? consistency = HabitConsistency.compute(
      habit: habit,
      occurrences: occurrences,
      now: now,
    );
    if (consistency == null) return null;
    // periods is newest first and its first entry is the open current one.
    final List<HabitPeriod> closed = consistency.periods
        .skip(1)
        .take(lookBackPeriods(habit.cadence))
        .toList(growable: false);
    final int completed = closed
        .where((HabitPeriod p) => p.state == HabitPeriodState.completed)
        .length;
    final int periods = expectedPeriods(habit.cadence, horizonDays);
    final bool enough = closed.length >= minimumClosedPeriods;
    TrajectoryExpectedCompletions? projected;
    if (enough) {
      final int mid = (completed * periods / closed.length).round().clamp(
        0,
        periods,
      );
      final int spread = math.sqrt(mid).ceil();
      projected = TrajectoryExpectedCompletions(
        low: math.max(0, mid - spread),
        mid: mid,
        high: math.min(periods, mid + spread),
      );
    }
    return TrajectoryHabitNode(
      habitId: habit.id,
      title: habit.title,
      cadence: habit.cadence,
      closedPeriodsJudged: closed.length,
      completedPeriods: completed,
      rate: enough ? completed / closed.length : null,
      expectedPeriods: periods,
      projectedCheckIns: projected,
      checkedInThisPeriod: consistency.checkedInThisPeriod,
      evidence: enough
          ? TrajectoryHabitEvidence.enough
          : TrajectoryHabitEvidence.notEnoughHistory,
      historyNeeded: minimumClosedPeriods,
    );
  }

  /// Lines for every active habit, ordered by title then id.
  static List<TrajectoryHabitNode> nodes({
    required List<HabitEntity> habits,
    required List<HabitOccurrenceEntity> occurrences,
    required DateTime now,
    required int horizonDays,
  }) {
    final List<TrajectoryHabitNode> output = <TrajectoryHabitNode>[];
    for (final HabitEntity habit in habits) {
      final TrajectoryHabitNode? line = node(
        habit: habit,
        occurrences: occurrences,
        now: now,
        horizonDays: horizonDays,
      );
      if (line != null) output.add(line);
    }
    output.sort((TrajectoryHabitNode a, TrajectoryHabitNode b) {
      final int byTitle = a.title.compareTo(b.title);
      return byTitle != 0 ? byTitle : a.habitId.compareTo(b.habitId);
    });
    return List<TrajectoryHabitNode>.unmodifiable(output);
  }

  /// What the lines rest on, for the comparison's source revisions; null when
  /// there are no lines (so a person without habits keeps the same revision).
  static String? revision(List<TrajectoryHabitNode> nodes) {
    if (nodes.isEmpty) return null;
    return nodes
        .map(
          (TrajectoryHabitNode n) =>
              '${n.habitId}:${n.cadence.name}:${n.closedPeriodsJudged}:'
              '${n.completedPeriods}:${n.expectedPeriods}:'
              '${n.checkedInThisPeriod ? 1 : 0}',
        )
        .join('|');
  }

  /// One evidence line per habit (data; the screen writes the sentences).
  static String evidenceLine(TrajectoryHabitNode n) {
    final String head = 'habit=${n.habitId}:${n.cadence.name}';
    final TrajectoryExpectedCompletions? p = n.projectedCheckIns;
    if (n.evidence == TrajectoryHabitEvidence.notEnoughHistory || p == null) {
      return '$head:not_enough_history:${n.closedPeriodsJudged}/'
          '${n.historyNeeded}:expected=${n.expectedPeriods}';
    }
    return '$head:enough:${n.completedPeriods}/${n.closedPeriodsJudged}:'
        'expected=${n.expectedPeriods}:check_ins=${p.low}-${p.mid}-${p.high}';
  }
}
