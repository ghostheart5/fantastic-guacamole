import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/services/task_occurrence_cloud_replica.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('occurrence-ledger-');
    await Hive.close();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('identical task IDs keep separate account ledgers', () async {
    final AccountStorageScope scopeA = AccountStorageScope.authenticated(
      'account-a',
    );
    final AccountStorageScope scopeB = AccountStorageScope.authenticated(
      'account-b',
    );
    final _Tasks tasksA = _Tasks(<TaskEntity>[_task('same')]);
    final _Tasks tasksB = _Tasks(<TaskEntity>[_task('same')]);

    await _coordinator(scopeA, tasksA).complete('same');

    final String key = TaskOccurrence.occurrenceKeyFor(_task('same'));
    expect(
      (await _occurrences(scopeA).getOccurrence('same', key))?.terminalOutcome,
      TaskOccurrenceOutcome.completed,
    );
    expect(await _occurrences(scopeB).getOccurrence('same', key), isNull);
    expect(tasksB.values['same']?.isCompleted, isFalse);
  });

  test('recurring completion is idempotent with one successor', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'recurring-user',
    );
    final _Tasks tasks = _Tasks(<TaskEntity>[
      _task(
        'daily',
        recurrenceRule: RecurrenceRule.daily,
        scheduledFor: DateTime.utc(2026, 8, 18, 10),
      ),
    ]);
    final TaskOccurrenceCoordinator coordinator = _coordinator(scope, tasks);

    final TaskOccurrenceResult first = await coordinator.complete('daily');
    final TaskOccurrenceResult repeated = await coordinator.complete('daily');

    expect(first.mutation, TaskOccurrenceMutation.applied);
    expect(repeated.mutation, TaskOccurrenceMutation.idempotent);
    expect(tasks.values['daily']?.isCompleted, isTrue);
    expect(
      tasks.values.values.where(
        (TaskEntity task) => task.id.startsWith('daily::next::'),
      ),
      hasLength(1),
    );
  });

  test('committed occurrences replicate to the cloud contract once', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'cloud-user',
    );
    final _Tasks tasks = _Tasks(<TaskEntity>[_task('cloud-task')]);
    final _Replica replica = _Replica();
    final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
      scope: scope,
      taskRepository: tasks,
      occurrenceRepository: _occurrences(scope),
      cloudReplica: replica,
      clock: () => DateTime.utc(2026, 8, 18, 11),
    );

    final TaskOccurrenceResult first = await coordinator.complete('cloud-task');
    final TaskOccurrenceResult repeated = await coordinator.complete(
      'cloud-task',
    );

    expect(first.mutation, TaskOccurrenceMutation.applied);
    expect(repeated.mutation, TaskOccurrenceMutation.idempotent);
    expect(replica.transitions, hasLength(1));
    expect(replica.transitions.single.operationId, isNotEmpty);
    expect(replica.occurrences.single.taskId, 'cloud-task');
  });

  test('pending completion survives failure and converges on retry', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'retry-user',
    );
    final _Tasks tasks = _Tasks(<TaskEntity>[_task('retry')])
      ..failNextSave = true;
    final TaskOccurrenceRepository occurrences = _occurrences(scope);
    final TaskOccurrenceCoordinator first = TaskOccurrenceCoordinator(
      scope: scope,
      taskRepository: tasks,
      occurrenceRepository: occurrences,
      clock: () => DateTime.utc(2026, 8, 18, 11),
    );

    await expectLater(first.complete('retry'), throwsStateError);
    final String key = TaskOccurrence.occurrenceKeyFor(_task('retry'));
    expect(
      (await occurrences.getOccurrence('retry', key))?.pendingOperation,
      isNotNull,
    );

    final TaskOccurrenceResult recovered = await TaskOccurrenceCoordinator(
      scope: scope,
      taskRepository: tasks,
      occurrenceRepository: occurrences,
      clock: () => DateTime.utc(2026, 8, 18, 12),
    ).complete('retry');

    expect(recovered.mutation, TaskOccurrenceMutation.applied);
    expect(recovered.occurrence.pendingOperation, isNull);
    expect(recovered.occurrence.transitions, hasLength(1));
    expect(tasks.values['retry']?.isCompleted, isTrue);
  });

  test(
    'successor write failure keeps pending operation and converges on retry',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'successor-failure-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task(
          'successor-fail',
          recurrenceRule: RecurrenceRule.daily,
          scheduledFor: DateTime.utc(2026, 8, 18, 10),
        ),
      ])..failOnSaveCall = 2;
      final TaskOccurrenceRepository occurrences = _occurrences(scope);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 18, 11),
      );

      await expectLater(
        coordinator.complete('successor-fail'),
        throwsStateError,
      );
      final String key = TaskOccurrence.occurrenceKeyFor(
        _task('successor-fail'),
      );
      expect(
        (await occurrences.getOccurrence(
          'successor-fail',
          key,
        ))?.pendingOperation,
        isNotNull,
      );

      final TaskOccurrenceResult recovered = await TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 18, 12),
      ).complete('successor-fail');

      expect(recovered.mutation, TaskOccurrenceMutation.applied);
      expect(
        tasks.values.values.where(
          (TaskEntity task) => task.id.startsWith('successor-fail::next::'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'final ledger failure converges without duplicating successor',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'ledger-failure-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task(
          'ledger-fail',
          recurrenceRule: RecurrenceRule.daily,
          scheduledFor: DateTime.utc(2026, 8, 18, 10),
        ),
      ]);
      final _FailingOccurrenceRepository occurrences =
          _FailingOccurrenceRepository(failOnSaveCall: 2);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 18, 11),
      );

      await expectLater(coordinator.complete('ledger-fail'), throwsStateError);
      expect(occurrences.saved.single.pendingOperation, isNotNull);

      final TaskOccurrenceResult recovered = await TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 18, 12),
      ).complete('ledger-fail');

      expect(recovered.mutation, TaskOccurrenceMutation.applied);
      expect(recovered.occurrence.pendingOperation, isNull);
      expect(recovered.occurrence.transitions, hasLength(1));
      expect(
        tasks.values.values.where(
          (TaskEntity task) => task.id.startsWith('ledger-fail::next::'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'reschedule records reschedule target without terminal side effects',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'reschedule-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('move-me')]);
      final DateTime target = DateTime.utc(2026, 8, 19, 15);

      final TaskOccurrenceResult result = await _coordinator(
        scope,
        tasks,
      ).reschedule('move-me', scheduledFor: target);

      expect(result.mutation, TaskOccurrenceMutation.applied);
      expect(result.occurrence.terminalOutcome, isNull);
      expect(result.occurrence.transitions.single.rescheduledFor, target);
      expect(tasks.values['move-me']?.scheduledFor, target);
    },
  );

  test('concurrent complete and skip select one terminal outcome', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'race-user',
    );
    final _Tasks tasks = _Tasks(<TaskEntity>[
      _task('race', recurrenceRule: RecurrenceRule.weekly),
    ]);
    final TaskOccurrenceCoordinator coordinator = _coordinator(scope, tasks);

    final List<TaskOccurrenceResult> results =
        await Future.wait<TaskOccurrenceResult>(<Future<TaskOccurrenceResult>>[
          coordinator.complete('race', operationId: 'complete-race'),
          coordinator.skip('race', operationId: 'skip-race'),
        ]);

    expect(
      results.where(
        (TaskOccurrenceResult result) =>
            result.mutation == TaskOccurrenceMutation.applied,
      ),
      hasLength(1),
    );
    expect(
      results.where(
        (TaskOccurrenceResult result) =>
            result.mutation == TaskOccurrenceMutation.conflict,
      ),
      hasLength(1),
    );
    expect(
      tasks.values['race']?.isCompleted == true,
      isNot(tasks.values['race']?.isSkipped == true),
    );
    expect(
      tasks.values.values.where(
        (TaskEntity task) => task.id.startsWith('race::next::'),
      ),
      hasLength(1),
    );
  });

  test('signed-out and drained coordinators fail closed', () async {
    final _Tasks tasks = _Tasks(<TaskEntity>[_task('protected')]);
    final TaskOccurrenceCoordinator signedOut = TaskOccurrenceCoordinator(
      scope: const AccountStorageScope.signedOut(),
      taskRepository: tasks,
      occurrenceRepository: TaskOccurrenceRepository.unavailable(),
    );

    await expectLater(signedOut.complete('protected'), throwsStateError);
    expect(tasks.values['protected']?.isCompleted, isFalse);

    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'drained-user',
    );
    final TaskOccurrenceCoordinator drained = _coordinator(scope, tasks);
    await drained.cancelAndDrain();
    await expectLater(drained.complete('protected'), throwsStateError);
    expect(
      await _occurrences(scope).listOccurrencesForTask('protected'),
      isEmpty,
    );
  });
}

TaskOccurrenceCoordinator _coordinator(
  AccountStorageScope scope,
  _Tasks tasks,
) => TaskOccurrenceCoordinator(
  scope: scope,
  taskRepository: tasks,
  occurrenceRepository: _occurrences(scope),
  clock: () => DateTime.utc(2026, 8, 18, 11),
);

TaskOccurrenceRepository _occurrences(AccountStorageScope scope) =>
    TaskOccurrenceRepository(
      HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, scope),
        hive: _DirectHiveStore(),
      ),
    );

TaskEntity _task(
  String id, {
  RecurrenceRule recurrenceRule = RecurrenceRule.none,
  DateTime? scheduledFor,
}) => TaskEntity(
  id: id,
  title: 'Task $id',
  createdAt: DateTime.utc(2026, 8, 18, 9),
  scheduledFor: scheduledFor ?? DateTime.utc(2026, 8, 18, 10),
  recurrenceRule: recurrenceRule,
);

class _Tasks implements ITaskRepository {
  _Tasks(Iterable<TaskEntity> seed) {
    for (final TaskEntity task in seed) {
      values[task.id] = task;
    }
  }

  final Map<String, TaskEntity> values = <String, TaskEntity>{};
  bool failNextSave = false;
  int? failOnSaveCall;
  int saveCalls = 0;

  @override
  Future<void> deleteTask(String id) async => values.remove(id);

  @override
  Future<List<TaskEntity>> getAllTasks() async => values.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => values[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    saveCalls += 1;
    if (failOnSaveCall == saveCalls) {
      throw StateError('injected task write failure $saveCalls');
    }
    if (failNextSave) {
      failNextSave = false;
      throw StateError('injected task write failure');
    }
    values[task.id] = task;
  }
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) return Hive.box<T>(key);
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<dynamic> target = Hive.isBoxOpen(key)
        ? Hive.box<dynamic>(key)
        : await Hive.openBox<dynamic>(key);
    await target.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}

class _Replica implements TaskOccurrenceCloudReplica {
  final List<TaskOccurrence> occurrences = <TaskOccurrence>[];
  final List<TaskOccurrenceTransition> transitions =
      <TaskOccurrenceTransition>[];

  @override
  Future<bool> replicate({
    required TaskOccurrence occurrence,
    required TaskOccurrenceTransition transition,
  }) async {
    occurrences.add(occurrence);
    transitions.add(transition);
    return true;
  }
}

class _FailingOccurrenceRepository extends TaskOccurrenceRepository {
  _FailingOccurrenceRepository({required this.failOnSaveCall})
    : super.unavailable();

  final int failOnSaveCall;
  int saveCalls = 0;
  final List<TaskOccurrence> saved = <TaskOccurrence>[];

  @override
  Future<TaskOccurrence?> getOccurrence(
    String taskId,
    String occurrenceKey,
  ) async {
    return saved.cast<TaskOccurrence?>().firstWhere(
      (TaskOccurrence? occurrence) =>
          occurrence?.taskId == taskId &&
          occurrence?.occurrenceKey == occurrenceKey,
      orElse: () => null,
    );
  }

  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async {
    return saved
        .where((TaskOccurrence occurrence) => occurrence.taskId == taskId)
        .toList(growable: false);
  }

  @override
  Future<void> save(TaskOccurrence occurrence) async {
    saveCalls += 1;
    if (saveCalls == failOnSaveCall) {
      throw StateError('injected occurrence write failure $saveCalls');
    }
    saved
      ..removeWhere((TaskOccurrence item) => item.id == occurrence.id)
      ..add(occurrence);
  }
}
