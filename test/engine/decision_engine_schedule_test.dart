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

  test('terminal tasks never re-enter decision candidates or plan blocks', () {
    final DateTime now = DateTime(2026, 8, 20, 8);
    TaskEntity task(
      String id, {
      bool completed = false,
      bool skipped = false,
      bool canceled = false,
    }) => TaskEntity(
      id: id,
      title: id,
      createdAt: now,
      isCompleted: completed,
      completedAt: completed ? now : null,
      isSkipped: skipped,
      skippedAt: skipped ? now : null,
      isCanceled: canceled,
      estimatedDuration: const Duration(minutes: 30),
    );

    final DecisionRecommendation result = const DecisionEngine().recommend(
      tasks: <TaskEntity>[
        task('open'),
        task('completed', completed: true),
        task('skipped', skipped: true),
        task('canceled', canceled: true),
      ],
      state: SiStateEntity(energy: .7, attention: .7, fatigue: .2),
      learning: LearningEntity(),
      now: now,
    );

    expect(result.selectedTask?.id, 'open');
    expect(result.orderedTasks.map((TaskEntity item) => item.id), <String>[
      'open',
    ]);
    expect(result.plan.blocks.map((block) => block.taskId), <String>['open']);
  });
}
