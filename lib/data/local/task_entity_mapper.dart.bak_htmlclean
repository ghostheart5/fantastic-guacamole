import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class TaskEntityMapper {
  const TaskEntityMapper._();

  static TaskEntity fromJson(Map<String, dynamic> json) {
    final int? durationMs = (json['estimatedDurationMs'] as num?)?.toInt();
    final String? recurrenceName = json['recurrenceRule']?.toString();
    final String legacyStatus = json['status']?.toString() ?? '';
    final bool legacyCompleted =
        legacyStatus == 'completed' ||
        ((json['completionCount'] as num?)?.toInt() ?? 0) > 0;

    return TaskEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Task',
      kind: json['kind']?.toString(),
      description: json['description']?.toString(),
      createdAt:
          _dateTimeFromJson(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isCompleted: json['isCompleted'] as bool? ?? legacyCompleted,
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      energyRequired: (json['energyRequired'] as num?)?.toInt() ?? 3,
      estimatedDuration: durationMs == null
          ? null
          : Duration(milliseconds: durationMs),
      completedAt: _dateTimeFromJson(json['completedAt']),
      scheduledFor: _dateTimeFromJson(json['scheduledFor']),
      dueDate: _dateTimeFromJson(json['dueDate']),
      goalId: json['goalId']?.toString(),
      isCanceled: json['isCanceled'] as bool? ?? false,
      subtasks:
          (json['subtasks'] as List<dynamic>?)
              ?.map((dynamic value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
      recurrenceRule: RecurrenceRule.values.firstWhere(
        (RecurrenceRule value) => value.name == recurrenceName,
        orElse: () => RecurrenceRule.none,
      ),
    );
  }

  static Map<String, dynamic> toJson(TaskEntity task) => <String, dynamic>{
    'id': task.id,
    'title': task.title,
    'kind': task.kind,
    'description': task.description,
    'createdAt': task.createdAt.toIso8601String(),
    'isCompleted': task.isCompleted,
    'priority': task.priority,
    'difficulty': task.difficulty,
    'energyRequired': task.energyRequired,
    'estimatedDurationMs': task.estimatedDuration?.inMilliseconds,
    'completedAt': task.completedAt?.toIso8601String(),
    'scheduledFor': task.scheduledFor?.toIso8601String(),
    'dueDate': task.dueDate?.toIso8601String(),
    'goalId': task.goalId,
    'isCanceled': task.isCanceled,
    'subtasks': task.subtasks,
    'recurrenceRule': task.recurrenceRule.name,
  };

  static DateTime? _dateTimeFromJson(dynamic value) {
    return value is String ? DateTime.tryParse(value) : null;
  }
}
