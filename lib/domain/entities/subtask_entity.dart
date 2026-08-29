/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
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
    bool clearCompletedAt = false,
  }) {
    final SubtaskStatus resolvedStatus = status ?? this.status;
    return SubtaskEntity(
      id: id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      status: resolvedStatus,
      completedAt: clearCompletedAt || resolvedStatus != SubtaskStatus.completed
          ? null
          : completedAt ?? this.completedAt,
    );
  }

  SubtaskEntity complete({DateTime? at}) {
    final DateTime timestamp = at ?? DateTime.now();
    return copyWith(
      status: SubtaskStatus.completed,
      completedAt: timestamp,
      updatedAt: timestamp,
    );
  }

  SubtaskEntity reopen({DateTime? at}) => copyWith(
    status: SubtaskStatus.pending,
    clearCompletedAt: true,
    updatedAt: at ?? DateTime.now(),
  );

  SubtaskEntity cancel({DateTime? at}) => copyWith(
    status: SubtaskStatus.canceled,
    clearCompletedAt: true,
    updatedAt: at ?? DateTime.now(),
  );

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
          DateTime.fromMillisecondsSinceEpoch(0),
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
