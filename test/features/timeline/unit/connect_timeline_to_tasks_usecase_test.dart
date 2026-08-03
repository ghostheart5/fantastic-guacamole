import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/connect_timeline_to_tasks_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingTimelineRepository implements ITimelineRepository {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    events.add(event);
  }

  @override
  List<TimelineEventEntity> getEvents() => List<TimelineEventEntity>.from(events);

  @override
  Future<void> removeEvent(String id) async {
    events.removeWhere((event) => event.id == id);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> updatedEvents) async {
    events
      ..clear()
      ..addAll(updatedEvents);
  }
}

void main() {
  group('ConnectTimelineToTasksUsecase', () {
    test('maps daily rhythm entries to habit timeline events', () async {
      final repository = _RecordingTimelineRepository();
      final usecase = ConnectTimelineToTasksUsecase(repository);
      final task = TaskEntity(
        id: 'habit-1',
        title: 'Morning reset',
        kind: 'habit',
        createdAt: DateTime(2024, 1, 1),
        recurrenceRule: RecurrenceRule.daily,
      );

      await usecase.call(task);

      expect(repository.events, hasLength(1));
      expect(repository.events.single.type, TimelineEventType.habit);
      expect(repository.events.single.title, startsWith('Habit: '));
    });
  });
}
