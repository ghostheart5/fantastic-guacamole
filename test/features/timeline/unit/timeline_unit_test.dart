import 'package:fantastic_guacamole/domain/entities/timeline_connection_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelineEventEntity', () {
    test('semantic helpers classify milestone/risk/recommendation events', () {
      final TimelineEventEntity milestone = TimelineEventEntity(
        id: '1',
        type: TimelineEventType.levelUp,
        title: 'Level up',
        detail: 'Reached level 4.',
        timestamp: DateTime.now(),
      );
      final TimelineEventEntity risk = TimelineEventEntity(
        id: '2',
        type: TimelineEventType.risk,
        title: 'Risk',
        detail: 'Overdue tasks accumulating.',
        timestamp: DateTime.now(),
      );

      expect(milestone.isMilestone, isTrue);
      expect(milestone.shortLabel, 'Level Up');
      expect(risk.isRisk, isTrue);
      expect(risk.isRecommendation, isFalse);
    });

    test('upcoming and overdue flags align with dueAt/status', () {
      final TimelineEventEntity upcoming = TimelineEventEntity(
        id: '3',
        type: TimelineEventType.deadline,
        title: 'Deadline soon',
        detail: 'Ship docs.',
        timestamp: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 2)),
        status: TimelineEventStatus.active,
      );
      final TimelineEventEntity overdue = TimelineEventEntity(
        id: '4',
        type: TimelineEventType.deadline,
        title: 'Overdue',
        detail: 'Missed checkpoint.',
        timestamp: DateTime.now(),
        dueAt: DateTime.now().subtract(const Duration(days: 1)),
        status: TimelineEventStatus.overdue,
      );

      expect(upcoming.isUpcoming, isTrue);
      expect(overdue.isOverdue, isTrue);
    });

    test('json roundtrip preserves timeline event payload', () {
      final TimelineEventEntity original = TimelineEventEntity(
        id: '5',
        type: TimelineEventType.snapshot,
        title: 'Snapshot',
        detail: 'Status snapshot.',
        timestamp: DateTime(2026, 8, 1),
        status: TimelineEventStatus.info,
        phase: 'p1',
        relatedId: 'goal-1',
      );

      final TimelineEventEntity decoded = TimelineEventEntity.fromJson(
        original.toJson(),
      );
      expect(decoded.id, original.id);
      expect(decoded.type, original.type);
      expect(decoded.phase, original.phase);
      expect(decoded.relatedId, original.relatedId);
    });

    test('validate enforces overdue dueAt invariant', () {
      final TimelineEventEntity invalid = TimelineEventEntity(
        id: '6',
        type: TimelineEventType.deadline,
        title: 'Broken',
        detail: 'No due date.',
        timestamp: DateTime.now(),
        status: TimelineEventStatus.overdue,
      );

      expect(invalid.validate, throwsStateError);
    });
  });

  group('TimelineConnectionEntity', () {
    test('json parsing maps known type and defaults unknown type to goal', () {
      final TimelineConnectionEntity taskLink =
          TimelineConnectionEntity.fromJson(<String, dynamic>{
            'id': 'c1',
            'timelineEventId': 'e1',
            'targetId': 't1',
            'type': 'task',
            'createdAt': '2026-08-01T00:00:00.000Z',
          });

      final TimelineConnectionEntity fallback =
          TimelineConnectionEntity.fromJson(<String, dynamic>{
            'id': 'c2',
            'timelineEventId': 'e2',
            'targetId': 't2',
            'type': 'unknown',
            'createdAt': 'bad-date',
          });

      expect(taskLink.type, TimelineConnectionType.task);
      expect(fallback.type, TimelineConnectionType.goal);
    });
  });
}
