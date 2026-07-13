enum SubtaskStatus { pending, completed, canceled }

class SubtaskEntity {
  SubtaskEntity({
    required this.id,
    required this.parentTaskId,
    required this.title,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.status = SubtaskStatus.pending,
    this.completedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String parentTaskId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final SubtaskStatus status;
  final DateTime? completedAt;

  bool get isCompleted => status == SubtaskStatus.completed;

  SubtaskEntity copyWith({
    String? parentTaskId,
    String? title,
    DateTime? updatedAt,
    String? userId,
    SubtaskStatus? status,
    DateTime? completedAt,
  }) {
    return SubtaskEntity(
      id: id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  SubtaskEntity complete() {
    return copyWith(
      status: SubtaskStatus.completed,
      completedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'parentTaskId': parentTaskId,
      'userId': userId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory SubtaskEntity.fromJson(Map<String, dynamic> json) {
    return SubtaskEntity(
      id: json['id']?.toString() ?? '',
      parentTaskId: json['parentTaskId']?.toString() ?? '',
      userId: json['userId']?.toString(),
      title: json['title']?.toString() ?? 'Untitled Subtask',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: SubtaskStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => json['isCompleted'] == true
            ? SubtaskStatus.completed
            : SubtaskStatus.pending,
      ),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'].toString()),
    );
  }
}
