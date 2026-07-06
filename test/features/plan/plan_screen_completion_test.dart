import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/session_score_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'plan completion tap completes task, sets score, and opens insight',
    (WidgetTester tester) async {
      final _MemoryTaskRepository repository = _MemoryTaskRepository();
      final TaskEntity seedEntity = TaskEntity(
        id: 'task-1',
        title: 'Deep work block',
        createdAt: DateTime.utc(2026, 7, 5),
        priority: 4,
        difficulty: 4,
        energyRequired: 3,
      );
      await repository.saveTask(seedEntity);

      final Task seededTask = Task(
        id: seedEntity.id,
        title: seedEntity.title,
        priority: seedEntity.priority,
        difficulty: seedEntity.difficulty,
        energyRequired: seedEntity.energyRequired,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
          tasksProvider.overrideWith((Ref ref) async => <Task>[seededTask]),
          completeTaskUseCaseProvider.overrideWithValue(
            CompleteTask(repository),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlanScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final Finder completeCta = find.text('COMPLETE').first;
      await tester.scrollUntilVisible(
        completeCta,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(completeCta);
      await tester.pump(const Duration(milliseconds: 600));

      final TaskEntity? updatedTask = await repository.getTaskById(
        seedEntity.id,
      );
      expect(updatedTask, isNotNull);
      expect(updatedTask!.isCompleted, isTrue);
      expect(container.read(appFlowProvider), AppView.insight);

      final score = container.read(sessionScoreProvider);
      expect(score, isNotNull);
      expect(score!.xp, greaterThan(0));
    },
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
