// CHRONOSPARK-CLASS: SHIPPING | Feature: Daily Rhythm planning
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';

enum RhythmPeriodStatus { unrecorded, completed, skipped, paused }

class RhythmPlanningEntry {
  const RhythmPlanningEntry(this.habit, this.periodKey, this.status);
  final HabitEntity habit;
  final String periodKey;
  final RhythmPeriodStatus status;
  bool get needsAttention => status == RhythmPeriodStatus.unrecorded;
}

abstract final class RhythmPlanningContext {
  static String periodKey(HabitCadence cadence, DateTime timestamp) {
    final local = timestamp.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final slot = cadence == HabitCadence.weekly
        ? day.subtract(Duration(days: local.weekday - DateTime.monday))
        : day;
    final month = slot.month.toString().padLeft(2, '0');
    return cadence == HabitCadence.monthly
        ? '${slot.year}-$month'
        : '${slot.year}-$month-${slot.day.toString().padLeft(2, '0')}';
  }

  static List<RhythmPlanningEntry> build(
    List<HabitEntity> habits,
    List<HabitOccurrenceEntity> outcomes,
    DateTime now,
  ) => [
    for (final habit in habits)
      RhythmPlanningEntry(
        habit,
        periodKey(habit.cadence, now),
        _status(habit, outcomes, now),
      ),
  ];

  static RhythmPeriodStatus _status(
    HabitEntity habit,
    List<HabitOccurrenceEntity> outcomes,
    DateTime now,
  ) {
    if (!habit.active) return RhythmPeriodStatus.paused;
    final key = periodKey(habit.cadence, now);
    for (final outcome in outcomes) {
      if (outcome.habitId == habit.id && outcome.occurrenceKey == key) {
        return outcome.outcome == HabitOccurrenceOutcome.completed
            ? RhythmPeriodStatus.completed
            : RhythmPeriodStatus.skipped;
      }
    }
    return RhythmPeriodStatus.unrecorded;
  }
}
