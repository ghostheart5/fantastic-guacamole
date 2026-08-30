import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('terminal Timeline events are never projected as upcoming', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    TimelineEventEntity event(TimelineEventStatus status) =>
        TimelineEventEntity(
          id: status.name,
          type: TimelineEventType.task,
          title: status.name,
          detail: status.name,
          timestamp: now,
          status: status,
          dueAt: now.add(const Duration(hours: 1)),
        );

    expect(event(TimelineEventStatus.planned).isUpcomingAt(now), isTrue);
    expect(event(TimelineEventStatus.completed).isUpcomingAt(now), isFalse);
    expect(event(TimelineEventStatus.skipped).isUpcomingAt(now), isFalse);
    expect(event(TimelineEventStatus.canceled).isUpcomingAt(now), isFalse);
  });
}
