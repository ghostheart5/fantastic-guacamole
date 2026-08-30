import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Calendar/timeline
///
/// Bound to TimelineRepository.
abstract class ITimelineRepository {
  bool get lastReadCorrupted;
  List<TimelineEventEntity> getEvents();
  Future<void> addEvent(TimelineEventEntity event);
  Future<void> saveEvents(List<TimelineEventEntity> events);
  Future<void> removeEvent(String id);
}

/// Optional capability for a read-transform-write operation serialized by the
/// persistence owner. Lifecycle use cases use this when available so a stale
/// caller snapshot cannot erase a concurrent Timeline write.
abstract interface class IAtomicTimelineRepository {
  Future<TimelineEventEntity?> updateEvent(
    String id,
    TimelineEventEntity Function(TimelineEventEntity current) transform,
  );
}
