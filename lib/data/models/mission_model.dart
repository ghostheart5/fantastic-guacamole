import 'task_model.dart';

class MissionModel {
  final String id;
  final String name;
  final List<TaskModel> tasks;

  const MissionModel({
    required this.id,
    required this.name,
    required this.tasks,
  });

  MissionModel copyWith({String? id, String? name, List<TaskModel>? tasks}) {
    return MissionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tasks': tasks.map((e) => e.toJson()).toList(),
  };

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    final rawTasks = (json['tasks'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return MissionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      tasks: rawTasks.map(TaskModel.fromJson).toList(),
    );
  }
}
