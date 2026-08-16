import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_projection_work_repository.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_projection_work.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }
}

class _Queue implements SyncQueueStoreContract {
  final List<SyncOperation> values = <SyncOperation>[];

  @override
  Future<void> enqueue(SyncOperation operation) async => values.add(operation);

  @override
  Future<void> overwrite(List<SyncOperation> operations) async {
    values
      ..clear()
      ..addAll(operations);
  }

  @override
  Future<List<SyncOperation>> readAll() async =>
      List<SyncOperation>.from(values);

  @override
  Future<void> removeById(String operationId) async => values.removeWhere(
    (SyncOperation item) => item.operationId == operationId,
  );

  @override
  Future<void> update(SyncOperation updated) => overwrite(
    values
        .map(
          (SyncOperation item) =>
              item.operationId == updated.operationId ? updated : item,
        )
        .toList(growable: false),
  );
}

class _Tasks implements ITaskRepository {
  _Tasks(this.task);
  TaskEntity task;
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[task];
  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      id == task.id ? task : null;
  @override
  Future<void> saveTask(TaskEntity value) async {
    task = value;
  }
}

class _Occurrences extends TaskOccurrenceRepository {
  _Occurrences() : super.unavailable();

  final Map<String, TaskOccurrence> values = <String, TaskOccurrence>{};

  @override
  Future<void> cancelAndDrain() async {}

  @override
  Future<TaskOccurrence?> getOccurrence(String taskId, String occurrenceKey) =>
      Future<TaskOccurrence?>.value(
        values[TaskOccurrence.occurrenceId(taskId, occurrenceKey)],
      );

  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) =>
      Future<List<TaskOccurrence>>.value(
        values.values
            .where((TaskOccurrence item) => item.taskId == taskId)
            .toList(growable: false),
      );

  @override
  Future<void> save(TaskOccurrence occurrence) async {
    values[occurrence.id] = occurrence;
  }
}

class _ProjectionWork extends TaskOccurrenceProjectionWorkRepository {
  _ProjectionWork() : super.unavailable();

  final Map<String, TaskOccurrenceProjectionWork> values =
      <String, TaskOccurrenceProjectionWork>{};

  @override
  Future<void> cancelAndDrain() async {}

  @override
  Future<TaskOccurrenceProjectionWork?> getById(String id) =>
      Future<TaskOccurrenceProjectionWork?>.value(values[id]);

  @override
  Future<List<TaskOccurrenceProjectionWork>> listPending() =>
      Future<List<TaskOccurrenceProjectionWork>>.value(
        values.values
            .where(
              (TaskOccurrenceProjectionWork work) => work.stages.values.any(
                (TaskOccurrenceProjectionStageState state) =>
                    state == TaskOccurrenceProjectionStageState.pending,
              ),
            )
            .toList(growable: false),
      );

  @override
  Future<void> save(TaskOccurrenceProjectionWork work) async {
    values[work.id] = work;
  }
}

class _Profile extends ProfileController {
  @override
  ProfileState build() => ProfileState(profileReady: true);

  @override
  void addXP(int amount) {}
}

class _Learning extends LearningController {
  @override
  LearningState build() => const LearningState();
  @override
  Future<void> update({required bool success, required int difficulty}) async {}
}

class _Logs extends LogsActions {
  _Logs(super.ref);
  @override
  Future<void> addMirroredEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
  }) async {}
  @override
  Future<void> addCompletedTask({
    required String task,
    bool mirrored = false,
    bool updateInsights = false,
    bool syncSoulMap = false,
  }) async {}
}

TaskEntity _entity() => TaskEntity(
  id: 'complete-a',
  title: 'Complete under A',
  createdAt: DateTime.utc(2026, 8, 13),
  priority: 3,
  difficulty: 2,
  energyRequired: 2,
);
Task _task(TaskEntity value) => Task(
  id: value.id,
  title: value.title,
  priority: value.priority,
  difficulty: value.difficulty,
  energyRequired: value.energyRequired,
);

ProviderContainer _container(
  _Store store,
  AccountStorageScope scope,
  _Tasks tasks, {
  _Occurrences? occurrences,
  _ProjectionWork? projectionWork,
  SyncMutationDispatcher? syncDispatcher,
}) {
  final _Occurrences activeOccurrences = occurrences ?? _Occurrences();
  final _ProjectionWork activeProjectionWork =
      projectionWork ?? _ProjectionWork();
  return ProviderContainer(
    overrides: [
      sensitivePrefsStoreProvider.overrideWithValue(store),
      accountStorageScopeProvider.overrideWith((Ref ref) => scope),
      domainTaskRepositoryProvider.overrideWithValue(tasks),
      taskOccurrenceRepositoryProvider.overrideWithValue(activeOccurrences),
      taskOccurrenceProjectionWorkRepositoryProvider.overrideWithValue(
        activeProjectionWork,
      ),
      if (syncDispatcher != null)
        syncMutationDispatcherProvider.overrideWithValue(syncDispatcher),
      taskOccurrenceCoordinatorProvider.overrideWithValue(
        TaskOccurrenceCoordinator(
          scope: scope,
          taskRepository: tasks,
          occurrenceRepository: activeOccurrences,
        ),
      ),
      tasksProvider.overrideWith((Ref ref) async => <Task>[_task(tasks.task)]),
      profileProvider.overrideWith(_Profile.new),
      learningProvider.overrideWith(_Learning.new),
      logsActionsProvider.overrideWith((Ref ref) => _Logs(ref)),
    ],
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'PRE-TEST-02E1 complete command persists through real Timeline path to scoped V2 storage',
    () async {
      final _Store store = _Store();
      const String legacy = '[{"legacy":"timeline-sentinel"}]';
      store.values['timeline_events_v1'] = legacy;
      final AccountStorageScope a = AccountStorageScope.authenticated(
        'account-a',
      );
      final AccountStorageScope b = AccountStorageScope.authenticated(
        'account-b',
      );
      final _Tasks tasks = _Tasks(_entity());
      final ProviderContainer containerA = _container(store, a, tasks);
      addTearDown(containerA.dispose);

      await containerA
          .read(taskActionsProvider)
          .completeTask('complete-a', notify: false);
      await _settle();
      final String keyA = 'timeline_events_v2.${a.v2Namespace}';
      final String keyB = 'timeline_events_v2.${b.v2Namespace}';
      expect(store.values[keyA], contains('taskCompleted'));
      expect(store.values[keyB], isNull);
      expect(store.values['timeline_events_v1'], legacy);

      final ProviderContainer containerB = _container(
        store,
        b,
        _Tasks(_entity()),
      );
      addTearDown(containerB.dispose);
      expect(containerB.read(timelineProvider), isEmpty);
      expect(store.values[keyB], isNull);

      final ProviderContainer containerAAgain = _container(
        store,
        a,
        _Tasks(_entity()),
      );
      addTearDown(containerAAgain.dispose);
      expect(
        containerAAgain.read(timelineProvider).map((event) => event.title),
        contains('Task completed'),
      );
      expect(store.values['timeline_events_v1'], legacy);
    },
  );

  test(
    'PRE-TEST-02E2 delay and skip commands follow the real scoped Timeline path',
    () async {
      final _Store store = _Store();
      const String legacy = '[{"legacy":"timeline-sentinel"}]';
      store.values['timeline_events_v1'] = legacy;
      final AccountStorageScope a = AccountStorageScope.authenticated(
        'account-a',
      );
      final AccountStorageScope b = AccountStorageScope.authenticated(
        'account-b',
      );
      final String keyA = 'timeline_events_v2.${a.v2Namespace}';
      final String keyB = 'timeline_events_v2.${b.v2Namespace}';

      final ProviderContainer delayA = _container(store, a, _Tasks(_entity()));
      addTearDown(delayA.dispose);
      await delayA
          .read(taskActionsProvider)
          .delayTask('complete-a', notify: false);
      await _settle();
      expect(store.values[keyA], contains('taskRescheduled'));
      expect(store.values[keyB], isNull);
      expect(store.values['timeline_events_v1'], legacy);
      final ProviderContainer delayB = _container(store, b, _Tasks(_entity()));
      addTearDown(delayB.dispose);
      expect(delayB.read(timelineProvider), isEmpty);
      final ProviderContainer delayAAgain = _container(
        store,
        a,
        _Tasks(_entity()),
      );
      addTearDown(delayAAgain.dispose);
      expect(
        delayAAgain.read(timelineProvider).map((event) => event.title),
        contains('Task rescheduled'),
      );

      final ProviderContainer skipB = _container(store, b, _Tasks(_entity()));
      addTearDown(skipB.dispose);
      await skipB
          .read(taskActionsProvider)
          .skipTask('complete-a', notify: false);
      await _settle();
      expect(store.values[keyB], contains('taskSkipped'));
      expect(store.values[keyA], contains('taskRescheduled'));
      expect(store.values['timeline_events_v1'], legacy);
      final ProviderContainer skipA = _container(store, a, _Tasks(_entity()));
      addTearDown(skipA.dispose);
      expect(
        skipA.read(timelineProvider).map((event) => event.title),
        contains('Task rescheduled'),
      );
      final ProviderContainer skipBAgain = _container(
        store,
        b,
        _Tasks(_entity()),
      );
      addTearDown(skipBAgain.dispose);
      expect(
        skipBAgain.read(timelineProvider).map((event) => event.title),
        contains('Task skipped'),
      );
    },
  );

  test(
    'duplicate complete through TaskActions retains one occurrence and one projection work record',
    () async {
      final _Store store = _Store();
      final _Occurrences occurrences = _Occurrences();
      final _ProjectionWork work = _ProjectionWork();
      final _Queue queue = _Queue();
      const String accountId = 'duplicate-complete-a';
      final ProviderContainer container = _container(
        store,
        AccountStorageScope.authenticated(accountId),
        _Tasks(_entity()),
        occurrences: occurrences,
        projectionWork: work,
        syncDispatcher: SyncMutationDispatcher(
          queueStore: queue,
          userId: accountId,
          isAuthorized: () => true,
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(taskActionsProvider)
          .completeTask('complete-a', notify: false);
      await container
          .read(taskActionsProvider)
          .completeTask('complete-a', notify: false);
      await _settle();

      expect(occurrences.values, hasLength(1));
      final TaskOccurrence occurrence = occurrences.values.values.single;
      expect(occurrence.transitions, hasLength(1));
      expect(
        occurrence.transitions.single.outcome,
        TaskOccurrenceOutcome.completed,
      );
      expect(work.values, hasLength(1));
      final TaskOccurrenceProjectionWork projection = work.values.values.single;
      expect(
        projection.stages[TaskOccurrenceProjectionStage.timeline],
        TaskOccurrenceProjectionStageState.done,
      );
      expect(
        projection.stages[TaskOccurrenceProjectionStage.completionLedger],
        TaskOccurrenceProjectionStageState.done,
      );
      expect(
        projection.stages[TaskOccurrenceProjectionStage.sync],
        TaskOccurrenceProjectionStageState.done,
      );
      expect(queue.values, hasLength(1));
      expect(queue.values.single.tableName, 'task_occurrences');
      final String timelineKey =
          'timeline_events_v2.${AccountStorageScope.authenticated(accountId).v2Namespace}';
      expect(store.values[timelineKey], contains('taskCompleted'));
    },
  );

  test(
    'duplicate skip through TaskActions retains one skipped occurrence',
    () async {
      const String accountId = 'duplicate-skip-a';
      final _Occurrences occurrences = _Occurrences();
      final _ProjectionWork work = _ProjectionWork();
      final _Queue queue = _Queue();
      final ProviderContainer container = _container(
        _Store(),
        AccountStorageScope.authenticated(accountId),
        _Tasks(_entity()),
        occurrences: occurrences,
        projectionWork: work,
        syncDispatcher: SyncMutationDispatcher(
          queueStore: queue,
          userId: accountId,
          isAuthorized: () => true,
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(taskActionsProvider)
          .skipTask('complete-a', notify: false);
      await container
          .read(taskActionsProvider)
          .skipTask('complete-a', notify: false);
      await _settle();

      expect(occurrences.values, hasLength(1));
      expect(occurrences.values.values.single.transitions, hasLength(1));
      expect(
        occurrences.values.values.single.transitions.single.outcome,
        TaskOccurrenceOutcome.skipped,
      );
      expect(work.values, hasLength(1));
      expect(queue.values, hasLength(1));
    },
  );

  test(
    'reschedule then complete keeps one occurrence with typed transitions',
    () async {
      const String accountId = 'reschedule-complete-a';
      final _Occurrences occurrences = _Occurrences();
      final _Queue queue = _Queue();
      final ProviderContainer container = _container(
        _Store(),
        AccountStorageScope.authenticated(accountId),
        _Tasks(_entity()),
        occurrences: occurrences,
        syncDispatcher: SyncMutationDispatcher(
          queueStore: queue,
          userId: accountId,
          isAuthorized: () => true,
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(taskActionsProvider)
          .delayTask('complete-a', notify: false);
      await container
          .read(taskActionsProvider)
          .completeTask('complete-a', notify: false);
      await _settle();

      expect(occurrences.values, hasLength(1));
      expect(
        occurrences.values.values.single.transitions.map(
          (TaskOccurrenceTransition value) => value.outcome,
        ),
        <TaskOccurrenceOutcome>[
          TaskOccurrenceOutcome.rescheduled,
          TaskOccurrenceOutcome.completed,
        ],
      );
      expect(queue.values, hasLength(2));
    },
  );

  test(
    'reschedule then skip keeps one occurrence with typed transitions',
    () async {
      const String accountId = 'reschedule-skip-a';
      final _Occurrences occurrences = _Occurrences();
      final _ProjectionWork work = _ProjectionWork();
      final _Queue queue = _Queue();
      final ProviderContainer container = _container(
        _Store(),
        AccountStorageScope.authenticated(accountId),
        _Tasks(_entity()),
        occurrences: occurrences,
        projectionWork: work,
        syncDispatcher: SyncMutationDispatcher(
          queueStore: queue,
          userId: accountId,
          isAuthorized: () => true,
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(taskActionsProvider)
          .delayTask('complete-a', notify: false);
      await container
          .read(taskActionsProvider)
          .skipTask('complete-a', notify: false);
      await _settle();

      expect(occurrences.values, hasLength(1));
      expect(
        occurrences.values.values.single.transitions.map(
          (TaskOccurrenceTransition value) => value.outcome,
        ),
        <TaskOccurrenceOutcome>[
          TaskOccurrenceOutcome.rescheduled,
          TaskOccurrenceOutcome.skipped,
        ],
      );
      expect(work.values, hasLength(2));
      expect(queue.values, hasLength(2));
    },
  );

  test(
    'concurrent complete and skip commit one terminal occurrence projection',
    () async {
      const String accountId = 'concurrent-terminal-a';
      final _Occurrences occurrences = _Occurrences();
      final _ProjectionWork work = _ProjectionWork();
      final _Queue queue = _Queue();
      final ProviderContainer container = _container(
        _Store(),
        AccountStorageScope.authenticated(accountId),
        _Tasks(_entity()),
        occurrences: occurrences,
        projectionWork: work,
        syncDispatcher: SyncMutationDispatcher(
          queueStore: queue,
          userId: accountId,
          isAuthorized: () => true,
        ),
      );
      addTearDown(container.dispose);

      await Future.wait<void>(<Future<void>>[
        container
            .read(taskActionsProvider)
            .completeTask('complete-a', notify: false),
        container
            .read(taskActionsProvider)
            .skipTask('complete-a', notify: false),
      ]);
      await _settle();

      expect(occurrences.values, hasLength(1));
      final TaskOccurrence occurrence = occurrences.values.values.single;
      expect(occurrence.transitions, hasLength(1));
      expect(
        occurrence.transitions.single.outcome,
        anyOf(TaskOccurrenceOutcome.completed, TaskOccurrenceOutcome.skipped),
      );
      expect(work.values, hasLength(1));
      expect(queue.values, hasLength(1));
    },
  );
}
