import 'package:fantastic_guacamole/domain/value_objects/task_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskId', () {
    test('accepts non-empty value', () {
      final id = TaskId('task-123');
      expect(id.value, 'task-123');
    });

    test('rejects empty or whitespace-only value', () {
      expect(() => TaskId(''), throwsArgumentError);
      expect(() => TaskId('   '), throwsArgumentError);
    });
  });
}
