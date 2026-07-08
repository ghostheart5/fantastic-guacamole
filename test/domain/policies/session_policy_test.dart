import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/policies/session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionPolicy', () {
    test('canStart returns true for planned durations of 5 minutes or more', () {
      final session = SessionEntity(
        id: 's1',
        taskId: 't1',
        startedAt: DateTime.utc(2026, 7, 5),
        plannedDuration: const Duration(minutes: 5),
      );

      expect(SessionPolicy.canStart(session), isTrue);
    });

    test('canStart returns false when planned duration is under 5 minutes', () {
      final session = SessionEntity(
        id: 's2',
        taskId: 't1',
        startedAt: DateTime.utc(2026, 7, 5),
        plannedDuration: const Duration(minutes: 4),
      );

      expect(SessionPolicy.canStart(session), isFalse);
    });

    test('canEnd returns true only when endedAt is null', () {
      final open = SessionEntity(
        id: 's3',
        taskId: 't1',
        startedAt: DateTime.utc(2026, 7, 5),
        plannedDuration: const Duration(minutes: 15),
      );
      final closed = SessionEntity(
        id: 's4',
        taskId: 't1',
        startedAt: DateTime.utc(2026, 7, 5),
        endedAt: DateTime.utc(2026, 7, 5, 0, 15),
        plannedDuration: const Duration(minutes: 15),
      );

      expect(SessionPolicy.canEnd(open), isTrue);
      expect(SessionPolicy.canEnd(closed), isFalse);
    });
  });
}
