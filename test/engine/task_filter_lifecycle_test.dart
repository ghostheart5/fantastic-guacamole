import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/tasks/task_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task filters never return completed, skipped, or canceled tasks', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    TaskEntity task(
      String id, {
      bool completed = false,
      bool skipped = false,
      bool canceled = false,
    }) => TaskEntity(
      id: id,
      title: id,
      createdAt: now.subtract(const Duration(hours: 1)),
      isCompleted: completed,
      completedAt: completed ? now : null,
      isSkipped: skipped,
      skippedAt: skipped ? now : null,
      isCanceled: canceled,
      dueDate: now.subtract(const Duration(minutes: 1)),
      scheduledFor: now,
      goalId: 'goal',
    );
    final List<TaskEntity> tasks = <TaskEntity>[
      task('open'),
      task('completed', completed: true),
      task('skipped', skipped: true),
      task('canceled', canceled: true),
    ];

    expect(TaskFilter.incomplete(tasks, now: now).single.id, 'open');
    expect(TaskFilter.overdue(tasks, now: now).single.id, 'open');
    expect(TaskFilter.forEnergy(tasks, .6, now: now).single.id, 'open');
    expect(TaskFilter.byMaxEnergy(tasks, 1, now: now).single.id, 'open');
    expect(
      TaskFilter.byDifficultyRange(tasks, 1, 5, now: now).single.id,
      'open',
    );
    expect(TaskFilter.scheduled(tasks, now).single.id, 'open');
    expect(TaskFilter.forGoal(tasks, 'goal', now: now).single.id, 'open');
  });
}
