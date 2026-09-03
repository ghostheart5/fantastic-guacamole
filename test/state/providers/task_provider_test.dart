import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/completion_side_effect_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_score_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
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

  test(
    'signed-out and unsafe scopes do not read account task storage',
    () async {
      for (final AccountStorageScope scope in <AccountStorageScope>[
        const AccountStorageScope.signedOut(),
        const AccountStorageScope.unsafe(),
      ]) {
        final _MemoryTaskRepository repository = _MemoryTaskRepository();
        final ProviderContainer container = _buildTaskContainer(
          repository,
          scope: scope,
        );

        expect(await container.read(tasksProvider.future), isEmpty);
        expect(repository.readCount, 0);
        container.dispose();
      }
    },
  );

  test('authentication refreshes a gated task read', () async {
    final _MemoryTaskRepository repository = _MemoryTaskRepository();
    final ProviderContainer container = _buildTaskContainer(
      repository,
      mutableScope: true,
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider.future);
    expect(repository.readCount, 0);

    container.read(_testAccountStorageScopeProvider.notifier).authenticate();
    await container.read(tasksProvider.future);

    expect(repository.readCount, 1);
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
    expect(container.read(completionScoreProvider), isNotNull);
    expect(container.read(profileProvider).xp, greaterThan(0));
    expect(container.read(learningProvider).completed, 1);
    expect(container.read(siStateProvider).completedToday, 1);
  });

  test(
    'complete task waits for canonical local side effects before returning',
    () async {
      final _MemoryTaskRepository repository = _MemoryTaskRepository();
      await repository.saveTask(
        TaskEntity(
          id: 'task-side-effects',
          title: 'Persist the completion loop',
          createdAt: DateTime.utc(2026, 9, 3),
          difficulty: 3,
          priority: 4,
        ),
      );
      final _BlockingLocalMetricsAccumulator metrics =
          _BlockingLocalMetricsAccumulator();
      final ProviderContainer container = _buildTaskContainer(
        repository,
        metricsAccumulator: metrics,
      );
      addTearDown(container.dispose);
      expect(await container.read(tasksProvider.future), hasLength(1));

      bool returned = false;
      final Future<void> completion = container
          .read(taskActionsProvider)
          .completeTask('task-side-effects', notify: false)
          .whenComplete(() => returned = true);

      await metrics.recordingStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(
        returned,
        isFalse,
        reason:
            'The completion future must not report success while its canonical '
            'local feedback loop is still pending.',
      );

      metrics.allowRecordingToFinish.complete();
      await completion;

      expect(returned, isTrue);
      expect(metrics.completedCount, 1);
    },
  );

  test(
    'complete task recovers task details from repository when provider list is stale',
    () async {
      final _MemoryTaskRepository repository = _MemoryTaskRepository();
      final TaskEntity seed = TaskEntity(
        id: 'task-stale',
        title: 'Recover score context',
        createdAt: DateTime.utc(2026, 7, 6),
        difficulty: 3,
        priority: 4,
        energyRequired: 3,
      );
      await repository.saveTask(seed);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('account-1'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
          tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
          domainTaskRepositoryProvider.overrideWithValue(repository),
          completeTaskUseCaseProvider.overrideWithValue(
            CompleteTask(repository),
          ),
          optimizationConfigProvider.overrideWith(
            (Ref ref) async => OptimizationConfig.neutral(),
          ),
          learningProvider.overrideWith(_FixedLearningController.new),
          profileProvider.overrideWith(_TestProfileController.new),
          siStateProvider.overrideWith(_FixedSiStateController.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(taskActionsProvider)
          .completeTask('task-stale', notify: false);

      final TaskEntity? stored = await repository.getTaskById('task-stale');
      expect(stored?.isCompleted, isTrue);
      final score = container.read(completionScoreProvider);
      expect(score, isNotNull);
      expect(score!.xp, greaterThan(0));
    },
  );

  test(
    'idempotent durable completion suppresses provider side effects',
    () async {
      final _MemoryTaskRepository repository = _MemoryTaskRepository();
      await repository.saveTask(
        TaskEntity(
          id: 'task-replay',
          title: 'Already completed',
          createdAt: DateTime.utc(2026, 7, 6),
          difficulty: 5,
          priority: 5,
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('account-1'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
          getTasksUseCaseProvider.overrideWithValue(GetTasks(repository)),
          domainTaskRepositoryProvider.overrideWithValue(repository),
          completeTaskUseCaseProvider.overrideWithValue(
            CompleteTask(
              repository,
              durableMutation: (_) async =>
                  CompletionMutationOutcome.idempotent,
            ),
          ),
          optimizationConfigProvider.overrideWith(
            (Ref ref) async => OptimizationConfig.neutral(),
          ),
          learningProvider.overrideWith(_FixedLearningController.new),
          profileProvider.overrideWith(_TestProfileController.new),
          siStateProvider.overrideWith(_FixedSiStateController.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(taskActionsProvider)
          .completeTask('task-replay', notify: false);

      expect(container.read(completionScoreProvider), isNull);
      expect(container.read(profileProvider).xp, 0);
      expect(container.read(learningProvider).completed, 0);
      expect(container.read(siStateProvider).completedToday, 0);
      expect(
        (await repository.getTaskById('task-replay'))?.isCompleted,
        isFalse,
      );
    },
  );

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

ProviderContainer _buildTaskContainer(
  ITaskRepository repository, {
  AccountStorageScope? scope,
  bool mutableScope = false,
  LocalMetricsAccumulator? metricsAccumulator,
}) {
  return ProviderContainer(
    overrides: [
      if (mutableScope)
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_testAccountStorageScopeProvider),
        ),
      if (!mutableScope)
        accountStorageScopeProvider.overrideWithValue(
          scope ?? AccountStorageScope.authenticated('account-1'),
        ),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.provenNotOwned,
      ),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      getTasksUseCaseProvider.overrideWithValue(GetTasks(repository)),
      createTaskUseCaseProvider.overrideWithValue(CreateTask(repository)),
      completeTaskUseCaseProvider.overrideWithValue(CompleteTask(repository)),
      optimizationConfigProvider.overrideWith(
        (Ref ref) async => OptimizationConfig.neutral(),
      ),
      if (metricsAccumulator != null)
        localMetricsAccumulatorProvider.overrideWithValue(metricsAccumulator),
      learningProvider.overrideWith(_FixedLearningController.new),
      profileProvider.overrideWith(_TestProfileController.new),
      siStateProvider.overrideWith(_FixedSiStateController.new),
    ],
  );
}

final NotifierProvider<_TestAccountStorageScopeController, AccountStorageScope>
_testAccountStorageScopeProvider =
    NotifierProvider<_TestAccountStorageScopeController, AccountStorageScope>(
      _TestAccountStorageScopeController.new,
    );

class _TestAccountStorageScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.signedOut();

  void authenticate() {
    state = AccountStorageScope.authenticated('account-1');
  }
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  int readCount = 0;

  List<TaskEntity> get saved => _tasks.values.toList(growable: false);

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    readCount += 1;
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
  Future<void> addXP(int amount) async {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _BlockingLocalMetricsAccumulator extends LocalMetricsAccumulator {
  final Completer<void> recordingStarted = Completer<void>();
  final Completer<void> allowRecordingToFinish = Completer<void>();
  int completedCount = 0;

  @override
  Future<void> recordTaskCompleted() async {
    if (!recordingStarted.isCompleted) {
      recordingStarted.complete();
    }
    await allowRecordingToFinish.future;
    completedCount += 1;
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
