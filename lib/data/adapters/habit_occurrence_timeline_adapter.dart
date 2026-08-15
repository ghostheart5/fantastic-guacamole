import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

/// Projects canonical occurrence facts into Timeline without owning them.
class HabitOccurrenceTimelineAdapter {
  const HabitOccurrenceTimelineAdapter(this._timeline);

  final ITimelineRepository _timeline;

  Future<void> record(HabitOccurrence occurrence) async {
    final String id = eventIdFor(occurrence);
    if (_timeline.getEvents().any(
      (TimelineEventEntity event) => event.id == id,
    )) {
      return;
    }
    final bool completed = occurrence.status == HabitOccurrenceStatus.completed;
    final DateTime timestamp =
        (completed ? occurrence.completedAt : occurrence.skippedAt) ??
        DateTime.now();
    await _timeline.addEvent(
      TimelineEventEntity(
        id: id,
        type: completed
            ? TimelineEventType.habitCompleted
            : TimelineEventType.habitSkipped,
        title: completed ? 'Habit completed' : 'Habit skipped',
        detail:
            'habitId=${occurrence.habitId}; periodKey=${occurrence.periodKey}; ordinal=${occurrence.ordinal}; occurrenceId=${occurrence.id}; status=${occurrence.status.name}',
        timestamp: timestamp,
        status: completed
            ? TimelineEventStatus.completed
            : TimelineEventStatus.info,
        relatedId: occurrence.habitId,
      ),
    );
  }

  static String eventIdFor(HabitOccurrence occurrence) =>
      'habit-occurrence:${occurrence.id}:${occurrence.status.name}';
}
