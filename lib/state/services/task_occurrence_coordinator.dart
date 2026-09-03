import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/services/task_occurrence_cloud_replica.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:timezone/timezone.dart' as tz;

enum TaskOccurrenceMutation { applied, idempotent, conflict }

class TaskOccurrenceResult {
  const TaskOccurrenceResult({
    required this.mutation,
    required this.occurrence,
    required this.task,
    this.successor,
  });

  final TaskOccurrenceMutation mutation;
  final TaskOccurrence occurrence;
  final TaskEntity task;
  final TaskEntity? successor;
}

/// Serializes durable task state with a restart-safe occurrence ledger.
class TaskOccurrenceCoordinator {
  TaskOccurrenceCoordinator({
    required this.scope,
    required this.taskRepository,
    required this.occurrenceRepository,
    this.cloudReplica,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountStorageScope scope;
  final ITaskRepository taskRepository;
  final TaskOccurrenceRepository occurrenceRepository;
  final TaskOccurrenceCloudReplica? cloudReplica;
  final DateTime Function() _clock;
  bool _cancelled = false;
  Future<void> _tail = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _tail.catchError((Object _) {});
    await occurrenceRepository.cancelAndDrain();
  }

  void dispose() => _cancelled = true;

  Future<TaskOccurrenceResult> complete(String taskId, {String? operationId}) =>
      _enqueue(
        taskId: taskId,
        outcome: TaskOccurrenceOutcome.completed,
        operationId: operationId,
      );

  Future<TaskOccurrenceResult> skip(String taskId, {String? operationId}) =>
      _enqueue(
        taskId: taskId,
        outcome: TaskOccurrenceOutcome.skipped,
        operationId: operationId,
      );

  Future<TaskOccurrenceResult> reschedule(
    String taskId, {
    required DateTime scheduledFor,
    String? operationId,
  }) => _enqueue(
    taskId: taskId,
    outcome: TaskOccurrenceOutcome.rescheduled,
    scheduledFor: scheduledFor,
    operationId: operationId,
  );

  Future<TaskOccurrenceResult> _enqueue({
    required String taskId,
    required TaskOccurrenceOutcome outcome,
    DateTime? scheduledFor,
    String? operationId,
  }) {
    if (_cancelled || !scope.isWritable) {
      return Future<TaskOccurrenceResult>.error(
        StateError(
          'Task occurrence mutation is unavailable during account transition.',
        ),
      );
    }
    final Completer<TaskOccurrenceResult> result =
        Completer<TaskOccurrenceResult>();
    final Future<void> next = _tail.then((_) async {
      try {
        if (_cancelled) {
          throw StateError(
            'Task occurrence mutation canceled during account transition.',
          );
        }
        result.complete(
          await _TaskOccurrenceMutationLocks.run(
            '${scope.v2Namespace}|$taskId',
            () => _mutate(
              taskId: taskId,
              outcome: outcome,
              scheduledFor: scheduledFor,
              operationId: operationId,
            ),
          ),
        );
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _tail = next.catchError((Object _) {});
    return result.future;
  }

  Future<TaskOccurrenceResult> _mutate({
    required String taskId,
    required TaskOccurrenceOutcome outcome,
    required DateTime? scheduledFor,
    required String? operationId,
  }) async {
    _ensureActive();
    if (taskId.trim().isEmpty) throw StateError('Task not found');
    final TaskEntity? current = await taskRepository.getTaskById(taskId);
    _ensureActive();
    if (current == null) throw StateError('Task not found');

    final String occurrenceKey = TaskOccurrence.occurrenceKeyFor(current);
    TaskOccurrence occurrence =
        await occurrenceRepository.getOccurrence(taskId, occurrenceKey) ??
        TaskOccurrence(
          taskId: taskId,
          seriesId: TaskOccurrence.seriesIdFor(current),
          occurrenceKey: occurrenceKey,
          initialScheduledFor: current.scheduledFor,
        );
    final String resolvedOperationId =
        operationId ??
        _operationId(
          occurrence: occurrence,
          outcome: outcome,
          scheduledFor: scheduledFor,
        );

    if (occurrence.hasCommittedOperation(resolvedOperationId)) {
      occurrence = await _replicatePending(occurrence);
      return TaskOccurrenceResult(
        mutation: TaskOccurrenceMutation.idempotent,
        occurrence: occurrence,
        task: current,
        successor: await _existingSuccessor(current, occurrence),
      );
    }
    final TaskOccurrenceOutcome? terminal = occurrence.terminalOutcome;
    if (terminal != null) {
      occurrence = await _replicatePending(occurrence);
      return TaskOccurrenceResult(
        mutation: terminal == outcome
            ? TaskOccurrenceMutation.idempotent
            : TaskOccurrenceMutation.conflict,
        occurrence: occurrence,
        task: current,
        successor: await _existingSuccessor(current, occurrence),
      );
    }
    final TaskOccurrencePendingOperation? existingPending =
        occurrence.pendingOperation;
    if (existingPending != null &&
        existingPending.operationId != resolvedOperationId) {
      return TaskOccurrenceResult(
        mutation: TaskOccurrenceMutation.conflict,
        occurrence: occurrence,
        task: current,
      );
    }

    if (existingPending != null &&
        (existingPending.outcome != outcome ||
            existingPending.rescheduledFor != scheduledFor)) {
      return TaskOccurrenceResult(
        mutation: TaskOccurrenceMutation.conflict,
        occurrence: occurrence,
        task: current,
      );
    }

    final DateTime mutationAt = existingPending?.at ?? _clock();
    if (!current.isActionableAt(mutationAt) &&
        !_matchesTerminalOutcome(
          current,
          existingPending?.outcome ?? outcome,
        )) {
      return TaskOccurrenceResult(
        mutation: TaskOccurrenceMutation.conflict,
        occurrence: occurrence,
        task: current,
        successor: await _existingSuccessor(current, occurrence),
      );
    }
    if (existingPending == null && !current.isActionableAt(mutationAt)) {
      return TaskOccurrenceResult(
        mutation: TaskOccurrenceMutation.idempotent,
        occurrence: occurrence,
        task: current,
        successor: await _existingSuccessor(current, occurrence),
      );
    }

    final TaskOccurrencePendingOperation pending =
        existingPending ??
        TaskOccurrencePendingOperation(
          operationId: resolvedOperationId,
          outcome: outcome,
          at: mutationAt,
          rescheduledFor: scheduledFor,
        );
    if (existingPending == null) {
      occurrence = occurrence.copyWith(pendingOperation: pending);
      await occurrenceRepository.save(occurrence);
      _ensureActive();
    }

    final _TaskMutation mutation = _taskMutation(current, occurrence, pending);
    await taskRepository.saveTask(mutation.task);
    _ensureActive();
    if (mutation.successor != null) {
      await taskRepository.saveTask(mutation.successor!);
      _ensureActive();
    }

    final TaskOccurrence committed = occurrence.copyWith(
      transitions: <TaskOccurrenceTransition>[
        ...occurrence.transitions,
        TaskOccurrenceTransition(
          operationId: pending.operationId,
          outcome: pending.outcome,
          at: pending.at,
          rescheduledFor: pending.rescheduledFor,
        ),
      ],
      pendingCloudOperationIds: <String>{
        ...occurrence.pendingCloudOperationIds,
        pending.operationId,
      },
      clearPendingOperation: true,
    );
    await occurrenceRepository.save(committed);
    _ensureActive();
    final TaskOccurrence replicated = await _replicatePending(committed);
    return TaskOccurrenceResult(
      mutation: TaskOccurrenceMutation.applied,
      occurrence: replicated,
      task: mutation.task,
      successor: mutation.successor,
    );
  }

  Future<int> retryPendingCloudReplication() async {
    _ensureActive();
    int delivered = 0;
    for (final TaskOccurrence occurrence
        in await occurrenceRepository.listOccurrences()) {
      final int before = occurrence.pendingCloudOperationIds.length;
      final TaskOccurrence after = await _TaskOccurrenceMutationLocks.run(
        '${scope.v2Namespace}|${occurrence.taskId}',
        () => _replicatePending(occurrence),
      );
      delivered += before - after.pendingCloudOperationIds.length;
    }
    return delivered;
  }

  Future<TaskOccurrence> _replicatePending(TaskOccurrence occurrence) async {
    final TaskOccurrenceCloudReplica? replica = cloudReplica;
    final String? expectedUserId = scope.rawUserId;
    if (replica == null || expectedUserId == null) return occurrence;
    TaskOccurrence current = occurrence;
    for (final TaskOccurrenceTransition transition
        in occurrence.pendingCloudTransitions) {
      _ensureActive();
      bool delivered = false;
      try {
        delivered = await replica.replicate(
          expectedUserId: expectedUserId,
          occurrence: current,
          transition: transition,
        );
      } on Object {
        delivered = false;
      }
      _ensureActive();
      if (!delivered) continue;
      current = current.copyWith(
        pendingCloudOperationIds: <String>{...current.pendingCloudOperationIds}
          ..remove(transition.operationId),
      );
      await occurrenceRepository.save(current);
      _ensureActive();
    }
    return current;
  }

  void _ensureActive() {
    if (_cancelled || !scope.isWritable) {
      throw StateError(
        'Task occurrence mutation canceled during account transition.',
      );
    }
  }

  _TaskMutation _taskMutation(
    TaskEntity current,
    TaskOccurrence occurrence,
    TaskOccurrencePendingOperation pending,
  ) {
    final DateTime updatedAt = pending.at;
    switch (pending.outcome) {
      case TaskOccurrenceOutcome.completed:
        final TaskEntity completed = current.copyWith(
          occurrenceKey: occurrence.occurrenceKey,
          isCompleted: true,
          isSkipped: false,
          isCanceled: false,
          completedAt: pending.at,
          clearSkippedAt: true,
          updatedAt: updatedAt,
        );
        return _TaskMutation(
          completed,
          _successorFor(current, occurrence, pending.at),
        );
      case TaskOccurrenceOutcome.skipped:
        final TaskEntity skipped = current.copyWith(
          occurrenceKey: occurrence.occurrenceKey,
          isCompleted: false,
          isSkipped: true,
          isCanceled: false,
          clearCompletedAt: true,
          skippedAt: pending.at,
          updatedAt: updatedAt,
        );
        return _TaskMutation(
          skipped,
          _successorFor(current, occurrence, pending.at),
        );
      case TaskOccurrenceOutcome.rescheduled:
        final DateTime target =
            pending.rescheduledFor ??
            (throw StateError('Rescheduling requires a target time.'));
        return _TaskMutation(
          current.copyWith(
            scheduledFor: target,
            occurrenceKey: occurrence.occurrenceKey,
            updatedAt: updatedAt,
          ),
          null,
        );
    }
  }

  TaskEntity? _successorFor(
    TaskEntity source,
    TaskOccurrence occurrence,
    DateTime now,
  ) {
    if (source.recurrenceRule == RecurrenceRule.none) return null;
    final int calendarDays = source.recurrenceRule == RecurrenceRule.daily
        ? 1
        : 7;
    final DateTime scheduleAnchor =
        occurrence.initialScheduledFor ??
        source.scheduledFor ??
        source.dueDate ??
        now;
    DateTime next = _addCalendarDays(scheduleAnchor, calendarDays);
    DateTime? nextDeadline = source.dueDate == null
        ? null
        : _addCalendarDays(source.dueDate!, calendarDays);
    while (!next.isAfter(now)) {
      next = _addCalendarDays(next, calendarDays);
      if (nextDeadline != null) {
        nextDeadline = _addCalendarDays(nextDeadline, calendarDays);
      }
    }
    while (nextDeadline != null && !nextDeadline.isAfter(now)) {
      nextDeadline = _addCalendarDays(nextDeadline, calendarDays);
    }
    return source.copyWith(
      id: '${source.id}::next::${occurrence.occurrenceKey}',
      isCompleted: false,
      isSkipped: false,
      clearCompletedAt: true,
      clearSkippedAt: true,
      createdAt: now,
      updatedAt: now,
      scheduledFor: next,
      dueDate: nextDeadline,
      occurrenceKey: next.toUtc().toIso8601String(),
    );
  }

  bool _matchesTerminalOutcome(
    TaskEntity task,
    TaskOccurrenceOutcome outcome,
  ) =>
      (outcome == TaskOccurrenceOutcome.completed && task.isCompleted) ||
      (outcome == TaskOccurrenceOutcome.skipped && task.isSkipped);

  Future<TaskEntity?> _existingSuccessor(
    TaskEntity source,
    TaskOccurrence occurrence,
  ) {
    if (source.recurrenceRule == RecurrenceRule.none) {
      return Future<TaskEntity?>.value();
    }
    return taskRepository.getTaskById(_successorId(source, occurrence));
  }

  String _successorId(TaskEntity source, TaskOccurrence occurrence) =>
      '${source.id}::next::${occurrence.occurrenceKey}';

  String _operationId({
    required TaskOccurrence occurrence,
    required TaskOccurrenceOutcome outcome,
    required DateTime? scheduledFor,
  }) =>
      '${occurrence.id}::${outcome.name}'
      '${scheduledFor == null ? '' : '::${scheduledFor.toUtc().toIso8601String()}'}';

  DateTime _addCalendarDays(DateTime value, int days) {
    if (value is tz.TZDateTime) {
      return tz.TZDateTime(
        value.location,
        value.year,
        value.month,
        value.day + days,
        value.hour,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      );
    }
    if (value.isUtc) {
      return DateTime.utc(
        value.year,
        value.month,
        value.day + days,
        value.hour,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      );
    }
    return DateTime(
      value.year,
      value.month,
      value.day + days,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }
}

class _TaskOccurrenceMutationLocks {
  const _TaskOccurrenceMutationLocks._();

  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() action) {
    final Future<void> previous = _tails[key] ?? Future<void>.value();
    final Completer<T> result = Completer<T>();
    late final Future<void> current;
    current = previous
        .catchError((Object _) {})
        .then((_) async {
          try {
            result.complete(await action());
          } on Object catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_tails[key], current)) {
            unawaited(_tails.remove(key));
          }
        });
    _tails[key] = current;
    return result.future;
  }
}

class _TaskMutation {
  const _TaskMutation(this.task, this.successor);
  final TaskEntity task;
  final TaskEntity? successor;
}
