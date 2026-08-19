import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountStorageScope scope;
  final ITaskRepository taskRepository;
  final TaskOccurrenceRepository occurrenceRepository;
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
          await _mutate(
            taskId: taskId,
            outcome: outcome,
            scheduledFor: scheduledFor,
            operationId: operationId,
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
    if (taskId.trim().isEmpty) throw StateError('Task not found');
    final TaskEntity? current = await taskRepository.getTaskById(taskId);
    if (current == null) throw StateError('Task not found');

    final String occurrenceKey = TaskOccurrence.occurrenceKeyFor(current);
    TaskOccurrence occurrence =
        await occurrenceRepository.getOccurrence(taskId, occurrenceKey) ??
        TaskOccurrence(
          taskId: taskId,
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
      return TaskOccurrenceResult(
        mutation: TaskOccurrenceMutation.idempotent,
        occurrence: occurrence,
        task: current,
        successor: await _existingSuccessor(current, occurrence),
      );
    }
    final TaskOccurrenceOutcome? terminal = occurrence.terminalOutcome;
    if (terminal != null) {
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

    final TaskOccurrencePendingOperation pending =
        existingPending ??
        TaskOccurrencePendingOperation(
          operationId: resolvedOperationId,
          outcome: outcome,
          at: _clock(),
          rescheduledFor: scheduledFor,
        );
    if (existingPending == null) {
      occurrence = occurrence.copyWith(pendingOperation: pending);
      await occurrenceRepository.save(occurrence);
    }

    final _TaskMutation mutation = _taskMutation(current, occurrence, pending);
    await taskRepository.saveTask(mutation.task);
    if (mutation.successor != null) {
      await taskRepository.saveTask(mutation.successor!);
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
      clearPendingOperation: true,
    );
    await occurrenceRepository.save(committed);
    return TaskOccurrenceResult(
      mutation: TaskOccurrenceMutation.applied,
      occurrence: committed,
      task: mutation.task,
      successor: mutation.successor,
    );
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
    final Duration offset = source.recurrenceRule == RecurrenceRule.daily
        ? const Duration(days: 1)
        : const Duration(days: 7);
    DateTime next =
        (occurrence.initialScheduledFor ?? source.scheduledFor ?? now).add(
          offset,
        );
    while (!next.isAfter(now)) {
      next = next.add(offset);
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
      occurrenceKey: next.toUtc().toIso8601String(),
    );
  }

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
}

class _TaskMutation {
  const _TaskMutation(this.task, this.successor);
  final TaskEntity task;
  final TaskEntity? successor;
}
