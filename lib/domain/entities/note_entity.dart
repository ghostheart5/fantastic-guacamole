import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class NoteEntity {
  const NoteEntity({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    this.userId,
  });

  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final String? userId;

  TaskEntity toTaskEntity({
    DateTime? scheduledFor,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
  }) {
    return TaskEntity(
      id: id,
      title: title,
      kind: 'note',
      description: body,
      createdAt: createdAt,
      priority: 1,
      difficulty: 2,
      energyRequired: 1,
      scheduledFor: scheduledFor,
      recurrenceRule: recurrenceRule,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      if (body != null) 'body': body,
      'createdAt': createdAt.toIso8601String(),
      if (userId != null) 'userId': userId,
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
      userId: json['userId']?.toString(),
    );
  }
}
