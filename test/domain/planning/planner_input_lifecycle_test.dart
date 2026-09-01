import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlannerInput preserves skipped state through every task bridge', () {
    final DateTime skippedAt = DateTime.utc(2026, 8, 30, 10);
    final TaskEntity skipped = TaskEntity(
      id: 'skipped',
      title: 'Skipped',
      createdAt: DateTime.utc(2026, 8, 30, 9),
      isSkipped: true,
      skippedAt: skippedAt,
    );

    final PlannerInput input = PlannerInputAdapter.fromTaskEntity(skipped);
    final TaskEntity canonical = input.toTaskEntity();
    final TaskEntity legacy = PlannerInputAdapter.toLegacyTask(input);

    expect(input.isSkipped, isTrue);
    expect(canonical.isSkipped, isTrue);
    expect(canonical.skippedAt, isNotNull);
    expect(legacy.isSkipped, isTrue);
    expect(legacy.skippedAt, isNotNull);
  });
}
