import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_connection_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class ConnectTimelineToHabitsUsecase {
  const ConnectTimelineToHabitsUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<HabitTimelineLink> call(HabitEntity habit) async {
    final DateTime now = DateTime.now();
    final String eventId =
        'habit_link_${habit.id}_${now.microsecondsSinceEpoch}';

    final TimelineEventEntity event = TimelineEventEntity(
      id: eventId,
      type: TimelineEventType.habit,
      title: habit.title.trim().isEmpty ? 'Habit linked' : habit.title.trim(),
      detail: (habit.description ?? 'Habit connected to timeline.').trim(),
      timestamp: now,
      status: habit.active
          ? TimelineEventStatus.active
          : TimelineEventStatus.info,
      relatedId: habit.id,
    );

    await AddTimelineEvent(_repository).call(event);

    return HabitTimelineLink(
      id: 'habit_timeline_link_${habit.id}_${now.microsecondsSinceEpoch}',
      timelineEventId: eventId,
      targetId: habit.id,
      createdAt: now,
      label: event.title,
    );
  }
}
