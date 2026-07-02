import 'package:flutter/foundation.dart';

enum TaskStatus { pending, inProgress, completed, skipped, delayed }

@immutable
class TaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final TaskStatus status;
  final int completionCount;
  final int skipCount;
  final int delayCount;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.scheduledFor,
    this.status = TaskStatus.pending,
    this.completionCount = 0,
    this.skipCount = 0,
    this.delayCount = 0,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? scheduledFor,
    TaskStatus? status,
    int? completionCount,
    int? skipCount,
    int? delayCount,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      completionCount: completionCount ?? this.completionCount,
      skipCount: skipCount ?? this.skipCount,
      delayCount: delayCount ?? this.delayCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'scheduledFor': scheduledFor?.toIso8601String(),
      'status': status.name,
      'completionCount': completionCount,
      'skipCount': skipCount,
      'delayCount': delayCount,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.parse(json['scheduledFor'] as String)
          : null,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      completionCount: json['completionCount'] as int? ?? 0,
      skipCount: json['skipCount'] as int? ?? 0,
      delayCount: json['delayCount'] as int? ?? 0,
    );
  }
}
