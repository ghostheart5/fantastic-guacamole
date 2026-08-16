import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_completion_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_sync_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/remote/goals_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/habit_occurrences_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/habits_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/notes_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/settings_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/task_occurrences_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/tasks_remote_gateway.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_projection_work_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/neural_history_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/supabase_sync_executor.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_projection_work.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/history/timeline_history_adapter.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_completion_event_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_downstream_adapters.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_projection_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

class _Timeline implements ITimelineRepository {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];
  bool failNextAdd = false;
  Completer<void>? holdNextAdd;
  final Completer<void> nextAddStarted = Completer<void>();

  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    if (failNextAdd) {
      failNextAdd = false;
      throw StateError('timeline failure');
    }
    if (!nextAddStarted.isCompleted) nextAddStarted.complete();
    final Completer<void>? gate = holdNextAdd;
    if (gate != null) await gate.future;
    events.add(event);
  }

  @override
  List<TimelineEventEntity> getEvents() =>
      List<TimelineEventEntity>.from(events);
  @override
  Future<void> removeEvent(String id) async =>
      events.removeWhere((TimelineEventEntity event) => event.id == id);
  @override
  Future<void> saveEvents(List<TimelineEventEntity> values) async {
    events
      ..clear()
      ..addAll(values);
  }
}

class _Completion implements ICompletionEventRepository {
  final List<CompletionEventEntity> events = <CompletionEventEntity>[];
  bool failNextAdd = false;
  @override
  Future<void> addEvent(CompletionEventEntity event) async {
    if (failNextAdd) {
      failNextAdd = false;
      throw StateError('completion failure');
    }
    events.add(event);
  }

  @override
  List<CompletionEventEntity> getEvents() =>
      List<CompletionEventEntity>.from(events);
  @override
  Future<void> removeEvent(String id) async =>
      events.removeWhere((CompletionEventEntity event) => event.id == id);
  @override
  Future<void> saveEvents(List<CompletionEventEntity> values) async {
    events
      ..clear()
      ..addAll(values);
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
  Future<void> removeById(String id) async =>
      values.removeWhere((SyncOperation item) => item.operationId == id);
  @override
  Future<void> update(SyncOperation updated) async {
    await overwrite(
      values
          .map(
            (SyncOperation item) =>
                item.operationId == updated.operationId ? updated : item,
          )
          .toList(growable: false),
    );
  }
}

class _WorkRepository extends TaskOccurrenceProjectionWorkRepository {
  _WorkRepository() : super.unavailable();

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

class _OccurrenceRepository extends TaskOccurrenceRepository {
  _OccurrenceRepository(this.occurrence) : super.unavailable();

  final TaskOccurrence occurrence;

  @override
  Future<TaskOccurrence?> getByOccurrenceId(String occurrenceId) =>
      Future<TaskOccurrence?>.value(
        occurrence.id == occurrenceId ? occurrence : null,
      );
}

class _ToggleDispatcher extends SyncMutationDispatcher {
  _ToggleDispatcher(this.queue)
    : super(queueStore: queue, userId: 'account-a', isAuthorized: () => true);

  final _Queue queue;
  bool acceptsWrites = true;

  @override
  Future<bool> enqueueUpsert({
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    if (!acceptsWrites) return false;
    return super.enqueueUpsert(
      tableName: tableName,
      recordId: recordId,
      payload: payload,
    );
  }
}

class _FailOnceNeuralAdapter extends TaskOccurrenceNeuralAdapter {
  _FailOnceNeuralAdapter(super.store);

  bool fail = true;

  @override
  Future<bool> record(
    TaskOccurrenceTransition transition,
    TaskOccurrenceProjectionWork work,
  ) async {
    if (fail) {
      fail = false;
      throw StateError('neural failure');
    }
    return super.record(transition, work);
  }
}

TaskOccurrence _occurrence() => TaskOccurrence(
  taskId: 'task-a',
  occurrenceKey: 'key-a',
  initialScheduledFor: DateTime.utc(2026, 8, 15, 10),
  transitions: <TaskOccurrenceTransition>[
    TaskOccurrenceTransition(
      operationId: 'move-a',
      outcome: TaskOccurrenceOutcome.rescheduled,
      at: DateTime.utc(2026, 8, 15, 11),
      rescheduledFor: DateTime.utc(2026, 8, 16, 10),
    ),
    TaskOccurrenceTransition(
      operationId: 'complete-a',
      outcome: TaskOccurrenceOutcome.completed,
      at: DateTime.utc(2026, 8, 16, 10),
    ),
  ],
);

TaskOccurrence _completedOccurrence(String id) => TaskOccurrence(
  taskId: id,
  occurrenceKey: 'key-$id',
  initialScheduledFor: DateTime.utc(2026, 8, 15, 10),
  transitions: <TaskOccurrenceTransition>[
    TaskOccurrenceTransition(
      operationId: 'complete-$id',
      outcome: TaskOccurrenceOutcome.completed,
      at: DateTime.utc(2026, 8, 16, 10),
    ),
  ],
);

TaskOccurrenceProjectionCoordinator _coordinator({
  required _Timeline timeline,
  required _Completion completion,
  required _ToggleDispatcher dispatcher,
  required _WorkRepository work,
  required _OccurrenceRepository occurrences,
  required List<String> learning,
  required List<String> logs,
  required NeuralHistoryStore neuralStore,
  OccurrenceLearningWrite? learningWrite,
  OccurrenceLogWrite? logWrite,
  TaskOccurrenceNeuralAdapter? neural,
}) => TaskOccurrenceProjectionCoordinator(
  scope: AccountStorageScope.authenticated('account-a'),
  timeline: TaskOccurrenceTimelineAdapter(timeline),
  completion: TaskOccurrenceCompletionAdapter(completion),
  sync: TaskOccurrenceSyncAdapter(dispatcher),
  workRepository: work,
  occurrenceRepository: occurrences,
  learning: TaskOccurrenceLearningAdapter(
    learningWrite ??
        ({required bool success, required int difficulty}) async {
          learning.add('$success:$difficulty');
        },
  ),
  log: TaskOccurrenceLogAdapter(
    logWrite ?? (entry) async => logs.add(entry.id),
  ),
  neural: neural ?? TaskOccurrenceNeuralAdapter(neuralStore),
);

SupabaseSyncExecutor _executor(TaskOccurrencesRemoteGateway gateway) =>
    SupabaseSyncExecutor(
      tasksGateway: const TasksRemoteGateway(null),
      goalsGateway: const GoalsRemoteGateway(null),
      habitsGateway: const HabitsRemoteGateway(null),
      habitOccurrencesGateway: const HabitOccurrencesRemoteGateway(null),
      taskOccurrencesGateway: gateway,
      settingsGateway: const SettingsRemoteGateway(null),
      notesGateway: const NotesRemoteGateway(null),
    );

SyncOperation _occurrenceOperation() => SyncOperation(
  operationId: 'sync-task-occurrence',
  tableName: 'task_occurrences',
  recordId: 'task-a::key-a::complete-a',
  operationType: SyncOperationType.update,
  payload: const <String, dynamic>{
    'id': 'task-a::key-a::complete-a',
    'task_id': 'task-a',
    'occurrence_key': 'key-a',
    'operation_id': 'complete-a',
    'outcome': 'completed',
  },
  userId: 'account-a',
  createdAtUtc: DateTime.utc(2026, 8, 16),
  retryCount: 0,
  nextRetryAtUtc: null,
  lastError: null,
);

void main() {
  test(
    'typed Timeline projection is deterministic, linked, and retry-safe',
    () async {
      final _Timeline timeline = _Timeline();
      final TaskOccurrence occurrence = _occurrence();
      final TaskOccurrenceTimelineAdapter adapter =
          TaskOccurrenceTimelineAdapter(timeline);

      await adapter.record(occurrence, taskTitle: 'Canonical task');
      await adapter.record(occurrence, taskTitle: 'Canonical task');

      expect(timeline.events, hasLength(2));
      expect(timeline.events.first.type, TimelineEventType.taskRescheduled);
      expect(timeline.events.last.type, TimelineEventType.taskCompleted);
      expect(
        timeline.events.every(
          (TimelineEventEntity item) => item.relatedId == 'task-a',
        ),
        isTrue,
      );
      expect(
        timeline.events.last.id,
        'task-occurrence:${occurrence.id}:complete-a',
      );
      expect(
        TimelineHistoryAdapter.toHistory(timeline.events.last).kind.name,
        'taskCompleted',
      );
    },
  );

  test(
    'Timeline projection failure is retryable without another occurrence',
    () async {
      final _Timeline timeline = _Timeline()..failNextAdd = true;
      final TaskOccurrenceTimelineAdapter adapter =
          TaskOccurrenceTimelineAdapter(timeline);
      final TaskOccurrence occurrence = _occurrence();

      await expectLater(adapter.record(occurrence), throwsStateError);
      expect(timeline.events, isEmpty);
      await adapter.record(occurrence);
      expect(timeline.events, hasLength(2));
    },
  );

  test(
    'completion ledger is a typed idempotent compatibility projection',
    () async {
      final _Completion ledger = _Completion();
      final TaskOccurrence occurrence = _occurrence();
      final TaskOccurrenceCompletionAdapter adapter =
          TaskOccurrenceCompletionAdapter(ledger);

      await adapter.record(occurrence);
      await adapter.record(occurrence);

      expect(ledger.events, hasLength(2));
      expect(ledger.events.last.eventType, CompletionEventType.completed);
      expect(ledger.events.last.metadata['occurrenceId'], occurrence.id);
      await ledger.removeEvent(ledger.events.last.id);
      expect(ledger.events, hasLength(1));
    },
  );

  test(
    'sync payload has canonical transition fields and queue dedupes retries',
    () async {
      final _Queue queue = _Queue();
      final TaskOccurrenceSyncAdapter adapter = TaskOccurrenceSyncAdapter(
        SyncMutationDispatcher(
          queueStore: queue,
          userId: 'account-a',
          isAuthorized: () => true,
        ),
      );
      final TaskOccurrence occurrence = _occurrence();

      await adapter.enqueue(occurrence);
      await adapter.enqueue(occurrence);

      expect(queue.values, hasLength(2));
      expect(
        queue.values.every(
          (SyncOperation item) => item.tableName == 'task_occurrences',
        ),
        isTrue,
      );
      expect(queue.values.last.payload['outcome'], 'completed');
      expect(queue.values.last.payload['task_id'], 'task-a');
      expect(queue.values.last.payload['operation_id'], 'complete-a');
    },
  );

  test(
    'executor awaits task occurrence gateway and classifies failures',
    () async {
      final List<Map<String, dynamic>> applied = <Map<String, dynamic>>[];
      final SupabaseSyncExecutor success = _executor(
        TaskOccurrencesRemoteGateway(
          null,
          upsertOverride: (Map<String, dynamic> row) async {
            applied.add(row);
          },
        ),
      );
      final SyncApplyResult successResult = await success.apply(
        _occurrenceOperation(),
      );
      expect(successResult.ok, isTrue);
      expect(applied.single['operation_id'], 'complete-a');

      final SupabaseSyncExecutor retryable = _executor(
        TaskOccurrencesRemoteGateway(
          null,
          upsertOverride: (_) async => throw StateError('network timeout'),
        ),
      );
      expect(
        (await retryable.apply(_occurrenceOperation())).shouldRetry,
        isTrue,
      );

      final SupabaseSyncExecutor fatal = _executor(
        TaskOccurrencesRemoteGateway(
          null,
          upsertOverride: (_) async => throw StateError('constraint rejected'),
        ),
      );
      final SyncApplyResult fatalResult = await fatal.apply(
        _occurrenceOperation(),
      );
      expect(fatalResult.ok, isFalse);
      expect(fatalResult.shouldRetry, isFalse);
    },
  );

  test(
    'durable projection work reconciles failed Timeline and Sync stages once',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence('restart-a');
      final _Timeline timeline = _Timeline()..failNextAdd = true;
      final _Completion completion = _Completion();
      final _Queue queue = _Queue();
      final _ToggleDispatcher dispatcher = _ToggleDispatcher(queue)
        ..acceptsWrites = false;
      final _WorkRepository work = _WorkRepository();
      final _OccurrenceRepository occurrences = _OccurrenceRepository(
        occurrence,
      );
      final List<String> learning = <String>[];
      final List<String> logs = <String>[];
      final NeuralHistoryStore neural = NeuralHistoryStore(
        scope: AccountStorageScope.authenticated('account-a'),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      );
      final TaskOccurrenceProjectionContext context =
          const TaskOccurrenceProjectionContext(
            taskTitle: 'Restart-safe task',
            taskDifficulty: 2,
            durationSeconds: 600,
            quality: 0.9,
          );

      final TaskOccurrenceProjectionCoordinator first = _coordinator(
        timeline: timeline,
        completion: completion,
        dispatcher: dispatcher,
        work: work,
        occurrences: occurrences,
        learning: learning,
        logs: logs,
        neuralStore: neural,
      );
      await first.project(occurrence, context: context);

      final TaskOccurrenceProjectionWork pending = work.values.values.single;
      expect(pending.isPending(TaskOccurrenceProjectionStage.timeline), isTrue);
      expect(pending.isPending(TaskOccurrenceProjectionStage.sync), isTrue);
      expect(completion.events, hasLength(1));
      expect(learning, <String>['true:2']);
      expect(logs, hasLength(1));

      dispatcher.acceptsWrites = true;
      final TaskOccurrenceProjectionCoordinator restarted = _coordinator(
        timeline: timeline,
        completion: completion,
        dispatcher: dispatcher,
        work: work,
        occurrences: occurrences,
        learning: learning,
        logs: logs,
        neuralStore: neural,
      );
      await restarted.reconcile();

      final TaskOccurrenceProjectionWork settled = work.values.values.single;
      expect(
        settled.isPending(TaskOccurrenceProjectionStage.timeline),
        isFalse,
      );
      expect(settled.isPending(TaskOccurrenceProjectionStage.sync), isFalse);
      expect(timeline.events, hasLength(1));
      expect(completion.events, hasLength(1));
      expect(queue.values, hasLength(1));
      expect(learning, <String>['true:2']);
      expect(logs, hasLength(1));
      expect(await neural.loadNeuralHistory(), hasLength(1));
    },
  );

  test(
    'retained A coordinator cannot project into a direct B fixture',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence('stale-a');
      final _Timeline aTimeline = _Timeline();
      final _Completion aCompletion = _Completion();
      final _Queue aQueue = _Queue();
      final _ToggleDispatcher aDispatcher = _ToggleDispatcher(aQueue);
      final List<String> aLearning = <String>[];
      final List<String> aLogs = <String>[];
      final TaskOccurrenceProjectionCoordinator retainedA = _coordinator(
        timeline: aTimeline,
        completion: aCompletion,
        dispatcher: aDispatcher,
        work: _WorkRepository(),
        occurrences: _OccurrenceRepository(occurrence),
        learning: aLearning,
        logs: aLogs,
        neuralStore: NeuralHistoryStore(
          scope: AccountStorageScope.authenticated('account-a'),
          secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      );

      // The deliberately separate B recorders model a direct-fixture B
      // construction. Retained A adapters must not resolve or touch them.
      final _Timeline bTimeline = _Timeline();
      final _Completion bCompletion = _Completion();
      final _Queue bQueue = _Queue();
      await retainedA.project(
        occurrence,
        context: const TaskOccurrenceProjectionContext(
          taskTitle: 'A only',
          taskDifficulty: 3,
        ),
      );

      expect(aTimeline.events, hasLength(1));
      expect(aCompletion.events, hasLength(1));
      expect(aQueue.values, hasLength(1));
      expect(aLearning, <String>['true:3']);
      expect(aLogs, hasLength(1));
      expect(bTimeline.events, isEmpty);
      expect(bCompletion.events, isEmpty);
      expect(bQueue.values, isEmpty);
    },
  );

  test(
    'completion work resumes after restart without repeating done stages',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence('ledger-a');
      final _Timeline timeline = _Timeline();
      final _Completion completion = _Completion()..failNextAdd = true;
      final _Queue queue = _Queue();
      final _ToggleDispatcher dispatcher = _ToggleDispatcher(queue);
      final _WorkRepository work = _WorkRepository();
      final List<String> learning = <String>[];
      final List<String> logs = <String>[];
      final NeuralHistoryStore neural = NeuralHistoryStore(
        scope: AccountStorageScope.authenticated('account-a'),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      );
      final TaskOccurrenceProjectionContext context =
          const TaskOccurrenceProjectionContext(
            taskTitle: 'Compatibility retry',
            taskDifficulty: 4,
          );
      await _coordinator(
        timeline: timeline,
        completion: completion,
        dispatcher: dispatcher,
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: learning,
        logs: logs,
        neuralStore: neural,
      ).project(occurrence, context: context);

      expect(
        work.values.values.single.isPending(
          TaskOccurrenceProjectionStage.completionLedger,
        ),
        isTrue,
      );
      expect(timeline.events, hasLength(1));
      expect(queue.values, hasLength(1));

      await _coordinator(
        timeline: timeline,
        completion: completion,
        dispatcher: dispatcher,
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: learning,
        logs: logs,
        neuralStore: neural,
      ).reconcile();

      expect(completion.events, hasLength(1));
      expect(timeline.events, hasLength(1));
      expect(queue.values, hasLength(1));
      expect(learning, <String>['true:4']);
      expect(logs, hasLength(1));
    },
  );

  test(
    'legacy V2 projection sentinels remain separate during new projections',
    () async {
      final _Timeline timeline = _Timeline()
        ..events.add(
          TimelineEventEntity(
            id: 'LEGACY_TIMELINE_EVENT_V2',
            type: TimelineEventType.reflection,
            title: 'legacy timeline',
            detail: 'preserve',
            timestamp: DateTime.utc(2026, 8, 1),
          ),
        );
      final _Completion completion = _Completion()
        ..events.add(
          CompletionEventEntity(
            id: 'LEGACY_COMPLETION_EVENT_V2',
            eventType: CompletionEventType.completed,
            eventAt: DateTime.utc(2026, 8, 1),
            taskId: 'legacy-task',
          ),
        );
      final TaskOccurrence occurrence = _completedOccurrence('new-task');
      await TaskOccurrenceTimelineAdapter(timeline).record(occurrence);
      await TaskOccurrenceCompletionAdapter(completion).record(occurrence);

      expect(timeline.events.first.id, 'LEGACY_TIMELINE_EVENT_V2');
      expect(completion.events.first.id, 'LEGACY_COMPLETION_EVENT_V2');
      expect(timeline.events, hasLength(2));
      expect(completion.events, hasLength(2));
    },
  );

  test(
    'concurrent distinct occurrence projections retain both ledgers',
    () async {
      final _Timeline timeline = _Timeline();
      final _Completion completion = _Completion();
      final TaskOccurrence first = _completedOccurrence('append-one');
      final TaskOccurrence second = _completedOccurrence('append-two');
      await Future.wait<void>(<Future<void>>[
        TaskOccurrenceTimelineAdapter(timeline).record(first),
        TaskOccurrenceTimelineAdapter(timeline).record(second),
        TaskOccurrenceCompletionAdapter(completion).record(first),
        TaskOccurrenceCompletionAdapter(completion).record(second),
      ]);

      expect(
        timeline.events.map((TimelineEventEntity item) => item.id),
        hasLength(2),
      );
      expect(
        completion.events.map((CompletionEventEntity item) => item.id),
        hasLength(2),
      );
    },
  );

  test(
    'Learning failure is terminal best effort without changing occurrence truth',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence(
        'learning-failure',
      );
      final _WorkRepository work = _WorkRepository();
      final TaskOccurrenceProjectionCoordinator coordinator = _coordinator(
        timeline: _Timeline(),
        completion: _Completion(),
        dispatcher: _ToggleDispatcher(_Queue()),
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: <String>[],
        logs: <String>[],
        neuralStore: NeuralHistoryStore(
          scope: AccountStorageScope.authenticated('account-a'),
          secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        learningWrite:
            ({required bool success, required int difficulty}) async {
              throw StateError('learning write failed');
            },
      );

      await coordinator.project(
        occurrence,
        context: const TaskOccurrenceProjectionContext(
          taskTitle: 'Learning failure',
          taskDifficulty: 2,
        ),
      );

      final TaskOccurrenceProjectionWork result = work.values.values.single;
      expect(
        result.stages[TaskOccurrenceProjectionStage.learning],
        TaskOccurrenceProjectionStageState.terminal,
      );
      expect(occurrence.transitions, hasLength(1));
    },
  );

  test(
    'Log failure remains pending then retries as one deterministic log',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence('log-failure');
      final _WorkRepository work = _WorkRepository();
      final List<String> logs = <String>[];
      await _coordinator(
        timeline: _Timeline(),
        completion: _Completion(),
        dispatcher: _ToggleDispatcher(_Queue()),
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: <String>[],
        logs: logs,
        neuralStore: NeuralHistoryStore(
          scope: AccountStorageScope.authenticated('account-a'),
          secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        logWrite: (LogEntryEntity entry) async {
          throw StateError('log write failed');
        },
      ).project(
        occurrence,
        context: const TaskOccurrenceProjectionContext(
          taskTitle: 'Log failure',
          taskDifficulty: 2,
        ),
      );
      expect(
        work.values.values.single.isPending(TaskOccurrenceProjectionStage.log),
        isTrue,
      );

      await _coordinator(
        timeline: _Timeline(),
        completion: _Completion(),
        dispatcher: _ToggleDispatcher(_Queue()),
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: <String>[],
        logs: logs,
        neuralStore: NeuralHistoryStore(
          scope: AccountStorageScope.authenticated('account-a'),
          secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ).reconcile();
      expect(
        work.values.values.single.isPending(TaskOccurrenceProjectionStage.log),
        isFalse,
      );
      expect(logs, <String>[
        'task-occurrence-log:${occurrence.id}::complete-log-failure',
      ]);
    },
  );

  test(
    'Neural failure remains pending then records one logical entry',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence('neural-failure');
      final _WorkRepository work = _WorkRepository();
      final NeuralHistoryStore neural = NeuralHistoryStore(
        scope: AccountStorageScope.authenticated('account-a'),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      );
      await _coordinator(
        timeline: _Timeline(),
        completion: _Completion(),
        dispatcher: _ToggleDispatcher(_Queue()),
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: <String>[],
        logs: <String>[],
        neuralStore: neural,
        neural: _FailOnceNeuralAdapter(neural),
      ).project(
        occurrence,
        context: const TaskOccurrenceProjectionContext(
          taskTitle: 'Neural failure',
          taskDifficulty: 2,
        ),
      );
      expect(
        work.values.values.single.isPending(
          TaskOccurrenceProjectionStage.neural,
        ),
        isTrue,
      );

      await _coordinator(
        timeline: _Timeline(),
        completion: _Completion(),
        dispatcher: _ToggleDispatcher(_Queue()),
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: <String>[],
        logs: <String>[],
        neuralStore: neural,
      ).reconcile();
      expect(
        work.values.values.single.isPending(
          TaskOccurrenceProjectionStage.neural,
        ),
        isFalse,
      );
      expect(await neural.loadNeuralHistory(), hasLength(1));
    },
  );

  test(
    'tracked startup reconciliation is drained before its paused write completes',
    () async {
      final TaskOccurrence occurrence = _completedOccurrence('startup-drain');
      final _Timeline timeline = _Timeline()..holdNextAdd = Completer<void>();
      final _WorkRepository work = _WorkRepository();
      await work.save(
        TaskOccurrenceProjectionWork(
          occurrenceId: occurrence.id,
          operationId: occurrence.transitions.single.operationId,
          taskTitle: 'Startup drain',
          taskDifficulty: 2,
          transitionAt: occurrence.transitions.single.at,
          stages:
              <
                TaskOccurrenceProjectionStage,
                TaskOccurrenceProjectionStageState
              >{
                TaskOccurrenceProjectionStage.timeline:
                    TaskOccurrenceProjectionStageState.pending,
                TaskOccurrenceProjectionStage.completionLedger:
                    TaskOccurrenceProjectionStageState.terminal,
                TaskOccurrenceProjectionStage.sync:
                    TaskOccurrenceProjectionStageState.terminal,
                TaskOccurrenceProjectionStage.learning:
                    TaskOccurrenceProjectionStageState.terminal,
                TaskOccurrenceProjectionStage.log:
                    TaskOccurrenceProjectionStageState.terminal,
                TaskOccurrenceProjectionStage.neural:
                    TaskOccurrenceProjectionStageState.terminal,
              },
        ),
      );
      final TaskOccurrenceProjectionCoordinator coordinator = _coordinator(
        timeline: timeline,
        completion: _Completion(),
        dispatcher: _ToggleDispatcher(_Queue()),
        work: work,
        occurrences: _OccurrenceRepository(occurrence),
        learning: <String>[],
        logs: <String>[],
        neuralStore: NeuralHistoryStore(
          scope: AccountStorageScope.authenticated('account-a'),
          secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      );

      unawaited(coordinator.reconcile());
      await timeline.nextAddStarted.future;
      bool drained = false;
      final Future<void> drain = coordinator.cancelAndDrain().then((_) {
        drained = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      timeline.holdNextAdd!.complete();
      await drain;
      expect(timeline.events, hasLength(1));
    },
  );
}
