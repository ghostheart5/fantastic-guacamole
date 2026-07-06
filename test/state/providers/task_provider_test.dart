import 'dart:async';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/session_score_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initial state is loading then resolves empty safely', () async {
    final _DelayedTaskRepository repository = _DelayedTaskRepository();
    final ProviderContainer container = _buildTaskContainer(repository);
    addTearDown(container.dispose);

    final AsyncValue<List<Task>> initial = container.read(tasksProvider);
    expect(initial.isLoading, isTrue);

    repository.completeWith(const <TaskEntity>[]);
    final List<Task> result = await container.read(tasksProvider.future);
    expect(result, isEmpty);
  });

  test('repository failure becomes error state', () async {
    final _FailingTaskRepository repository = _FailingTaskRepository();
    final ProviderContainer container = _buildTaskContainer(repository);
    addTearDown(container.dispose);

    await expectLater(
      container.read(tasksProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  test('createQuickTask ignores blank titles', () async {
    final _MemoryTaskRepository repository = _MemoryTaskRepository();
    final ProviderContainer container = _buildTaskContainer(repository);
    addTearDown(container.dispose);

    await container.read(taskActionsProvider).createQuickTask('   ');

    expect(repository.saved, isEmpty);
  });

  test('create task updates provider state', () async {
    final _MemoryTaskRepository repository = _MemoryTaskRepository();
    final ProviderContainer container = _buildTaskContainer(repository);
    addTearDown(container.dispose);

    await container
        .read(taskActionsProvider)
        .createQuickTask('  Launch prep  ');

    final List<Task> tasks = await container.read(tasksProvider.future);
    expect(repository.saved, hasLength(1));
    final TaskEntity created = repository.saved.single;
    expect(created.title, 'Launch prep');
    expect(created.priority, 3);
    expect(created.isCompleted, isFalse);
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Launch prep');
  });

  test('complete task removes task from ranked incomplete list', () async {
    final _MemoryTaskRepository repository = _MemoryTaskRepository();
    final TaskEntity seed = TaskEntity(
      id: 'task-1',
      title: 'Ship feature',
      createdAt: DateTime.utc(2026, 7, 5),
      difficulty: 4,
      priority: 5,
      energyRequired: 3,
    );
    await repository.saveTask(seed);

    final ProviderContainer container = _buildTaskContainer(repository);
    addTearDown(container.dispose);

    expect(await container.read(tasksProvider.future), hasLength(1));
    await container
        .read(taskActionsProvider)
        .completeTask('task-1', notify: false);

    final TaskEntity? stored = await repository.getTaskById('task-1');
    expect(stored?.isCompleted, isTrue);
    expect(await container.read(tasksProvider.future), isEmpty);
    expect(container.read(sessionScoreProvider), isNotNull);
    expect(container.read(profileProvider).xp, greaterThan(0));
    expect(container.read(learningProvider).completed, 1);
    expect(container.read(siStateProvider).completedToday, 1);
  });

  test('refreshing does not duplicate tasks', () async {
    final _MemoryTaskRepository repository = _MemoryTaskRepository();
    await repository.saveTask(
      TaskEntity(
        id: 'task-refresh',
        title: 'Refresh once',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    final ProviderContainer container = _buildTaskContainer(repository);
    addTearDown(container.dispose);

    final List<Task> first = await container.read(tasksProvider.future);
    container.invalidate(tasksProvider);
    final List<Task> second = await container.read(tasksProvider.future);

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(second.single.id, first.single.id);
  });
}

ProviderContainer _buildTaskContainer(ITaskRepository repository) {
  return ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      getTasksUseCaseProvider.overrideWithValue(GetTasks(repository)),
      createTaskUseCaseProvider.overrideWithValue(CreateTask(repository)),
      completeTaskUseCaseProvider.overrideWithValue(CompleteTask(repository)),
      optimizationConfigProvider.overrideWith(
        (Ref ref) async => OptimizationConfig.neutral(),
      ),
      learningProvider.overrideWith(_FixedLearningController.new),
      profileProvider.overrideWith(_TestProfileController.new),
      siStateProvider.overrideWith(_FixedSiStateController.new),
    ],
  );
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  List<TaskEntity> get saved => _tasks.values.toList(growable: false);

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return saved;
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

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.8, fatigue: 0.2, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  void addXP(int amount) {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _DelayedTaskRepository implements ITaskRepository {
  final Completer<List<TaskEntity>> _completer = Completer<List<TaskEntity>>();

  void completeWith(List<TaskEntity> value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() => _completer.future;

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _FailingTaskRepository implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    throw StateError('failed to read tasks');
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}
