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
    return TaskOccurrenceTransition(
      operationId: json['operationId']?.toString() ?? '',
      outcome: _outcomeFromJson(json['outcome']),
      at:
          DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rescheduledFor: DateTime.tryParse(
        json['rescheduledFor']?.toString() ?? '',
      )?.toLocal(),
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
    return TaskOccurrencePendingOperation(
      operationId: json['operationId']?.toString() ?? '',
      outcome: _outcomeFromJson(json['outcome']),
      at:
          DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rescheduledFor: DateTime.tryParse(
        json['rescheduledFor']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// Durable outcome authority for one actionable recurrence slot.
class TaskOccurrence {
  const TaskOccurrence({
    required this.taskId,
    required this.occurrenceKey,
    required this.initialScheduledFor,
    this.transitions = const <TaskOccurrenceTransition>[],
    this.pendingOperation,
  });

  final String taskId;
  final String occurrenceKey;
  final DateTime? initialScheduledFor;
  final List<TaskOccurrenceTransition> transitions;
  final TaskOccurrencePendingOperation? pendingOperation;

  String get id => occurrenceId(taskId, occurrenceKey);

  static String occurrenceId(String taskId, String occurrenceKey) =>
      '$taskId::$occurrenceKey';

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

  TaskOccurrence copyWith({
    List<TaskOccurrenceTransition>? transitions,
    TaskOccurrencePendingOperation? pendingOperation,
    bool clearPendingOperation = false,
  }) => TaskOccurrence(
    taskId: taskId,
    occurrenceKey: occurrenceKey,
    initialScheduledFor: initialScheduledFor,
    transitions: transitions ?? this.transitions,
    pendingOperation: clearPendingOperation
        ? null
        : pendingOperation ?? this.pendingOperation,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'taskId': taskId,
    'occurrenceKey': occurrenceKey,
    'initialScheduledFor': initialScheduledFor?.toUtc().toIso8601String(),
    'transitions': transitions
        .map((TaskOccurrenceTransition value) => value.toJson())
        .toList(growable: false),
    'pendingOperation': pendingOperation?.toJson(),
  };

  factory TaskOccurrence.fromJson(Map<String, dynamic> json) {
    final Object? rawTransitions = json['transitions'];
    final Object? rawPending = json['pendingOperation'];
    return TaskOccurrence(
      taskId: json['taskId']?.toString() ?? '',
      occurrenceKey: json['occurrenceKey']?.toString() ?? '',
      initialScheduledFor: DateTime.tryParse(
        json['initialScheduledFor']?.toString() ?? '',
      )?.toLocal(),
      transitions: rawTransitions is List<dynamic>
          ? rawTransitions
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (Map<dynamic, dynamic> value) =>
                      TaskOccurrenceTransition.fromJson(
                        value.map<String, dynamic>(
                          (dynamic key, dynamic item) =>
                              MapEntry(key.toString(), item),
                        ),
                      ),
                )
                .toList(growable: false)
          : const <TaskOccurrenceTransition>[],
      pendingOperation: rawPending is Map<dynamic, dynamic>
          ? TaskOccurrencePendingOperation.fromJson(
              rawPending.map<String, dynamic>(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
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
