import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/scoring/session_scoring_engine.dart';
import 'package:fantastic_guacamole/engine/tasks/task_filter.dart';
import 'package:fantastic_guacamole/engine/tasks/task_ranker.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
  show
    advancedAudioProfileEnabledProvider,
    soundEnabledProvider,
    timelineFirstActionCompletedProvider,
    timelineFirstActionCompletedStorageKey,
    timelineFirstActionCompletedStorageKeyForUser;
import 'package:fantastic_guacamole/state/models/session_score_view.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/session_score_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final tasksProvider = FutureProvider<List<Task>>((Ref ref) async {
  final List<TaskEntity> tasks = await ref.read(getTasksUseCaseProvider).call();
  final OptimizationConfig optimization = await ref.watch(
    optimizationConfigProvider.future,
  );
  final si = ref.watch(siStateProvider);
  final learning = ref.watch(learningProvider);
  final SiStateEntity siState = SiStateEntity(
    energy: si.energy,
    focus: (si.energy * (1 - si.fatigue)).clamp(0.0, 1.0),
    fatigue: si.fatigue,
    avoidOverwhelm: si.fatigue >= 0.75,
    primaryInstinct: si.fatigue >= 0.75 ? 'safety_first' : 'progress_first',
  );
  final List<TaskEntity> candidates = TaskFilter.bySiState(tasks, siState);
  final List<RankedTask> ranked = const TaskRanker().rank(
    candidates,
    learning: learning,
    energy: si.energy,
    fatigue: si.fatigue,
    priorityScale: optimization.nextActionAggressiveness,
    difficultyScale: optimization.taskDifficultyScale,
    siState: siState,
  );
  return ranked.map((RankedTask item) => _taskFromEntity(item.task)).toList();
});

final taskActionsProvider = Provider<TaskActions>((Ref ref) {
  return TaskActions(ref);
});

class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;
  static final SessionScoringEngine _scoringEngine = SessionScoringEngine();
  static const Duration _timelineActionDedupWindow = Duration(
    milliseconds: 900,
  );
  final Map<String, DateTime> _recentTimelineActions = <String, DateTime>{};

  Future<void> createTask(
    TaskEntity entity, {
    bool notify = false,
    String actionSource = 'unknown',
  }) async {
    final String trimmed = entity.title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    final TaskEntity normalized = entity.copyWith(
      title: trimmed,
      createdAt: entity.createdAt,
    );

    await _ref.read(createTaskUseCaseProvider).call(normalized);
    await _ref.read(timelineActionsProvider).connectTask(normalized);
    AppAnalytics.track(
      'task_created',
      params: <String, Object?>{
        'task_id': normalized.id,
        'action_source': actionSource,
      },
    );
    unawaited(
      _recordCreationSideEffects(
        task: normalized,
        timestamp: now,
        notify: notify,
      ),
    );

    _emitTaskLifecycle(
      taskId: normalized.id,
      title: trimmed,
      action: 'created',
      actionSource: actionSource,
    );
    await _bestEffort(
      () => _ref
          .read(localMetricsAccumulatorProvider)
          .recordAutomationCheckpoint('task_created_event_emitted'),
    );
    _invalidateTaskGraph();
  }

  Future<void> createQuickTask(String title, {bool notify = false}) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    final TaskEntity entity = TaskEntity(
      id: now.microsecondsSinceEpoch.toString(),
      title: trimmed,
      createdAt: now,
      priority: 3,
      difficulty: 3,
      energyRequired: 3,
    );
    await createTask(entity, notify: notify, actionSource: 'quick_create');
  }

  Future<void> completeTask(
    String id, {
    bool notify = true,
    String actionSource = 'unknown',
  }) async {
    if (_shouldSuppressTimelineDuplicate(
      taskId: id,
      action: 'completed',
      actionSource: actionSource,
    )) {
      return;
    }

    Task? selectedTask = _taskFromCachedTasks(id);
    final Future<Task?> selectedTaskFuture = selectedTask != null
        ? Future<Task?>.value(selectedTask)
        : _taskFromRepository(id);

    await _ref.read(completeTaskUseCaseProvider).call(id);
    selectedTask ??= await selectedTaskFuture;

    if (selectedTask != null) {
      final DateTime now = DateTime.now();
      final int estimatedSeconds = (selectedTask.difficulty * 300).clamp(
        60,
        1800,
      );
      final double energy = _ref.read(siStateProvider).energy;
      final score = _scoringEngine.calculate(
        seconds: estimatedSeconds,
        energy: energy,
        taskPriority: selectedTask.priority,
      );
      _ref
          .read(sessionScoreProvider.notifier)
          .set(
            SessionScoreView.fromScore(
              score,
              durationSeconds: estimatedSeconds,
              taskTitle: selectedTask.title,
            ),
          );
      _ref.read(profileProvider.notifier).addXP(score.xp);
      _ref.read(siStateProvider.notifier).sessionComplete();
      unawaited(
        _recordCompletionSideEffects(
          task: selectedTask,
          durationSeconds: estimatedSeconds,
          quality: score.quality,
          timestamp: now,
          notify: notify,
        ),
      );
    }

    if (selectedTask == null) {
      unawaited(_refreshCoachDecision(notify: notify));
    }

    if (actionSource == 'timeline') {
      unawaited(_markTimelineFirstActionCompleted());
    }

    if (selectedTask != null) {
      AppAnalytics.track(
        'task_completed',
        params: <String, Object?>{
          'task_id': selectedTask.id,
          'action_source': actionSource,
        },
      );
      unawaited(
        _bestEffort(
          () => _recordCompletionEvent(
            task: selectedTask!,
            eventType: CompletionEventType.completed,
            actionSource: actionSource,
          ),
        ),
      );
      _emitTaskLifecycle(
        taskId: selectedTask.id,
        title: selectedTask.title,
        action: 'completed',
        actionSource: actionSource,
      );
      await _bestEffort(
        () => _ref
            .read(localMetricsAccumulatorProvider)
            .recordAutomationCheckpoint('task_completed_event_emitted'),
      );
    }

    _invalidateTaskGraph();
  }

  Future<Task?> _taskFromRepository(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }
    final TaskEntity? entity = await _ref
        .read(domainTaskRepositoryProvider)
        .getTaskById(id);
    if (entity == null || entity.isCompleted || entity.isCanceled) {
      return null;
    }
    return _taskFromEntity(entity);
  }

  Task? _taskFromCachedTasks(String id) {
    final AsyncValue<List<Task>> asyncTasks = _ref.read(tasksProvider);
    final List<Task>? tasks = asyncTasks.maybeWhen(
      data: (List<Task> value) => value,
      orElse: () => null,
    );
    if (tasks == null) {
      return null;
    }
    for (final Task task in tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Future<void> skipTask(
    String id, {
    bool notify = true,
    String actionSource = 'unknown',
  }) async {
    final List<Task> tasks = await _ref.read(tasksProvider.future);
    Task? selectedTask;
    for (final Task task in tasks) {
      if (task.id == id) {
        selectedTask = task;
        break;
      }
    }
    if (selectedTask == null) {
      throw StateError('Task not found');
    }

    if (_shouldSuppressTimelineDuplicate(
      taskId: selectedTask.id,
      action: 'skipped',
      actionSource: actionSource,
    )) {
      return;
    }

    final DateTime now = DateTime.now();
    await _ref
        .read(learningProvider.notifier)
        .update(success: false, difficulty: selectedTask.difficulty);
    _ref.read(siStateProvider.notifier).taskSkipped();
    await _ref
        .read(logsActionsProvider)
        .addMirroredEntry(source: 'task_skipped', message: selectedTask.title);
    await _ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'timeline-task-skipped-${now.microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Task Skipped',
            detail: '${selectedTask.title} skipped and adaptation triggered.',
            timestamp: now,
          ),
        );
    if (notify) {
      await _ref
          .read(notificationActionsProvider)
          .pushMirroredTaskSkipped(selectedTask.title);
    }
    await _refreshCoachDecision(notify: notify);

    if (actionSource == 'timeline') {
      unawaited(_markTimelineFirstActionCompleted());
    }

    unawaited(
      _bestEffort(
        () => _recordCompletionEvent(
          task: selectedTask!,
          eventType: CompletionEventType.skipped,
          actionSource: actionSource,
        ),
      ),
    );

    _emitTaskLifecycle(
      taskId: selectedTask.id,
      title: selectedTask.title,
      action: 'skipped',
      actionSource: actionSource,
    );
    await _bestEffort(
      () => _ref
          .read(localMetricsAccumulatorProvider)
          .recordAutomationCheckpoint('task_skipped_event_emitted'),
    );
    _invalidateTaskGraph();
  }

  Future<void> delayTask(
    String id, {
    Duration by = const Duration(hours: 2),
    bool notify = true,
    String actionSource = 'unknown',
    String delayReason = 'reschedule',
  }) async {
    if (id.trim().isEmpty) {
      throw StateError('Task not found');
    }
    final TaskEntity? entity = await _ref
        .read(domainTaskRepositoryProvider)
        .getTaskById(id);
    if (entity == null || entity.isCompleted || entity.isCanceled) {
      throw StateError('Task not found');
    }
    final DateTime now = DateTime.now();
    final DateTime nextSchedule =
        (entity.scheduledFor ?? now).add(by).isBefore(now)
        ? now.add(by)
        : (entity.scheduledFor ?? now).add(by);
    final TaskEntity delayed = entity.copyWith(scheduledFor: nextSchedule);
    final String normalizedDelayReason = delayReason.trim().toLowerCase();
    final bool isNotCompleted = normalizedDelayReason == 'not_completed';
    final bool isOverdue = normalizedDelayReason == 'overdue';
    final String logSource = isNotCompleted
      ? 'task_not_completed'
      : 'task_delayed';
    final String eventTitle = isNotCompleted ? 'Task Not Completed' : 'Task Delayed';
    final String eventDetail = isNotCompleted
      ? '${delayed.title} marked not completed and moved to ${nextSchedule.toLocal().toIso8601String()}.'
      : '${delayed.title} delayed until ${nextSchedule.toLocal().toIso8601String()}.';
    final String lifecycleAction = isNotCompleted ? 'not_completed' : 'delayed';

    if (_shouldSuppressTimelineDuplicate(
      taskId: delayed.id,
      action: lifecycleAction,
      actionSource: actionSource,
    )) {
      return;
    }

    await _ref.read(updateTaskUseCaseProvider).call(delayed);
    await _ref
        .read(logsActionsProvider)
      .addMirroredEntry(source: logSource, message: delayed.title);
    await _ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'timeline-task-delayed-${now.microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
        title: eventTitle,
        detail: eventDetail,
            timestamp: now,
          ),
        );
    if (notify) {
      await _refreshCoachDecision(notify: true);
    }

    if (actionSource == 'timeline') {
      unawaited(_markTimelineFirstActionCompleted());
    }
    final CompletionEventType eventType = isNotCompleted
        ? CompletionEventType.notCompleted
        : isOverdue
        ? CompletionEventType.overdue
        : CompletionEventType.rescheduled;
    unawaited(
      _bestEffort(
        () => _recordCompletionEvent(
          task: _taskFromEntity(delayed),
          eventType: eventType,
          actionSource: actionSource,
        ),
      ),
    );
    _emitTaskLifecycle(
      taskId: delayed.id,
      title: delayed.title,
      action: lifecycleAction,
      actionSource: actionSource,
    );
    await _bestEffort(
      () => _ref
          .read(localMetricsAccumulatorProvider)
          .recordAutomationCheckpoint(
            'task_${lifecycleAction}_event_emitted',
          ),
    );
    _invalidateTaskGraph(includeDecision: true);
  }

  Future<void> updateCreatorEntry({
    required String id,
    required String title,
    String? description,
    required int priority,
  }) async {
    final String trimmedTitle = title.trim();
    if (id.trim().isEmpty || trimmedTitle.isEmpty) {
      throw StateError('Creator entry is missing required fields.');
    }

    final TaskEntity? existing = await _ref
        .read(domainTaskRepositoryProvider)
        .getTaskById(id);

    if (existing == null || existing.isCompleted || existing.isCanceled) {
      throw StateError('Creator entry not found.');
    }

    final String? normalizedDescription =
        description == null || description.trim().isEmpty
        ? null
        : description.trim();

    final TaskEntity updated = existing.copyWith(
      title: trimmedTitle,
      description: normalizedDescription,
      priority: priority.clamp(1, 5),
    );

    await _ref.read(updateTaskUseCaseProvider).call(updated);

    await _bestEffort(
      () => _ref
          .read(logsActionsProvider)
          .addMirroredEntry(
            source: 'creator_entry_updated',
            message: updated.title,
          ),
    );

    _emitTaskLifecycle(taskId: updated.id, title: updated.title, action: 'updated');
    await _bestEffort(
      () => _ref
          .read(localMetricsAccumulatorProvider)
          .recordAutomationCheckpoint('task_updated_event_emitted'),
    );
    _invalidateTaskGraph(includeDecision: true);
  }

  void _emitTaskLifecycle({
    required String taskId,
    required String title,
    required String action,
    String actionSource = 'unknown',
  }) {
    _ref
        .read(eventBusProvider)
        .emit(
          TaskLifecycleEvent(
            taskId: taskId,
            title: title,
            action: action,
            actionSource: actionSource,
          ),
        );
  }

  bool _shouldSuppressTimelineDuplicate({
    required String taskId,
    required String action,
    required String actionSource,
  }) {
    if (actionSource != 'timeline') {
      return false;
    }

    final String normalizedTaskId = taskId.trim();
    if (normalizedTaskId.isEmpty) {
      return false;
    }

    final DateTime now = DateTime.now();
    _recentTimelineActions.removeWhere(
      (_, DateTime timestamp) => now.difference(timestamp).inSeconds > 8,
    );

    final String key = '$normalizedTaskId::$action';
    final DateTime? previous = _recentTimelineActions[key];
    if (previous != null &&
        now.difference(previous) < _timelineActionDedupWindow) {
      AppAnalytics.track(
        'task_action_dedup_suppressed',
        params: <String, Object?>{
          'task_id': normalizedTaskId,
          'action': action,
          'action_source': actionSource,
        },
      );
      return true;
    }

    _recentTimelineActions[key] = now;
    return false;
  }

  void _invalidateTaskGraph({bool includeDecision = false}) {
    _ref.invalidate(tasksProvider);
    _ref.invalidate(goalProgressProvider);
    unawaited(
      _bestEffort(
        () => _ref
            .read(localMetricsAccumulatorProvider)
            .recordAutomationCheckpoint('task_graph_invalidated'),
      ),
    );
    if (includeDecision) {
      _ref.invalidate(domainSiDecisionProvider);
      unawaited(
        _bestEffort(
          () => _ref
              .read(localMetricsAccumulatorProvider)
              .recordAutomationCheckpoint('task_decision_invalidated'),
        ),
      );
    }
  }

  Future<void> _refreshCoachDecision({required bool notify}) async {
    try {
      final decision = await _ref
          .read(generateSiDecisionUseCaseProvider)
          .call();
      _ref.invalidate(domainSiDecisionProvider);
      if (!notify) {
        return;
      }

      final String? selectedTaskId = decision.selectedTaskId;
      if (selectedTaskId == null || selectedTaskId.isEmpty) {
        return;
      }

      final TaskEntity? selected = await _ref
          .read(domainTaskRepositoryProvider)
          .getTaskById(selectedTaskId);
      final String selectedTitle = selected?.title.trim() ?? '';
      if (selectedTitle.isEmpty) {
        return;
      }
      await _ref
          .read(notificationActionsProvider)
          .pushMirroredDecision(selectedTitle);
    } catch (_) {
      // Skip coach refresh errors to avoid blocking task mutations.
    }
  }

  Future<void> _recordCompletionLearning({
    required Task task,
    required int durationSeconds,
    required double quality,
    required DateTime timestamp,
  }) async {
    const String storageKey = 'neural_dump';
    final store = _ref.read(secureStoreProvider);
    final String? raw = await store.readString(storageKey);
    final Map<String, dynamic> entry = NeuralEntry(
      task: task.title,
      reasoning: 'Recorded from a completed task.',
      confidence: quality,
      duration: durationSeconds,
      quality: quality,
      timestamp: timestamp,
    ).toJson();

    final String encoded = await compute<Map<String, dynamic>, String>(
      _appendNeuralDumpEntry,
      <String, dynamic>{'raw': raw, 'entry': entry},
    );
    await store.writeString(storageKey, encoded);
  }

  Future<void> _recordCreationSideEffects({
    required TaskEntity task,
    required DateTime timestamp,
    required bool notify,
  }) async {
    final bool soundEnabled = _ref.read(soundEnabledProvider);
    final bool advancedAudioEnabled = _ref.read(
      advancedAudioProfileEnabledProvider,
    );
    await _bestEffort(
      () => AudioService.playCreate(
        soundEnabled,
        advancedProfileEnabled: advancedAudioEnabled,
      ),
    );
    await _bestEffort(
      () => _ref.read(localMetricsAccumulatorProvider).recordTaskCreated(),
    );
    await _bestEffort(
      () => _ref
          .read(logsActionsProvider)
          .addMirroredEntry(source: 'task_created', message: task.title),
    );
    await _bestEffort(
      () => _ref
          .read(timelineActionsProvider)
          .addMirroredEvent(
            TimelineEventEntity(
              id: 'timeline-task-created-${timestamp.microsecondsSinceEpoch}',
              type: TimelineEventType.reflection,
              title: 'Task Added',
              detail: '${task.title} added to trajectory.',
              timestamp: timestamp,
            ),
          ),
    );
    await _refreshCoachDecision(notify: notify);
  }

  Future<void> _recordCompletionSideEffects({
    required Task task,
    required int durationSeconds,
    required double quality,
    required DateTime timestamp,
    required bool notify,
  }) async {
    await _bestEffort(
      () => _ref
          .read(learningProvider.notifier)
          .update(success: true, difficulty: task.difficulty),
    );
    await _bestEffort(
      () => _ref.read(localMetricsAccumulatorProvider).recordTaskCompleted(),
    );
    await _bestEffort(
      () => _recordCompletionLearning(
        task: task,
        durationSeconds: durationSeconds,
        quality: quality,
        timestamp: timestamp,
      ),
    );
    await _bestEffort(
      () => _ref
          .read(logsActionsProvider)
          .addCompletedTask(task: task.title, mirrored: true),
    );
    await _bestEffort(
      () => _ref
          .read(timelineActionsProvider)
          .addMirroredEvent(
            TimelineEventEntity(
              id: 'timeline-task-complete-${timestamp.microsecondsSinceEpoch}',
              type: TimelineEventType.reflection,
              title: 'Task Completed',
              detail: '${task.title} marked complete.',
              timestamp: timestamp,
            ),
          ),
    );
    if (notify) {
      await _bestEffort(
        () => _ref
            .read(notificationActionsProvider)
            .pushMirroredCompletionFeedback(task.title),
      );
    }
    await _refreshCoachDecision(notify: notify);
  }

  Future<void> _recordCompletionEvent({
    required Task task,
    required CompletionEventType eventType,
    required String actionSource,
  }) async {
    if (!Env.enableCompletionEventTracking) {
      return;
    }
    final CompletionEventEntity event = CompletionEventEntity(
      id:
          'completion-${DateTime.now().microsecondsSinceEpoch}-${task.id}-${eventType.name}',
      eventType: eventType,
      eventAt: DateTime.now().toUtc(),
      taskId: task.id,
      userId: sb.Supabase.instance.client.auth.currentUser?.id,
      source: actionSource,
      metadata: <String, dynamic>{
        'title': task.title,
        'priority': task.priority,
        'difficulty': task.difficulty,
      },
    );
    await _ref.read(completionEventRepositoryProvider).addEvent(event);
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // The task mutation already succeeded. Supporting telemetry and learning
      // must not turn a successful completion into a false failure for users.
    }
  }

  Future<void> _markTimelineFirstActionCompleted() async {
    _ref.read(timelineFirstActionCompletedProvider.notifier).set(true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? userId = sb.Supabase.instance.client.auth.currentUser?.id;
      final String key =
          (userId == null || userId.trim().isEmpty)
          ? timelineFirstActionCompletedStorageKey
          : timelineFirstActionCompletedStorageKeyForUser(userId.trim());
      await prefs.setBool(key, true);
    } on Object {
      // Do not block task actions if this local onboarding flag fails to write.
    }
  }
}

Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    description: task.description,
    kind: task.kind,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
    scheduledFor: task.scheduledFor,
    goalId: task.goalId,
    subtasks: task.subtasks,
    recurrenceRule: task.recurrenceRule,
  );
}

String _appendNeuralDumpEntry(Map<String, dynamic> payload) {
  final Object? raw = payload['raw'];
  final Object? entry = payload['entry'];
  final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];

  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        entries.addAll(decoded.whereType<Map<String, dynamic>>());
      }
    } catch (_) {
      // If historical neural dump data is malformed, recover by replacing it.
    }
  }

  if (entry is Map<String, dynamic>) {
    entries.add(entry);
  }

  final List<Map<String, dynamic>> bounded = entries.length > 200
      ? entries.sublist(entries.length - 200)
      : entries;
  return jsonEncode(bounded);
}
