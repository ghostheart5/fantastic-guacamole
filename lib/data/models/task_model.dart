class TaskModel {
  final String id;
  final String title;
  final bool done;

  const TaskModel({required this.id, required this.title, this.done = false});

  TaskModel copyWith({String? id, String? title, bool? done}) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      done: (json['done'] as bool?) ?? false,
    );
  }
}
