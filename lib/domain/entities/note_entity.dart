/// CHRONOSPARK-CLASS: SHIPPING | Feature: Notes
enum NoteKind { note, reflection }

class NoteEntity {
  const NoteEntity({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.isArchived = false,
    this.kind = NoteKind.note,
    this.goalId,
    this.taskId,
    this.habitId,
    this.occurrenceId,
    this.outcomeId,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final bool isArchived;
  final NoteKind kind;
  final String? goalId;
  final String? taskId;
  final String? habitId;
  final String? occurrenceId;
  final String? outcomeId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      if (body != null) 'body': body,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (userId != null) 'userId': userId,
      'isArchived': isArchived,
      'kind': kind.name,
      if (goalId != null) 'goalId': goalId,
      if (taskId != null) 'taskId': taskId,
      if (habitId != null) 'habitId': habitId,
      if (occurrenceId != null) 'occurrenceId': occurrenceId,
      if (outcomeId != null) 'outcomeId': outcomeId,
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
      kind: NoteKind.values.firstWhere(
        (NoteKind value) => value.name == json['kind']?.toString(),
        orElse: () => NoteKind.note,
      ),
      goalId: json['goalId']?.toString(),
      taskId: json['taskId']?.toString(),
      habitId: json['habitId']?.toString(),
      occurrenceId: json['occurrenceId']?.toString(),
      outcomeId: json['outcomeId']?.toString(),
    );
  }

  NoteEntity copyWith({
    String? title,
    String? body,
    bool? isArchived,
    NoteKind? kind,
    DateTime? updatedAt,
  }) => NoteEntity(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    userId: userId,
    isArchived: isArchived ?? this.isArchived,
    kind: kind ?? this.kind,
    goalId: goalId,
    taskId: taskId,
    habitId: habitId,
    occurrenceId: occurrenceId,
    outcomeId: outcomeId,
  );
}
