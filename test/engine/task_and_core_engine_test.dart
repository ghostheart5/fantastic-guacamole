import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/core/si_core.dart';
import 'package:fantastic_guacamole/engine/tasks/task_filter.dart';
import 'package:fantastic_guacamole/engine/tasks/task_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime.utc(2026, 1, 1);
  late List<TaskEntity> tasks;

  setUp(() {
    tasks = <TaskEntity>[
      TaskEntity(
        id: 'hard',
        title: 'High-priority project',
        createdAt: createdAt,
        priority: 5,
        difficulty: 4,
        energyRequired: 4,
      ),
      TaskEntity(
        id: 'easy',
        title: 'Quick cleanup',
        createdAt: createdAt,
        priority: 2,
        difficulty: 1,
        energyRequired: 1,
      ),
      TaskEntity(
        id: 'done',
        title: 'Already finished',
        createdAt: createdAt,
        isCompleted: true,
      ),
    ];
  });

  test('task filter and ranker select an active task for the user state', () {
    final SiStateEntity state = SiStateEntity(
      energy: 0.8,
      focus: 0.7,
      fatigue: 0.2,
    );
    final List<TaskEntity> candidates = TaskFilter.bySiState(tasks, state);
    final List<RankedTask> ranked = const TaskRanker().rank(
      candidates,
      learning: const LearningState(),
      energy: state.energy,
      fatigue: state.fatigue,
      siState: state,
    );

    expect(
      candidates.map((TaskEntity task) => task.id),
      isNot(contains('done')),
    );
    expect(ranked.first.task.id, 'hard');
  });

  test('safety-first task filtering avoids overwhelming work', () {
    final SiStateEntity state = SiStateEntity(
      energy: 0.2,
      focus: 0.2,
      fatigue: 0.9,
      primaryInstinct: 'safety_first',
      avoidOverwhelm: true,
    );

    final List<TaskEntity> candidates = TaskFilter.bySiState(tasks, state);

    expect(candidates.map((TaskEntity task) => task.id), <String>['easy']);
  });

  test('modular SI core produces a response and retains pipeline memory', () {
    final SICore core = SICore();
    const Task task = Task(
      id: 'focus',
      title: 'Write the project outline',
      priority: 5,
      difficulty: 3,
      energyRequired: 3,
    );

    final SIPipelineResult first = core.run(
      input: const SIInputPacket(text: 'Help me start a focus session'),
      task: task,
    );
    final SIPipelineResult second = core.run(
      input: const SIInputPacket(text: 'What should I do next?'),
      task: task,
    );

    expect(first.response.task, same(task));
    expect(first.response.message, isNotEmpty);
    expect(second.memoryUpdate.store.snapshots, hasLength(2));
  });
}
