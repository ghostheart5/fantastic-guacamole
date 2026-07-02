import 'package:fantastic_guacamole/data/models/task.dart';

class DataMigration {
  static List<Task> migrateTasks(List<dynamic> raw) {
    final List<Task> tasks = [];
    for (final item in raw) {
      try {
        if (item is Map<String, dynamic>) tasks.add(_migrateTask(item));
      } catch (_) {}
    }
    return tasks;
  }

  static Task _migrateTask(Map<String, dynamic> json) {
    final version = json["version"] ?? 1;
    switch (version) {
      case 1:
        return _fromV1(json);
      case 2:
      default:
        return _fromV2(json);
    }
  }

  static Task _fromV1(Map<String, dynamic> json) {
    final Object? difficultyOrEffort = json['effort'] ?? json['difficulty'];
    return Task(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      difficulty: (difficultyOrEffort as num?)?.toInt() ?? 3,
      energyRequired: (json['energyRequired'] as num?)?.toInt() ?? 3,
    );
  }

  static Task _fromV2(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      energyRequired: (json['energyRequired'] as num?)?.toInt() ?? 3,
    );
  }
}
