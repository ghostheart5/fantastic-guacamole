/// CHRONOSPARK-CLASS: SHIPPING | Feature: Notes
class NoteEntity {
  const NoteEntity({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.isArchived = false,
    this.goalId,
    this.taskId,
    this.habitId,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final bool isArchived;
  final String? goalId;
  final String? taskId;
  final String? habitId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      if (body != null) 'body': body,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (userId != null) 'userId': userId,
      'isArchived': isArchived,
      if (goalId != null) 'goalId': goalId,
      if (taskId != null) 'taskId': taskId,
      if (habitId != null) 'habitId': habitId,
    };
  }

  factory NoteEntity.fromJson(Map<String, dynamic> json) {
    return NoteEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Note',
      body: json['body']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      userId: json['userId']?.toString(),
      isArchived: json['isArchived'] == true,
      goalId: json['goalId']?.toString(),
      taskId: json['taskId']?.toString(),
      habitId: json['habitId']?.toString(),
    );
  }

  NoteEntity copyWith({
    String? title,
    String? body,
    bool? isArchived,
    DateTime? updatedAt,
  }) => NoteEntity(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    userId: userId,
    isArchived: isArchived ?? this.isArchived,
    goalId: goalId,
    taskId: taskId,
    habitId: habitId,
  );
}
