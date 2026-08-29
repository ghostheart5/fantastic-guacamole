import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves an explicit future schedule without repacking it', () {
    final DateTime now = DateTime(2026, 8, 20, 18);
    final DateTime scheduled = DateTime(2026, 8, 27, 18, 27);
    final TaskEntity task = TaskEntity(
      id: 'scheduled-task',
      title: 'Scheduled task',
      createdAt: now,
      scheduledFor: scheduled,
      estimatedDuration: const Duration(minutes: 45),
    );

    final DecisionRecommendation result = const DecisionEngine().recommend(
      tasks: <TaskEntity>[task],
      state: SiStateEntity(energy: .7, attention: .7, fatigue: .2),
      learning: LearningEntity(),
      now: now,
    );

    expect(result.plan.blocks, hasLength(1));
    expect(result.plan.blocks.single.taskId, task.id);
    expect(result.plan.blocks.single.start, scheduled);
    expect(
      result.plan.blocks.single.end,
      scheduled.add(const Duration(minutes: 45)),
    );
  });
}
