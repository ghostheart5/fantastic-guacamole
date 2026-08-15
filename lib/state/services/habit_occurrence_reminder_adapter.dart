import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';

/// Platform schedules are Habit-level repeating IDs, never occurrence IDs.
class HabitOccurrenceReminderAdapter {
  const HabitOccurrenceReminderAdapter();

  Future<void> reconcile(HabitOccurrence occurrence) async {
    // Completion/skip cannot cancel an occurrence-specific platform schedule.
    // Definition-level pause/resume/archive stays with ReminderOrchestratorService.
  }
}
