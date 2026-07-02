import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';
import 'package:fantastic_guacamole/core/utils/json_utils.dart';

/// Converts raw JSON into TaskModel and back.
class TaskAdapter {
  static TaskModel fromJson(Map<String, dynamic> json) {
    final statusRaw = JsonUtils.getString(json, 'status', fallback: 'pending');
    final status = TaskStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => TaskStatus.pending,
    );
    final scheduledRaw = json['scheduledFor'] as String?;
    final createdRaw = JsonUtils.getString(json, 'createdAt');

    return TaskModel(
      id: JsonUtils.getString(json, 'id', fallback: ''),
      title: JsonUtils.getString(json, 'title', fallback: 'Untitled Task'),
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(createdRaw) ?? DateTime.now(),
      scheduledFor: scheduledRaw != null
          ? DateTime.tryParse(scheduledRaw)
          : null,
      status: status,
      completionCount: JsonUtils.getNum(
        json,
        'completionCount',
        fallback: 0,
      ).toInt(),
      skipCount: JsonUtils.getNum(json, 'skipCount', fallback: 0).toInt(),
      delayCount: JsonUtils.getNum(json, 'delayCount', fallback: 0).toInt(),
    );
  }

  static List<TaskModel> fromJsonList(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  static Map<String, dynamic> toJson(TaskModel model) {
    return {
      'id': model.id,
      'title': model.title,
      'description': model.description,
      'createdAt': model.createdAt.toIso8601String(),
      'scheduledFor': model.scheduledFor?.toIso8601String(),
      'status': model.status.name,
      'completionCount': model.completionCount,
      'skipCount': model.skipCount,
      'delayCount': model.delayCount,
    };
  }
}
