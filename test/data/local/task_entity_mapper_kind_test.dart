import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips task kind for mission persistence', () {
    final TaskEntity original = TaskEntity(
      id: 'task-1',
      title: 'Mission task',
      kind: 'mission',
      createdAt: DateTime.utc(2026, 1, 1),
      recurrenceRule: RecurrenceRule.none,
    );

    final Map<String, dynamic> json = TaskEntityMapper.toJson(original);
    final TaskEntity decoded = TaskEntityMapper.fromJson(json);

    expect(decoded.kind, 'mission');
  });
}
