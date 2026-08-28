import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/domain/usecases/update_task.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'updateTask changes only the trimmed title and refreshes projections',
    () async {
      final _MemoryTaskRepository repository = _MemoryTaskRepository();
      final DateTime createdAt = DateTime.utc(2026, 8, 20, 10);
      final DateTime oldUpdatedAt = DateTime.utc(2026, 8, 21, 11);
      final DateTime scheduledFor = DateTime.utc(2026, 8, 28, 9);
      final DateTime dueDate = DateTime.utc(2026, 8, 29, 17);
      final TaskEntity original = TaskEntity(
        id: 'task-edit',
        title: 'Original title',
        description: 'Keep every persisted field',
        createdAt: createdAt,
        updatedAt: oldUpdatedAt,
        priority: 5,
        difficulty: 4,
        energyRequired: 2,
        estimatedDuration: const Duration(minutes: 75),
        scheduledFor: scheduledFor,
        occurrenceKey: 'v1:task-edit:occurrence',
        dueDate: dueDate,
        goalId: 'goal-1',
        subtasks: const <String>['subtask-1', 'subtask-2'],
        recurrenceRule: RecurrenceRule.weekly,
      );
      await repository.saveTask(original);
      final ProviderContainer container = _buildContainer(repository);
      addTearDown(container.dispose);

      expect(
        (await container.read(tasksProvider.future)).single.title,
        'Original title',
      );
      expect(
        (await container.read(
          goalProgressProvider('goal-1').future,
        )).tasks.single.title,
        'Original title',
      );

      await container
          .read(taskActionsProvider)
          .updateTask(id: original.id, title: '  Revised title  ');

      final TaskEntity stored = (await repository.getTaskById(original.id))!;
      expect(stored.id, original.id);
      expect(stored.title, 'Revised title');
      expect(stored.description, original.description);
      expect(stored.createdAt, createdAt);
      expect(stored.updatedAt, isNot(oldUpdatedAt));
      expect(stored.priority, original.priority);
      expect(stored.difficulty, original.difficulty);
      expect(stored.energyRequired, original.energyRequired);
      expect(stored.estimatedDuration, original.estimatedDuration);
      expect(stored.scheduledFor, scheduledFor);
      expect(stored.occurrenceKey, original.occurrenceKey);
      expect(stored.dueDate, dueDate);
      expect(stored.goalId, original.goalId);
      expect(stored.subtasks, original.subtasks);
      expect(stored.recurrenceRule, original.recurrenceRule);
      expect(
        (await container.read(tasksProvider.future)).single.title,
        'Revised title',
      );
      expect(
        (await container.read(
          goalProgressProvider('goal-1').future,
        )).tasks.single.title,
        'Revised title',
      );
    },
  );

  test('deleteTask removes the task and refreshes task projections', () async {
    final _MemoryTaskRepository repository = _MemoryTaskRepository();
    await repository.saveTask(
      TaskEntity(
        id: 'task-delete',
        title: 'Delete me',
        createdAt: DateTime.utc(2026, 8, 20),
        goalId: 'goal-1',
      ),
    );
    final ProviderContainer container = _buildContainer(repository);
    addTearDown(container.dispose);

    expect(await container.read(tasksProvider.future), hasLength(1));
    expect(
      (await container.read(goalProgressProvider('goal-1').future)).tasks,
      hasLength(1),
    );

    await container.read(taskActionsProvider).deleteTask('task-delete');

    expect(await repository.getTaskById('task-delete'), isNull);
    expect(await container.read(tasksProvider.future), isEmpty);
    expect(
      (await container.read(goalProgressProvider('goal-1').future)).tasks,
      isEmpty,
    );
  });
}

ProviderContainer _buildContainer(_MemoryTaskRepository repository) {
  return ProviderContainer(
    overrides: [
      domainTaskRepositoryProvider.overrideWithValue(repository),
      getTasksUseCaseProvider.overrideWithValue(GetTasks(repository)),
      updateTaskUseCaseProvider.overrideWithValue(UpdateTask(repository)),
      deleteTaskUseCaseProvider.overrideWithValue(DeleteTask(repository)),
      tasksProvider.overrideWith((Ref ref) async {
        final List<TaskEntity> entities = await repository.getAllTasks();
        return entities.map(Task.fromEntity).toList(growable: false);
      }),
    ],
  );
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}
