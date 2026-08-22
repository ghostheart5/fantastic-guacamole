enum TaskOccurrenceProjectionStage {
  timeline,
  completionLedger,
  sync,
  learning,
  log,
  neural,
}

enum TaskOccurrenceProjectionStageState { pending, done, terminal }

/// Durable reconciliation state for an already-committed occurrence transition.
/// It never determines or changes canonical TaskOccurrence truth.
class TaskOccurrenceProjectionWork {
  const TaskOccurrenceProjectionWork({
    required this.occurrenceId,
    required this.operationId,
    required this.taskTitle,
    required this.taskDifficulty,
    this.taskKind,
    required this.transitionAt,
    this.durationSeconds,
    this.quality,
    required this.stages,
  });

  final String occurrenceId;
  final String operationId;
  final String taskTitle;
  final int taskDifficulty;
  final String? taskKind;
  final DateTime transitionAt;
  final int? durationSeconds;
  final double? quality;
  final Map<TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>
  stages;

  String get id => '$occurrenceId::$operationId';

  bool isPending(TaskOccurrenceProjectionStage stage) =>
      (stages[stage] ?? TaskOccurrenceProjectionStageState.pending) ==
      TaskOccurrenceProjectionStageState.pending;

  TaskOccurrenceProjectionWork withStage(
    TaskOccurrenceProjectionStage stage,
    TaskOccurrenceProjectionStageState state,
  ) => TaskOccurrenceProjectionWork(
    occurrenceId: occurrenceId,
    operationId: operationId,
    taskTitle: taskTitle,
    taskDifficulty: taskDifficulty,
    taskKind: taskKind,
    transitionAt: transitionAt,
    durationSeconds: durationSeconds,
    quality: quality,
    stages: <TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>{
      ...stages,
      stage: state,
    },
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'occurrenceId': occurrenceId,
    'operationId': operationId,
    'taskTitle': taskTitle,
    'taskDifficulty': taskDifficulty,
    'taskKind': taskKind,
    'transitionAt': transitionAt.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'quality': quality,
    'stages': stages.map(
      (
        TaskOccurrenceProjectionStage key,
        TaskOccurrenceProjectionStageState value,
      ) => MapEntry(key.name, value.name),
    ),
  };

  factory TaskOccurrenceProjectionWork.fromJson(Map<String, dynamic> json) {
    final Map<TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>
    stages =
        <TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>{};
    final Object? rawStages = json['stages'];
    if (rawStages is Map<dynamic, dynamic>) {
      for (final MapEntry<dynamic, dynamic> entry in rawStages.entries) {
        final TaskOccurrenceProjectionStage? stage = _stageFromName(
          entry.key?.toString(),
        );
        final TaskOccurrenceProjectionStageState? state = _stateFromName(
          entry.value?.toString(),
        );
        if (stage != null && state != null) stages[stage] = state;
      }
    }
    return TaskOccurrenceProjectionWork(
      occurrenceId: json['occurrenceId']?.toString() ?? '',
      operationId: json['operationId']?.toString() ?? '',
      taskTitle: json['taskTitle']?.toString() ?? '',
      taskDifficulty: (json['taskDifficulty'] as num?)?.toInt() ?? 3,
      taskKind: json['taskKind']?.toString(),
      transitionAt:
          DateTime.tryParse(
            json['transitionAt']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      quality: (json['quality'] as num?)?.toDouble(),
      stages: stages,
    );
  }
}

TaskOccurrenceProjectionStage? _stageFromName(String? name) {
  for (final TaskOccurrenceProjectionStage stage
      in TaskOccurrenceProjectionStage.values) {
    if (stage.name == name) return stage;
  }
  return null;
}

TaskOccurrenceProjectionStageState? _stateFromName(String? name) {
  for (final TaskOccurrenceProjectionStageState state
      in TaskOccurrenceProjectionStageState.values) {
    if (state.name == name) return state;
  }
  return null;
}
