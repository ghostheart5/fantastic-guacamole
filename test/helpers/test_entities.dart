import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

TaskEntity testTask({
  String id = 'task-1',
  String title = 'Test Task',
  int priority = 3,
  int difficulty = 3,
  int energyRequired = 3,
  bool isCompleted = false,
}) {
  return TaskEntity(
    id: id,
    title: title,
    createdAt: DateTime.utc(2026, 1, 1),
    priority: priority,
    difficulty: difficulty,
    energyRequired: energyRequired,
    isCompleted: isCompleted,
  );
}

SiStateEntity testSiState({
  double energy = 0.6,
  double focus = 0.6,
  double fatigue = 0.3,
  String mood = 'neutral',
  double confidence = 0.5,
}) {
  return SiStateEntity(
    energy: energy,
    focus: focus,
    fatigue: fatigue,
    mood: mood,
    confidence: confidence,
  );
}

CalendarEntryEntity testCalendarEntry({
  String id = 'entry-1',
  String title = 'Test Entry',
  DateTime? start,
  DateTime? end,
  String? taskId,
}) {
  final DateTime startTime = start ?? DateTime.utc(2026, 1, 1, 9);
  final DateTime endTime = end ?? startTime.add(const Duration(minutes: 30));

  return CalendarEntryEntity(id: id, title: title, start: startTime, end: endTime, taskId: taskId);
}
