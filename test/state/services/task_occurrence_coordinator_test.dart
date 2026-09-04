import 'dart:async';
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
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  setUp(() async {
    tzdata.initializeTimeZones();
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
        (TaskEntity task) => task.recurrenceSeriesId == 'daily',
      ),
      hasLength(1),
    );
  });

  test(
    'long recurrence chains retain bounded deterministic identities',
    () async {
      const String seriesId = 'long-running-daily-series';
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'long-chain-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task(
          seriesId,
          recurrenceRule: RecurrenceRule.daily,
          scheduledFor: DateTime.utc(2026, 8, 18, 10),
        ),
      ]);
      final TaskOccurrenceCoordinator coordinator = _coordinator(scope, tasks);
      String currentId = seriesId;

      for (int index = 0; index < 120; index++) {
        final TaskEntity current = tasks.values[currentId]!;
        final String occurrenceKey = TaskOccurrence.occurrenceKeyFor(current);
        final TaskOccurrenceResult result = await coordinator.complete(
          currentId,
        );
        final TaskEntity successor = result.successor!;

        expect(
          successor.id,
          TaskEntity.recurringSuccessorId(
            seriesId: seriesId,
            occurrenceKey: occurrenceKey,
          ),
          reason: 'generation $index',
        );
        expect(successor.id.length, lessThanOrEqualTo(256));
        expect(successor.recurrenceSeriesId, seriesId);
        currentId = successor.id;
      }

      expect(tasks.values, hasLength(121));
      expect(tasks.values.keys.toSet(), hasLength(121));
    },
  );

  test(
    'legacy nested successors converge without duplication then migrate',
    () async {
      const String rootId = 'legacy-series';
      const String occurrenceKey = '2026-08-18';
      final String legacySourceId = <String>[
        rootId,
        ...List<String>.generate(12, (int index) => 'slot-$index'),
      ].join(TaskEntity.legacyRecurringSuccessorSeparator);
      final DateTime mutationAt = DateTime.utc(2026, 8, 18, 11);
      final TaskEntity source =
          _task(
            legacySourceId,
            recurrenceRule: RecurrenceRule.daily,
            scheduledFor: DateTime.utc(2026, 8, 18, 10),
          ).copyWith(
            occurrenceKey: occurrenceKey,
            isCompleted: true,
            completedAt: mutationAt,
          );
      final String legacySuccessorId =
          '$legacySourceId${TaskEntity.legacyRecurringSuccessorSeparator}'
          '$occurrenceKey';
      final TaskEntity legacySuccessor = _task(
        legacySuccessorId,
        recurrenceRule: RecurrenceRule.daily,
        scheduledFor: DateTime.utc(2026, 8, 19, 10),
      ).copyWith(occurrenceKey: '2026-08-19');
      final _Tasks tasks = _Tasks(<TaskEntity>[source, legacySuccessor]);
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'legacy-chain-user',
      );
      final TaskOccurrenceRepository occurrences = _occurrences(scope);
      final TaskOccurrence pending = TaskOccurrence(
        taskId: legacySourceId,
        seriesId: rootId,
        occurrenceKey: occurrenceKey,
        initialScheduledFor: source.scheduledFor,
        pendingOperation: TaskOccurrencePendingOperation(
          operationId: '$legacySourceId::$occurrenceKey::completed',
          outcome: TaskOccurrenceOutcome.completed,
          at: mutationAt,
        ),
      );
      await occurrences.save(pending);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => mutationAt,
      );

      final TaskOccurrenceResult recovered = await coordinator.complete(
        legacySourceId,
      );

      expect(recovered.successor?.id, legacySuccessorId);
      expect(tasks.values, hasLength(2));

      final TaskOccurrenceResult migrated = await coordinator.complete(
        legacySuccessorId,
      );
      expect(
        migrated.successor?.id,
        TaskEntity.recurringSuccessorId(
          seriesId: rootId,
          occurrenceKey: '2026-08-19',
        ),
      );
      expect(migrated.successor?.recurrenceSeriesId, rootId);
      expect(migrated.successor!.id.length, lessThanOrEqualTo(256));
      expect(tasks.values, hasLength(3));
    },
  );

  test(
    'recurring successors advance schedules and deadlines together',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'recurring-deadline-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task(
          'deadline-daily',
          recurrenceRule: RecurrenceRule.daily,
          scheduledFor: DateTime.utc(2026, 8, 18, 10),
          dueDate: DateTime.utc(2026, 8, 18, 17),
        ),
      ]);

      final TaskOccurrenceResult result = await _coordinator(
        scope,
        tasks,
      ).complete('deadline-daily');

      expect(result.successor?.scheduledFor, DateTime.utc(2026, 8, 19, 10));
      expect(result.successor?.dueDate, DateTime.utc(2026, 8, 19, 17));
    },
  );

  test('recurring successor deadlines catch up with stale schedules', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'recurring-deadline-catch-up-user',
    );
    final _Tasks tasks = _Tasks(<TaskEntity>[
      _task(
        'deadline-catch-up',
        recurrenceRule: RecurrenceRule.daily,
        scheduledFor: DateTime.utc(2026, 8, 10, 10),
        dueDate: DateTime.utc(2026, 8, 10, 17),
      ),
    ]);

    final TaskOccurrenceResult result = await _coordinator(
      scope,
      tasks,
    ).complete('deadline-catch-up');

    expect(result.successor?.scheduledFor, DateTime.utc(2026, 8, 19, 10));
    expect(result.successor?.dueDate, DateTime.utc(2026, 8, 19, 17));
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
    expect(replica.expectedUserIds.single, 'cloud-user');
    expect(first.occurrence.pendingCloudOperationIds, isEmpty);
  });

  test(
    'failed cloud replication remains durable and is delivered after restart',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'cloud-retry-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('cloud-retry')]);
      final TaskOccurrenceRepository occurrences = _occurrences(scope);
      final _Replica failing = _Replica()..succeed = false;

      final TaskOccurrenceResult committed = await TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        cloudReplica: failing,
        clock: () => DateTime.utc(2026, 8, 18, 11),
      ).complete('cloud-retry', operationId: 'cloud-retry-operation');

      expect(committed.mutation, TaskOccurrenceMutation.applied);
      expect(committed.occurrence.pendingCloudOperationIds, <String>{
        'cloud-retry-operation',
      });

      final _Replica recoveredReplica = _Replica();
      final TaskOccurrenceCoordinator restarted = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: TaskOccurrenceRepository(
          HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, scope),
            hive: _DirectHiveStore(),
          ),
        ),
        cloudReplica: recoveredReplica,
      );

      expect(await restarted.retryPendingCloudReplication(), 1);
      final TaskOccurrence stored =
          (await occurrences.listOccurrences()).single;
      expect(stored.pendingCloudOperationIds, isEmpty);
      expect(stored.transitions, hasLength(1));
      expect(
        recoveredReplica.transitions.single.operationId,
        'cloud-retry-operation',
      );
    },
  );

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
          (TaskEntity task) => task.recurrenceSeriesId == 'successor-fail',
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
          (TaskEntity task) => task.recurrenceSeriesId == 'ledger-fail',
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

  test('fresh occurrence mutations cannot alter terminal task state', () async {
    final DateTime resolvedAt = DateTime.utc(2026, 8, 18, 10);
    final List<TaskEntity> terminalTasks = <TaskEntity>[
      _task(
        'already-completed',
      ).copyWith(isCompleted: true, completedAt: resolvedAt),
      _task('already-skipped').copyWith(isSkipped: true, skippedAt: resolvedAt),
      _task('already-canceled').copyWith(isCanceled: true),
    ];

    for (final TaskEntity terminal in terminalTasks) {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'terminal-${terminal.id}',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[terminal]);
      final TaskOccurrenceRepository occurrences = _occurrences(scope);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 18, 11),
      );

      final TaskOccurrenceResult completed = await coordinator.complete(
        terminal.id,
      );
      final TaskOccurrenceResult skipped = await coordinator.skip(terminal.id);
      final TaskOccurrenceResult rescheduled = await coordinator.reschedule(
        terminal.id,
        scheduledFor: DateTime.utc(2026, 8, 20, 9),
      );

      expect(
        completed.mutation,
        terminal.isCompleted
            ? TaskOccurrenceMutation.idempotent
            : TaskOccurrenceMutation.conflict,
        reason: terminal.id,
      );
      expect(
        skipped.mutation,
        terminal.isSkipped
            ? TaskOccurrenceMutation.idempotent
            : TaskOccurrenceMutation.conflict,
        reason: terminal.id,
      );
      expect(
        rescheduled.mutation,
        TaskOccurrenceMutation.conflict,
        reason: terminal.id,
      );
      expect(tasks.saveCalls, 0, reason: terminal.id);
      expect(await occurrences.listOccurrences(), isEmpty, reason: terminal.id);
      expect(tasks.values[terminal.id]?.toJson(), terminal.toJson());
    }
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
        (TaskEntity task) => task.recurrenceSeriesId == 'race',
      ),
      hasLength(1),
    );
  });

  test(
    'separate coordinators share one account-and-task mutation lock',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'multi-coordinator-user',
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task('multi-race', recurrenceRule: RecurrenceRule.daily),
      ]);
      final TaskOccurrenceRepository occurrences = _occurrences(scope);
      final TaskOccurrenceCoordinator first = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
      );
      final TaskOccurrenceCoordinator second = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
      );

      final List<TaskOccurrenceResult> results =
          await Future.wait(<Future<TaskOccurrenceResult>>[
            first.complete('multi-race', operationId: 'multi-complete'),
            second.skip('multi-race', operationId: 'multi-skip'),
          ]);

      expect(
        results.where(
          (TaskOccurrenceResult value) =>
              value.mutation == TaskOccurrenceMutation.applied,
        ),
        hasLength(1),
      );
      expect(
        results.where(
          (TaskOccurrenceResult value) =>
              value.mutation == TaskOccurrenceMutation.conflict,
        ),
        hasLength(1),
      );
      expect(
        (await occurrences.listOccurrences()).single.transitions,
        hasLength(1),
      );
      expect(
        tasks.values.values.where(
          (TaskEntity value) => value.recurrenceSeriesId == 'multi-race',
        ),
        hasLength(1),
      );
    },
  );

  test('daily recurrence preserves wall clock across DST boundaries', () async {
    final tz.Location chicago = tz.getLocation('America/Chicago');
    final fixtures = <({DateTime scheduled, int elapsedHours})>[
      (scheduled: tz.TZDateTime(chicago, 2026, 3, 7, 9), elapsedHours: 23),
      (scheduled: tz.TZDateTime(chicago, 2026, 10, 31, 9), elapsedHours: 25),
    ];
    for (final fixture in fixtures) {
      final String id = 'dst-${fixture.elapsedHours}';
      final AccountStorageScope scope = AccountStorageScope.authenticated(id);
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task(
          id,
          recurrenceRule: RecurrenceRule.daily,
          scheduledFor: fixture.scheduled,
        ),
      ]);

      final TaskOccurrenceResult result = await TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(scope),
        clock: () => fixture.scheduled.add(const Duration(hours: 1)),
      ).complete(id);

      final DateTime next = result.successor!.scheduledFor!;
      expect(next.hour, 9);
      expect(next.difference(fixture.scheduled).inHours, fixture.elapsedHours);
    }
  });

  test(
    'malformed ledger members are quarantined without hiding valid records',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'quarantine-user',
      );
      final HiveStorage<String> storage = HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, scope),
        hive: _DirectHiveStore(),
      );
      await storage.open();
      await storage.put(
        TaskOccurrenceRepository.persistenceKey,
        '[{"taskId":"valid","occurrenceKey":"slot","transitions":[]},'
        '{"taskId":"broken","occurrenceKey":"slot","transitions":'
        '[{"operationId":"","outcome":"completed","at":"bad"}]}]',
      );
      final TaskOccurrenceRepository repository = TaskOccurrenceRepository(
        storage,
      );

      final List<TaskOccurrence> valid = await repository.listOccurrences();

      expect(valid.single.taskId, 'valid');
      expect(valid.single.seriesId, 'valid');
      expect(await repository.listQuarantinedRecords(), hasLength(1));
    },
  );

  test('account transition stops after each persistence boundary', () async {
    for (final _PauseBoundary boundary in _PauseBoundary.values) {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'transition-${boundary.name}',
      );
      final _PausingTasks tasks = _PausingTasks(<TaskEntity>[
        _task(
          'transition-task',
          recurrenceRule: RecurrenceRule.daily,
          scheduledFor: DateTime.utc(2026, 8, 18, 10),
        ),
      ], pauseOnSaveCall: boundary.taskSaveCall);
      final _PausingOccurrenceRepository occurrences =
          _PausingOccurrenceRepository(
            pauseOnSaveCall: boundary.occurrenceSaveCall,
          );
      final _Replica replica = _Replica();
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: scope,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        cloudReplica: replica,
        clock: () => DateTime.utc(2026, 8, 18, 11),
      );

      final Future<TaskOccurrenceResult> mutation = coordinator.complete(
        'transition-task',
        operationId: 'transition-operation',
      );
      await boundary.waitUntilPaused(tasks, occurrences);
      final Future<void> drain = coordinator.cancelAndDrain();
      boundary.release(tasks, occurrences);

      await expectLater(mutation, throwsStateError, reason: boundary.name);
      await drain;
      expect(replica.transitions, isEmpty, reason: boundary.name);
    }
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
  DateTime? dueDate,
}) => TaskEntity(
  id: id,
  title: 'Task $id',
  createdAt: DateTime.utc(2026, 8, 18, 9),
  scheduledFor: scheduledFor ?? DateTime.utc(2026, 8, 18, 10),
  dueDate: dueDate,
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
  final List<String> expectedUserIds = <String>[];
  bool succeed = true;

  @override
  Future<bool> replicate({
    required String expectedUserId,
    required TaskOccurrence occurrence,
    required TaskOccurrenceTransition transition,
  }) async {
    occurrences.add(occurrence);
    transitions.add(transition);
    expectedUserIds.add(expectedUserId);
    return succeed;
  }
}

enum _PauseBoundary {
  pendingLedger(occurrenceSaveCall: 1),
  taskState(taskSaveCall: 1),
  successorTask(taskSaveCall: 2),
  finalLedger(occurrenceSaveCall: 2);

  const _PauseBoundary({this.taskSaveCall, this.occurrenceSaveCall});

  final int? taskSaveCall;
  final int? occurrenceSaveCall;

  Future<void> waitUntilPaused(
    _PausingTasks tasks,
    _PausingOccurrenceRepository occurrences,
  ) => taskSaveCall == null ? occurrences.paused.future : tasks.paused.future;

  void release(_PausingTasks tasks, _PausingOccurrenceRepository occurrences) {
    if (taskSaveCall == null) {
      occurrences.release.complete();
    } else {
      tasks.release.complete();
    }
  }
}

class _PausingTasks extends _Tasks {
  _PausingTasks(super.seed, {required this.pauseOnSaveCall});

  final int? pauseOnSaveCall;
  final Completer<void> paused = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<void> saveTask(TaskEntity task) async {
    final int nextCall = saveCalls + 1;
    if (nextCall == pauseOnSaveCall) {
      paused.complete();
      await release.future;
    }
    await super.saveTask(task);
  }
}

class _PausingOccurrenceRepository extends TaskOccurrenceRepository {
  _PausingOccurrenceRepository({required this.pauseOnSaveCall})
    : super.unavailable();

  final int? pauseOnSaveCall;
  final Completer<void> paused = Completer<void>();
  final Completer<void> release = Completer<void>();
  final List<TaskOccurrence> values = <TaskOccurrence>[];
  int saveCalls = 0;

  @override
  Future<TaskOccurrence?> getOccurrence(
    String taskId,
    String occurrenceKey,
  ) async => values.cast<TaskOccurrence?>().firstWhere(
    (TaskOccurrence? value) =>
        value?.taskId == taskId && value?.occurrenceKey == occurrenceKey,
    orElse: () => null,
  );

  @override
  Future<List<TaskOccurrence>> listOccurrences() async =>
      List<TaskOccurrence>.from(values);

  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async =>
      values.where((TaskOccurrence value) => value.taskId == taskId).toList();

  @override
  Future<void> save(TaskOccurrence occurrence) async {
    saveCalls += 1;
    if (saveCalls == pauseOnSaveCall) {
      paused.complete();
      await release.future;
    }
    values
      ..removeWhere((TaskOccurrence value) => value.id == occurrence.id)
      ..add(occurrence);
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
