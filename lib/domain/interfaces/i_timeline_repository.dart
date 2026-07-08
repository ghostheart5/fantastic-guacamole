import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';

abstract class ITimelineRepository {
  List<TimelineEventEntity> getEvents();
  Future<void> addEvent(TimelineEventEntity event);
  Future<void> saveEvents(List<TimelineEventEntity> events);
  Future<void> removeEvent(String id);
}
