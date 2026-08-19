import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
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

  @override
  Future<void> deleteTask(String id) async => values.remove(id);

  @override
  Future<List<TaskEntity>> getAllTasks() async => values.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => values[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
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
