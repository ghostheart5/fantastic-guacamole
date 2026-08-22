import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_completion_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_sync_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_projection_work_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_projection_work.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_downstream_adapters.dart';

class TaskOccurrenceProjectionContext {
  const TaskOccurrenceProjectionContext({
    required this.taskTitle,
    required this.taskDifficulty,
    this.taskKind,
    this.durationSeconds,
    this.quality,
  });

  final String taskTitle;
  final int taskDifficulty;
  final String? taskKind;
  final int? durationSeconds;
  final double? quality;
}

/// Serializes replay-safe projections of already committed occurrence facts.
class TaskOccurrenceProjectionCoordinator {
  TaskOccurrenceProjectionCoordinator({
    required this.scope,
    required this.timeline,
    required this.completion,
    required this.sync,
    required this.workRepository,
    required this.occurrenceRepository,
    required this.learning,
    required this.log,
    required this.neural,
  });

  final AccountStorageScope scope;
  final TaskOccurrenceTimelineAdapter timeline;
  final TaskOccurrenceCompletionAdapter completion;
  final TaskOccurrenceSyncAdapter sync;
  final TaskOccurrenceProjectionWorkRepository workRepository;
  final TaskOccurrenceRepository occurrenceRepository;
  final TaskOccurrenceLearningAdapter learning;
  final TaskOccurrenceLogAdapter log;
  final TaskOccurrenceNeuralAdapter neural;
  Future<void> _tail = Future<void>.value();
  bool _cancelled = false;

  Future<void> project(
    TaskOccurrence occurrence, {
    required TaskOccurrenceProjectionContext context,
  }) {
    if (_cancelled || !scope.isWritable) {
      return Future<void>.error(
        StateError(
          'Task occurrence projection is unavailable during transition.',
        ),
      );
    }
    final Future<void> next = _tail.then((_) async {
      if (_cancelled) {
        throw StateError(
          'Task occurrence projection canceled during transition.',
        );
      }
      for (final TaskOccurrenceTransition transition
          in occurrence.transitions) {
        await _projectTransition(occurrence, transition, context);
      }
    });
    _tail = next.catchError((Object _) {});
    return next;
  }

  /// Replays only unfinished work using repositories and adapters captured for
  /// this account scope. It never constructs or mutates an occurrence.
  Future<void> reconcile() {
    final Future<void> next = _tail.then((_) async {
      if (_cancelled || !scope.isWritable) return;
      for (final TaskOccurrenceProjectionWork work
          in await workRepository.listPending()) {
        if (_cancelled) return;
        final TaskOccurrence? occurrence = await occurrenceRepository
            .getByOccurrenceId(work.occurrenceId);
        if (occurrence == null) continue;
        final TaskOccurrenceTransition? transition = occurrence.transitions
            .cast<TaskOccurrenceTransition?>()
            .firstWhere(
              (TaskOccurrenceTransition? value) =>
                  value?.operationId == work.operationId,
              orElse: () => null,
            );
        if (transition == null) continue;
        await _runStages(occurrence, transition, work);
      }
    });
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _projectTransition(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
    TaskOccurrenceProjectionContext context,
  ) async {
    final String workId = '${occurrence.id}::${transition.operationId}';
    TaskOccurrenceProjectionWork? work = await workRepository.getById(workId);
    work ??= TaskOccurrenceProjectionWork(
      occurrenceId: occurrence.id,
      operationId: transition.operationId,
      taskTitle: context.taskTitle,
      taskDifficulty: context.taskDifficulty,
      taskKind: context.taskKind,
      transitionAt: transition.at,
      durationSeconds: context.durationSeconds,
      quality: context.quality,
      stages: _initialStages(transition.outcome),
    );
    await workRepository.save(work);
    await _runStages(occurrence, transition, work);
  }

  Map<TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>
  _initialStages(TaskOccurrenceOutcome outcome) =>
      <TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>{
        TaskOccurrenceProjectionStage.timeline:
            TaskOccurrenceProjectionStageState.pending,
        TaskOccurrenceProjectionStage.completionLedger:
            TaskOccurrenceProjectionStageState.pending,
        TaskOccurrenceProjectionStage.sync:
            TaskOccurrenceProjectionStageState.pending,
        TaskOccurrenceProjectionStage.learning:
            outcome == TaskOccurrenceOutcome.rescheduled
            ? TaskOccurrenceProjectionStageState.terminal
            : TaskOccurrenceProjectionStageState.pending,
        TaskOccurrenceProjectionStage.log:
            TaskOccurrenceProjectionStageState.pending,
        TaskOccurrenceProjectionStage.neural:
            outcome == TaskOccurrenceOutcome.completed
            ? TaskOccurrenceProjectionStageState.pending
            : TaskOccurrenceProjectionStageState.terminal,
      };

  Future<void> _runStages(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
    TaskOccurrenceProjectionWork work,
  ) async {
    TaskOccurrenceProjectionWork current = work;
    current = await _retryable(
      current,
      TaskOccurrenceProjectionStage.timeline,
      () => timeline.recordTransition(
        occurrence,
        transition,
        taskTitle: current.taskTitle,
      ),
    );
    current = await _retryable(
      current,
      TaskOccurrenceProjectionStage.completionLedger,
      () => completion.recordTransition(
        occurrence,
        transition,
        taskKind: current.taskKind,
      ),
    );
    current = await _retryableBool(
      current,
      TaskOccurrenceProjectionStage.sync,
      () => sync.enqueueTransition(occurrence, transition),
    );
    current = await _bestEffortTerminal(
      current,
      TaskOccurrenceProjectionStage.learning,
      () => learning.record(transition, current),
    );
    current = await _retryable(
      current,
      TaskOccurrenceProjectionStage.log,
      () => log.record(transition, current),
    );
    await _retryableBool(
      current,
      TaskOccurrenceProjectionStage.neural,
      () => neural.record(transition, current),
    );
  }

  Future<TaskOccurrenceProjectionWork> _retryable(
    TaskOccurrenceProjectionWork work,
    TaskOccurrenceProjectionStage stage,
    Future<void> Function() action,
  ) async {
    if (!work.isPending(stage)) return work;
    try {
      await action();
      final TaskOccurrenceProjectionWork updated = work.withStage(
        stage,
        TaskOccurrenceProjectionStageState.done,
      );
      await workRepository.save(updated);
      return updated;
    } on Object {
      return work;
    }
  }

  Future<TaskOccurrenceProjectionWork> _retryableBool(
    TaskOccurrenceProjectionWork work,
    TaskOccurrenceProjectionStage stage,
    Future<bool> Function() action,
  ) async {
    if (!work.isPending(stage)) return work;
    try {
      final bool applied = await action();
      if (!applied) return work;
      final TaskOccurrenceProjectionWork updated = work.withStage(
        stage,
        TaskOccurrenceProjectionStageState.done,
      );
      await workRepository.save(updated);
      return updated;
    } on Object {
      return work;
    }
  }

  Future<TaskOccurrenceProjectionWork> _bestEffortTerminal(
    TaskOccurrenceProjectionWork work,
    TaskOccurrenceProjectionStage stage,
    Future<bool> Function() action,
  ) async {
    if (!work.isPending(stage)) return work;
    try {
      final bool applied = await action();
      final TaskOccurrenceProjectionWork updated = work.withStage(
        stage,
        applied
            ? TaskOccurrenceProjectionStageState.done
            : TaskOccurrenceProjectionStageState.terminal,
      );
      await workRepository.save(updated);
      return updated;
    } on Object {
      final TaskOccurrenceProjectionWork updated = work.withStage(
        stage,
        TaskOccurrenceProjectionStageState.terminal,
      );
      await workRepository.save(updated);
      return updated;
    }
  }

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _tail.catchError((Object _) {});
  }

  void dispose() => _cancelled = true;
}
