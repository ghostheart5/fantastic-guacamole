import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
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

class _Hive implements HiveStore {
  const _Hive();
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();
  @override
  Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

const _Hive _hive = _Hive();

TaskOccurrenceRepository _occurrences(AccountStorageScope scope) =>
    TaskOccurrenceRepository(
      HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, scope),
        hive: _hive,
      ),
    );

TaskEntity _task(
  String id, {
  RecurrenceRule recurrenceRule = RecurrenceRule.none,
  DateTime? scheduledFor,
}) => TaskEntity(
  id: id,
  title: 'Task $id',
  createdAt: DateTime.utc(2026, 8, 15, 9),
  scheduledFor: scheduledFor ?? DateTime.utc(2026, 8, 15, 10),
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
  int saveCount = 0;
  int? failOnSaveCount;

  @override
  Future<void> deleteTask(String id) async => values.remove(id);

  @override
  Future<List<TaskEntity>> getAllTasks() async => values.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => values[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    saveCount++;
    if (failOnSaveCount == saveCount) {
      throw StateError('injected task write failure');
    }
    if (failNextSave) {
      failNextSave = false;
      throw StateError('injected task write failure');
    }
    values[task.id] = task;
  }
}

class _FailingOccurrences extends TaskOccurrenceRepository {
  _FailingOccurrences(this.delegate, {this.failOnSaveCount})
    : super.unavailable();

  final TaskOccurrenceRepository delegate;
  int? failOnSaveCount;
  int saveCount = 0;

  @override
  Future<void> cancelAndDrain() => delegate.cancelAndDrain();

  @override
  Future<TaskOccurrence?> getOccurrence(String taskId, String occurrenceKey) =>
      delegate.getOccurrence(taskId, occurrenceKey);

  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) =>
      delegate.listOccurrencesForTask(taskId);

  @override
  Future<void> save(TaskOccurrence occurrence) async {
    saveCount++;
    if (failOnSaveCount == saveCount) {
      throw StateError('injected occurrence write failure');
    }
    await delegate.save(occurrence);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AccountStorageScope a = AccountStorageScope.authenticated('task-a');
  final AccountStorageScope b = AccountStorageScope.authenticated('task-b');

  setUpAll(
    () => Hive.init(
      Directory.systemTemp.createTempSync('task-occurrence-authority-').path,
    ),
  );

  test(
    'occurrence ledger is V2 account scoped for identical task IDs',
    () async {
      final _Tasks tasksA = _Tasks(<TaskEntity>[_task('same')]);
      final _Tasks tasksB = _Tasks(<TaskEntity>[_task('same')]);
      final TaskOccurrenceCoordinator aCoordinator = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasksA,
        occurrenceRepository: _occurrences(a),
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );
      final TaskOccurrenceCoordinator bCoordinator = TaskOccurrenceCoordinator(
        scope: b,
        taskRepository: tasksB,
        occurrenceRepository: _occurrences(b),
        clock: () => DateTime.utc(2026, 8, 15, 12),
      );

      await aCoordinator.complete('same');
      final TaskOccurrence? aOccurrence = await _occurrences(
        a,
      ).getOccurrence('same', TaskOccurrence.occurrenceKeyFor(_task('same')));
      expect(aOccurrence?.terminalOutcome, TaskOccurrenceOutcome.completed);
      expect(
        await _occurrences(
          b,
        ).getOccurrence('same', TaskOccurrence.occurrenceKeyFor(_task('same'))),
        isNull,
      );

      await bCoordinator.skip('same');
      expect(aOccurrence?.terminalOutcome, TaskOccurrenceOutcome.completed);
      expect(
        (await _occurrences(b).getOccurrence(
          'same',
          TaskOccurrence.occurrenceKeyFor(_task('same')),
        ))?.terminalOutcome,
        TaskOccurrenceOutcome.skipped,
      );
      expect(
        HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, a),
        isNot(HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, b)),
      );
    },
  );

  test('legacy task payload derives and persists a stable occurrence key', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': 'legacy-task',
      'title': 'Legacy task',
      'createdAt': '2026-08-15T09:00:00.000Z',
      // This schedule is mutable legacy data and must not influence the key.
      'scheduledFor': '2026-08-18T10:00:00.000Z',
    };

    final TaskEntity first = TaskEntityMapper.fromJson(payload);
    final TaskEntity second = TaskEntityMapper.fromJson(payload);

    expect(first.occurrenceKey, second.occurrenceKey);
    expect(
      first.occurrenceKey,
      TaskEntity.deriveOccurrenceKey(
        taskId: 'legacy-task',
        createdAt: DateTime.utc(2026, 8, 15, 9),
      ),
    );
    expect(
      TaskEntityMapper.toJson(first)['occurrenceKey'],
      first.occurrenceKey,
    );
  });

  test(
    'occurrence serialization preserves journal state and rejects unknown outcomes',
    () {
      final TaskOccurrence original = TaskOccurrence(
        taskId: 'serial',
        occurrenceKey: 'key',
        initialScheduledFor: DateTime.utc(2026, 8, 15, 10),
        transitions: <TaskOccurrenceTransition>[
          TaskOccurrenceTransition(
            operationId: 'move-1',
            outcome: TaskOccurrenceOutcome.rescheduled,
            at: DateTime.utc(2026, 8, 15, 11),
            rescheduledFor: DateTime.utc(2026, 8, 16, 10),
          ),
        ],
        pendingOperation: TaskOccurrencePendingOperation(
          operationId: 'complete-1',
          outcome: TaskOccurrenceOutcome.completed,
          at: DateTime.utc(2026, 8, 16, 10),
        ),
      );

      final TaskOccurrence restored = TaskOccurrence.fromJson(
        original.toJson(),
      );
      expect(restored.id, 'serial::key');
      expect(restored.transitions.single.operationId, 'move-1');
      expect(restored.pendingOperation?.operationId, 'complete-1');
      expect(
        () => TaskOccurrenceTransition.fromJson(<String, dynamic>{
          'operationId': 'bad',
          'outcome': 'unknown',
          'at': '2026-08-15T11:00:00.000Z',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'recurring completion is idempotent and creates exactly one successor',
    () async {
      final TaskEntity source = _task(
        'daily',
        recurrenceRule: RecurrenceRule.daily,
        scheduledFor: DateTime.utc(2026, 8, 15, 10),
      );
      final _Tasks tasks = _Tasks(<TaskEntity>[source]);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(a),
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );

      final TaskOccurrenceResult first = await coordinator.complete('daily');
      final TaskOccurrenceResult second = await coordinator.complete('daily');

      expect(first.mutation, TaskOccurrenceMutation.applied);
      expect(second.mutation, TaskOccurrenceMutation.idempotent);
      expect(tasks.values['daily']?.isCompleted, isTrue);
      expect(
        tasks.values.values.where(
          (TaskEntity item) => item.id.startsWith('daily::next::'),
        ),
        hasLength(1),
      );
      expect(first.occurrence.terminalOutcome, TaskOccurrenceOutcome.completed);
    },
  );

  test(
    'recurring skip creates one next cadence successor without completion',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[
        _task(
          'weekly-skip',
          recurrenceRule: RecurrenceRule.weekly,
          scheduledFor: DateTime.utc(2026, 8, 15, 10),
        ),
      ]);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(a),
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );

      final TaskOccurrenceResult result = await coordinator.skip('weekly-skip');
      final TaskEntity successor = result.successor!;

      expect(tasks.values['weekly-skip']?.isSkipped, isTrue);
      expect(tasks.values['weekly-skip']?.isCompleted, isFalse);
      expect(successor.scheduledFor, DateTime.utc(2026, 8, 22, 10));
      expect(successor.occurrenceKey, isNot(result.task.occurrenceKey));
      expect(
        (await coordinator.skip('weekly-skip')).successor?.id,
        successor.id,
      );
    },
  );

  test(
    'one-time skip is terminal, distinct from completion, and has no successor',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('one-time')]);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(a),
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );

      final TaskOccurrenceResult result = await coordinator.skip('one-time');

      expect(result.occurrence.terminalOutcome, TaskOccurrenceOutcome.skipped);
      expect(tasks.values['one-time']?.isSkipped, isTrue);
      expect(tasks.values['one-time']?.isCompleted, isFalse);
      expect(result.successor, isNull);
      expect(
        await coordinator.complete('one-time'),
        isA<TaskOccurrenceResult>(),
      );
    },
  );

  test('reschedule remains non-terminal and records typed history', () async {
    final _Tasks tasks = _Tasks(<TaskEntity>[_task('move')]);
    final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
      scope: a,
      taskRepository: tasks,
      occurrenceRepository: _occurrences(a),
      clock: () => DateTime.utc(2026, 8, 15, 11),
    );
    final DateTime target = DateTime.utc(2026, 8, 16, 10);

    final TaskOccurrenceResult moved = await coordinator.reschedule(
      'move',
      scheduledFor: target,
    );
    final TaskOccurrenceResult completed = await coordinator.complete('move');

    expect(moved.occurrence.isTerminal, isFalse);
    expect(tasks.values['move']?.scheduledFor, target);
    expect(
      completed.occurrence.transitions.map((value) => value.outcome),
      <TaskOccurrenceOutcome>[
        TaskOccurrenceOutcome.rescheduled,
        TaskOccurrenceOutcome.completed,
      ],
    );
  });

  test(
    'terminal conflicts are typed and reschedules retain one occurrence key',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('conflicts')]);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(a),
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );
      final TaskOccurrenceResult firstMove = await coordinator.reschedule(
        'conflicts',
        scheduledFor: DateTime.utc(2026, 8, 16, 10),
        operationId: 'move-1',
      );
      final TaskOccurrenceResult secondMove = await coordinator.reschedule(
        'conflicts',
        scheduledFor: DateTime.utc(2026, 8, 17, 10),
        operationId: 'move-2',
      );
      final TaskOccurrenceResult completed = await coordinator.complete(
        'conflicts',
        operationId: 'complete-1',
      );

      expect(
        secondMove.occurrence.occurrenceKey,
        firstMove.occurrence.occurrenceKey,
      );
      expect(completed.mutation, TaskOccurrenceMutation.applied);
      expect(
        (await coordinator.skip('conflicts', operationId: 'skip-1')).mutation,
        TaskOccurrenceMutation.conflict,
      );
      expect(
        (await coordinator.reschedule(
          'conflicts',
          scheduledFor: DateTime.utc(2026, 8, 18, 10),
        )).mutation,
        TaskOccurrenceMutation.conflict,
      );
      expect(
        (await coordinator.complete(
          'conflicts',
          operationId: 'complete-2',
        )).mutation,
        TaskOccurrenceMutation.idempotent,
      );
    },
  );

  test(
    'pending operation survives a task-write failure and retry commits once',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('retry')])
        ..failNextSave = true;
      final TaskOccurrenceRepository occurrences = _occurrences(a);
      final TaskOccurrenceCoordinator first = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );

      await expectLater(first.complete('retry'), throwsStateError);
      final String key = TaskOccurrence.occurrenceKeyFor(_task('retry'));
      expect(
        (await occurrences.getOccurrence('retry', key))?.pendingOperation,
        isNotNull,
      );

      final TaskOccurrenceCoordinator restarted = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: occurrences,
        clock: () => DateTime.utc(2026, 8, 15, 12),
      );
      final TaskOccurrenceResult retried = await restarted.complete('retry');

      expect(retried.mutation, TaskOccurrenceMutation.applied);
      expect(retried.occurrence.pendingOperation, isNull);
      expect(retried.occurrence.transitions, hasLength(1));
      expect(tasks.values['retry']?.isCompleted, isTrue);
    },
  );

  test(
    'occurrence-write failure never reports success and retry converges',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('occurrence-failure')]);
      final TaskOccurrenceRepository durable = _occurrences(a);
      final _FailingOccurrences failing = _FailingOccurrences(
        durable,
        failOnSaveCount: 2,
      );
      final TaskOccurrenceCoordinator first = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: failing,
        clock: () => DateTime.utc(2026, 8, 15, 11),
      );

      await expectLater(first.complete('occurrence-failure'), throwsStateError);
      expect(tasks.values['occurrence-failure']?.isCompleted, isTrue);
      expect(
        (await durable.getOccurrence(
          'occurrence-failure',
          TaskOccurrence.occurrenceKeyFor(_task('occurrence-failure')),
        ))?.pendingOperation,
        isNotNull,
      );

      final TaskOccurrenceResult recovered = await TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: durable,
        clock: () => DateTime.utc(2026, 8, 15, 12),
      ).complete('occurrence-failure');
      expect(recovered.mutation, TaskOccurrenceMutation.applied);
      expect(recovered.occurrence.transitions, hasLength(1));
    },
  );

  test('successor-write failure retries to exactly one successor', () async {
    final _Tasks tasks = _Tasks(<TaskEntity>[
      _task('successor-failure', recurrenceRule: RecurrenceRule.daily),
    ])..failOnSaveCount = 2;
    final TaskOccurrenceRepository occurrences = _occurrences(a);
    final TaskOccurrenceCoordinator first = TaskOccurrenceCoordinator(
      scope: a,
      taskRepository: tasks,
      occurrenceRepository: occurrences,
      clock: () => DateTime.utc(2026, 8, 15, 11),
    );

    await expectLater(first.complete('successor-failure'), throwsStateError);
    expect(tasks.values['successor-failure']?.isCompleted, isTrue);
    final TaskOccurrenceResult recovered = await TaskOccurrenceCoordinator(
      scope: a,
      taskRepository: tasks,
      occurrenceRepository: occurrences,
      clock: () => DateTime.utc(2026, 8, 15, 12),
    ).complete('successor-failure');

    expect(recovered.mutation, TaskOccurrenceMutation.applied);
    expect(
      tasks.values.values.where(
        (TaskEntity item) => item.id.startsWith('successor-failure::next::'),
      ),
      hasLength(1),
    );
  });

  test('concurrent complete and skip select one terminal outcome', () async {
    final _Tasks tasks = _Tasks(<TaskEntity>[
      _task('race', recurrenceRule: RecurrenceRule.daily),
    ]);
    final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
      scope: a,
      taskRepository: tasks,
      occurrenceRepository: _occurrences(a),
    );

    final List<TaskOccurrenceResult> results =
        await Future.wait<TaskOccurrenceResult>(<Future<TaskOccurrenceResult>>[
          coordinator.complete('race', operationId: 'complete-race'),
          coordinator.skip('race', operationId: 'skip-race'),
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
      tasks.values['race']?.isCompleted == true,
      isNot(tasks.values['race']?.isSkipped == true),
    );
    expect(
      tasks.values.values.where(
        (TaskEntity item) => item.id.startsWith('race::next::'),
      ),
      hasLength(1),
    );
  });

  test(
    'signed-out scope fails closed without creating an occurrence namespace',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('signed-out')]);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: const AccountStorageScope.signedOut(),
        taskRepository: tasks,
        occurrenceRepository: TaskOccurrenceRepository.unavailable(),
      );

      await expectLater(coordinator.complete('signed-out'), throwsStateError);
      expect(tasks.values['signed-out']?.isCompleted, isFalse);
      expect(Hive.isBoxOpen('task_occurrences_v2.v2.signed_out'), isFalse);
    },
  );

  test(
    'drained coordinator fails closed before another account can own work',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('handoff')]);
      final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(a),
      );

      await coordinator.cancelAndDrain();
      await expectLater(coordinator.complete('handoff'), throwsStateError);
      expect(await _occurrences(a).listOccurrencesForTask('handoff'), isEmpty);
    },
  );

  test(
    'same-owner reauthentication restores durable occurrence history',
    () async {
      final _Tasks tasks = _Tasks(<TaskEntity>[_task('reauth')]);
      await TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasks,
        occurrenceRepository: _occurrences(a),
      ).reschedule(
        'reauth',
        scheduledFor: DateTime.utc(2026, 8, 16, 10),
        operationId: 'reauth-move',
      );

      final TaskOccurrenceCoordinator signedOut = TaskOccurrenceCoordinator(
        scope: const AccountStorageScope.signedOut(),
        taskRepository: tasks,
        occurrenceRepository: TaskOccurrenceRepository.unavailable(),
      );
      await expectLater(signedOut.complete('reauth'), throwsStateError);

      final TaskEntity current = tasks.values['reauth']!;
      final TaskOccurrence? restored = await _occurrences(
        a,
      ).getOccurrence('reauth', TaskOccurrence.occurrenceKeyFor(current));
      expect(restored?.transitions.single.operationId, 'reauth-move');
      expect(current.isCompleted, isFalse);
    },
  );

  test(
    'a retained coordinator stays bound to A after B is constructed',
    () async {
      final _Tasks tasksA = _Tasks(<TaskEntity>[_task('retained')]);
      final _Tasks tasksB = _Tasks(<TaskEntity>[_task('retained')]);
      final TaskOccurrenceCoordinator retainedA = TaskOccurrenceCoordinator(
        scope: a,
        taskRepository: tasksA,
        occurrenceRepository: _occurrences(a),
      );
      final TaskOccurrenceCoordinator coordinatorB = TaskOccurrenceCoordinator(
        scope: b,
        taskRepository: tasksB,
        occurrenceRepository: _occurrences(b),
      );

      await retainedA.complete('retained');
      expect(tasksA.values['retained']?.isCompleted, isTrue);
      expect(tasksB.values['retained']?.isCompleted, isFalse);
      expect(
        await _occurrences(b).getOccurrence(
          'retained',
          TaskOccurrence.occurrenceKeyFor(_task('retained')),
        ),
        isNull,
      );
      await coordinatorB.skip('retained');
      expect(tasksB.values['retained']?.isSkipped, isTrue);
    },
  );

  test('legacy timeline data is inert to the occurrence authority', () async {
    final HiveStorage<String> legacyTimeline = HiveStorage<String>(
      HiveBoxes.accountScoped(HiveBoxes.timeline, a),
      hive: _hive,
    );
    const String sentinel = '[{"legacy":"timeline"}]';
    await legacyTimeline.put('timeline_events_v2', sentinel);
    final _Tasks tasks = _Tasks(<TaskEntity>[_task('legacy-inert')]);

    await TaskOccurrenceCoordinator(
      scope: a,
      taskRepository: tasks,
      occurrenceRepository: _occurrences(a),
    ).complete('legacy-inert');

    expect(legacyTimeline.get('timeline_events_v2'), sentinel);
  });
}
