import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

enum TaskOccurrenceOutcome { completed, skipped, rescheduled }

class TaskOccurrenceTransition {
  const TaskOccurrenceTransition({
    required this.operationId,
    required this.outcome,
    required this.at,
    this.rescheduledFor,
  });

  final String operationId;
  final TaskOccurrenceOutcome outcome;
  final DateTime at;
  final DateTime? rescheduledFor;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'operationId': operationId,
    'outcome': outcome.name,
    'at': at.toUtc().toIso8601String(),
    'rescheduledFor': rescheduledFor?.toUtc().toIso8601String(),
  };

  factory TaskOccurrenceTransition.fromJson(Map<String, dynamic> json) {
    final String operationId = json['operationId']?.toString().trim() ?? '';
    final DateTime? at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (operationId.isEmpty || at == null) {
      throw const FormatException(
        'Task occurrence transition requires an operation ID and timestamp.',
      );
    }
    final TaskOccurrenceOutcome outcome = _outcomeFromJson(json['outcome']);
    final DateTime? rescheduledFor = DateTime.tryParse(
      json['rescheduledFor']?.toString() ?? '',
    );
    if (outcome == TaskOccurrenceOutcome.rescheduled &&
        rescheduledFor == null) {
      throw const FormatException(
        'A rescheduled occurrence transition requires a target timestamp.',
      );
    }
    return TaskOccurrenceTransition(
      operationId: operationId,
      outcome: outcome,
      at: at,
      rescheduledFor: rescheduledFor,
    );
  }
}

/// A persisted intent makes a multi-write task transition restart-safe.
class TaskOccurrencePendingOperation {
  const TaskOccurrencePendingOperation({
    required this.operationId,
    required this.outcome,
    required this.at,
    this.rescheduledFor,
  });

  final String operationId;
  final TaskOccurrenceOutcome outcome;
  final DateTime at;
  final DateTime? rescheduledFor;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'operationId': operationId,
    'outcome': outcome.name,
    'at': at.toUtc().toIso8601String(),
    'rescheduledFor': rescheduledFor?.toUtc().toIso8601String(),
  };

  factory TaskOccurrencePendingOperation.fromJson(Map<String, dynamic> json) {
    final String operationId = json['operationId']?.toString().trim() ?? '';
    final DateTime? at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (operationId.isEmpty || at == null) {
      throw const FormatException(
        'Pending task occurrence requires an operation ID and timestamp.',
      );
    }
    final TaskOccurrenceOutcome outcome = _outcomeFromJson(json['outcome']);
    final DateTime? rescheduledFor = DateTime.tryParse(
      json['rescheduledFor']?.toString() ?? '',
    );
    if (outcome == TaskOccurrenceOutcome.rescheduled &&
        rescheduledFor == null) {
      throw const FormatException(
        'A pending reschedule requires a target timestamp.',
      );
    }
    return TaskOccurrencePendingOperation(
      operationId: operationId,
      outcome: outcome,
      at: at,
      rescheduledFor: rescheduledFor,
    );
  }
}

/// Durable outcome authority for one actionable recurrence slot.
class TaskOccurrence {
  const TaskOccurrence({
    required this.taskId,
    required this.seriesId,
    required this.occurrenceKey,
    required this.initialScheduledFor,
    this.transitions = const <TaskOccurrenceTransition>[],
    this.pendingOperation,
    this.pendingCloudOperationIds = const <String>{},
  });

  final String taskId;
  final String seriesId;
  final String occurrenceKey;
  final DateTime? initialScheduledFor;
  final List<TaskOccurrenceTransition> transitions;
  final TaskOccurrencePendingOperation? pendingOperation;
  final Set<String> pendingCloudOperationIds;

  String get id => occurrenceId(taskId, occurrenceKey);

  static String occurrenceId(String taskId, String occurrenceKey) =>
      '$taskId::$occurrenceKey';

  static String seriesIdFor(TaskEntity task) {
    const String successorSeparator = '::next::';
    final int separator = task.id.indexOf(successorSeparator);
    return separator < 0 ? task.id : task.id.substring(0, separator);
  }

  static String occurrenceKeyFor(TaskEntity task) {
    final String? persisted = task.occurrenceKey;
    if (persisted != null && persisted.isNotEmpty) return persisted;
    return TaskEntity.deriveOccurrenceKey(
      taskId: task.id,
      createdAt: task.createdAt,
    );
  }

  TaskOccurrenceOutcome? get terminalOutcome {
    for (final TaskOccurrenceTransition transition in transitions.reversed) {
      if (transition.outcome == TaskOccurrenceOutcome.completed ||
          transition.outcome == TaskOccurrenceOutcome.skipped) {
        return transition.outcome;
      }
    }
    return null;
  }

  bool get isTerminal => terminalOutcome != null;

  bool hasCommittedOperation(String operationId) => transitions.any(
    (TaskOccurrenceTransition value) => value.operationId == operationId,
  );

  List<TaskOccurrenceTransition> get pendingCloudTransitions => transitions
      .where(
        (TaskOccurrenceTransition transition) =>
            pendingCloudOperationIds.contains(transition.operationId),
      )
      .toList(growable: false);

  TaskOccurrence copyWith({
    List<TaskOccurrenceTransition>? transitions,
    TaskOccurrencePendingOperation? pendingOperation,
    Set<String>? pendingCloudOperationIds,
    bool clearPendingOperation = false,
  }) => TaskOccurrence(
    taskId: taskId,
    seriesId: seriesId,
    occurrenceKey: occurrenceKey,
    initialScheduledFor: initialScheduledFor,
    transitions: transitions ?? this.transitions,
    pendingOperation: clearPendingOperation
        ? null
        : pendingOperation ?? this.pendingOperation,
    pendingCloudOperationIds:
        pendingCloudOperationIds ?? this.pendingCloudOperationIds,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'taskId': taskId,
    'seriesId': seriesId,
    'occurrenceKey': occurrenceKey,
    'initialScheduledFor': initialScheduledFor?.toUtc().toIso8601String(),
    'transitions': transitions
        .map((TaskOccurrenceTransition value) => value.toJson())
        .toList(growable: false),
    'pendingOperation': pendingOperation?.toJson(),
    'pendingCloudOperationIds': pendingCloudOperationIds.toList()..sort(),
  };

  factory TaskOccurrence.fromJson(Map<String, dynamic> json) {
    final String taskId = json['taskId']?.toString().trim() ?? '';
    final String occurrenceKey = json['occurrenceKey']?.toString().trim() ?? '';
    if (taskId.isEmpty || occurrenceKey.isEmpty) {
      throw const FormatException(
        'Task occurrence requires task and occurrence identities.',
      );
    }
    final String storedSeriesId = json['seriesId']?.toString().trim() ?? '';
    final Object? rawTransitions = json['transitions'];
    final Object? rawPending = json['pendingOperation'];
    if (rawTransitions != null && rawTransitions is! List<dynamic>) {
      throw const FormatException(
        'Task occurrence transitions must be a list.',
      );
    }
    final List<dynamic> transitionValues = rawTransitions == null
        ? const <dynamic>[]
        : rawTransitions as List<dynamic>;
    final List<TaskOccurrenceTransition> transitions = rawTransitions == null
        ? const <TaskOccurrenceTransition>[]
        : transitionValues
              .map((dynamic value) {
                if (value is! Map<dynamic, dynamic>) {
                  throw const FormatException(
                    'Task occurrence transition must be an object.',
                  );
                }
                return TaskOccurrenceTransition.fromJson(
                  value.map<String, dynamic>(
                    (dynamic key, dynamic item) =>
                        MapEntry(key.toString(), item),
                  ),
                );
              })
              .toList(growable: false);
    final Set<String> transitionIds = transitions
        .map((TaskOccurrenceTransition value) => value.operationId)
        .toSet();
    if (transitionIds.length != transitions.length) {
      throw const FormatException(
        'Task occurrence transition operation IDs must be unique.',
      );
    }
    final Object? rawPendingCloud = json['pendingCloudOperationIds'];
    if (rawPendingCloud != null && rawPendingCloud is! List<dynamic>) {
      throw const FormatException(
        'Task occurrence cloud outbox must be a list.',
      );
    }
    final List<dynamic> pendingCloudValues = rawPendingCloud == null
        ? const <dynamic>[]
        : rawPendingCloud as List<dynamic>;
    final Set<String> pendingCloudOperationIds = rawPendingCloud == null
        ? <String>{}
        : pendingCloudValues
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toSet();
    if (!transitionIds.containsAll(pendingCloudOperationIds)) {
      throw const FormatException(
        'Task occurrence cloud outbox references an unknown transition.',
      );
    }
    return TaskOccurrence(
      taskId: taskId,
      seriesId: storedSeriesId.isEmpty
          ? taskId.split('::next::').first
          : storedSeriesId,
      occurrenceKey: occurrenceKey,
      initialScheduledFor: DateTime.tryParse(
        json['initialScheduledFor']?.toString() ?? '',
      ),
      transitions: transitions,
      pendingOperation: rawPending is Map<dynamic, dynamic>
          ? TaskOccurrencePendingOperation.fromJson(
              rawPending.map<String, dynamic>(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      pendingCloudOperationIds: pendingCloudOperationIds,
    );
  }
}

TaskOccurrenceOutcome _outcomeFromJson(Object? raw) {
  final String name = raw?.toString() ?? '';
  for (final TaskOccurrenceOutcome outcome in TaskOccurrenceOutcome.values) {
    if (outcome.name == name) return outcome;
  }
  throw FormatException('Unknown task occurrence outcome: $name');
}
