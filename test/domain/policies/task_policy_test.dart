import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskPolicy', () {
    test('isValid returns true for non-empty title and priority in range', () {
      final task = TaskEntity(
        id: 't1',
        title: 'Write tests',
        createdAt: DateTime.utc(2026, 7, 5),
        priority: 3,
      );

      expect(TaskPolicy.isValid(task), isTrue);
    });

    test('isValid returns false for empty title', () {
      final task = TaskEntity(
        id: 't2',
        title: '   ',
        createdAt: DateTime.utc(2026, 7, 5),
        priority: 3,
      );

      expect(TaskPolicy.isValid(task), isFalse);
    });

    test('isValid returns false for priority outside 1-5', () {
      final low = TaskEntity(
        id: 't3',
        title: 'Low',
        createdAt: DateTime.utc(2026, 7, 5),
        priority: 0,
      );
      final high = TaskEntity(
        id: 't4',
        title: 'High',
        createdAt: DateTime.utc(2026, 7, 5),
        priority: 6,
      );

      expect(TaskPolicy.isValid(low), isFalse);
      expect(TaskPolicy.isValid(high), isFalse);
    });

    test('canComplete returns true only when task is not completed', () {
      final open = TaskEntity(id: 't5', title: 'Open', createdAt: DateTime.utc(2026, 7, 5));
      final done = TaskEntity(
        id: 't6',
        title: 'Done',
        createdAt: DateTime.utc(2026, 7, 5),
        isCompleted: true,
      );

      expect(TaskPolicy.canComplete(open), isTrue);
      expect(TaskPolicy.canComplete(done), isFalse);
    });
  });
}
