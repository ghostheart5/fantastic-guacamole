enum MilestoneStatus { planned, inProgress, completed, overdue, archived }

enum MilestoneCategory {
  goal,
  project,
  habit,
  streak,
  timeline,
  financial,
  health,
  learning,
  life,
  futureSelf,
  other,
}

enum MilestonePriority { low, medium, high, critical }

class MilestoneEntity {
  const MilestoneEntity({
    required this.id,
    this.goalId,
    this.projectId,
    this.habitId,
    required this.title,
    this.description,
    this.status = MilestoneStatus.planned,
    this.category = MilestoneCategory.other,
    this.priority = MilestonePriority.medium,
    this.targetDate,
    this.completionPercent = 0,
    this.reward,
    this.reminderAt,
    this.note,
    this.reflection,
    this.dependencies = const <String>[],
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.archivedAt,
  });

  final String id;
  final String? goalId;
  final String? projectId;
  final String? habitId;
  final String title;
  final String? description;
  final MilestoneStatus status;
  final MilestoneCategory category;
  final MilestonePriority priority;
  final DateTime? targetDate;
  final double completionPercent;
  final String? reward;
  final DateTime? reminderAt;
  final String? note;
  final String? reflection;
  final List<String> dependencies;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;

  bool get isCompleted => status == MilestoneStatus.completed;
  bool get isArchived =>
      status == MilestoneStatus.archived || archivedAt != null;
  bool get isOverdue {
    final DateTime? due = targetDate;
    if (due == null || isCompleted || isArchived) {
      return false;
    }
    return due.isBefore(DateTime.now()) || status == MilestoneStatus.overdue;
  }

  bool get isUpcoming {
    final DateTime? due = targetDate;
    if (due == null || isCompleted || isArchived) {
      return false;
    }
    final Duration delta = due.difference(DateTime.now());
    return delta.inDays <= 14 && delta.inHours >= 0;
  }

  bool get isActive => !isCompleted && !isArchived;

  MilestoneEntity copyWith({
    String? goalId,
    String? projectId,
    String? habitId,
    String? title,
    String? description,
    MilestoneStatus? status,
    MilestoneCategory? category,
    MilestonePriority? priority,
    DateTime? targetDate,
    double? completionPercent,
    String? reward,
    DateTime? reminderAt,
    String? note,
    String? reflection,
    List<String>? dependencies,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? archivedAt,
  }) {
    return MilestoneEntity(
      id: id,
      goalId: goalId ?? this.goalId,
      projectId: projectId ?? this.projectId,
      habitId: habitId ?? this.habitId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      targetDate: targetDate ?? this.targetDate,
      completionPercent: completionPercent ?? this.completionPercent,
      reward: reward ?? this.reward,
      reminderAt: reminderAt ?? this.reminderAt,
      note: note ?? this.note,
      reflection: reflection ?? this.reflection,
      dependencies: dependencies ?? this.dependencies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'goalId': goalId,
      'projectId': projectId,
      'habitId': habitId,
      'title': title,
      'description': description,
      'status': status.name,
      'category': category.name,
      'priority': priority.name,
      'targetDate': targetDate?.toIso8601String(),
      'completionPercent': completionPercent,
      'reward': reward,
      'reminderAt': reminderAt?.toIso8601String(),
      'note': note,
      'reflection': reflection,
      'dependencies': dependencies,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
    };
  }

  factory MilestoneEntity.fromJson(Map<String, dynamic> json) {
    double parsedCompletion = 0;
    final dynamic rawCompletion = json['completionPercent'];
    if (rawCompletion is num) {
      parsedCompletion = rawCompletion.toDouble();
    } else if (rawCompletion != null) {
      parsedCompletion = double.tryParse(rawCompletion.toString()) ?? 0;
    }

    return MilestoneEntity(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      goalId: json['goalId']?.toString(),
      projectId: json['projectId']?.toString(),
      habitId: json['habitId']?.toString(),
      title: json['title']?.toString() ?? 'Untitled Milestone',
      description: json['description']?.toString(),
      status: MilestoneStatus.values.firstWhere(
        (MilestoneStatus value) => value.name == json['status']?.toString(),
        orElse: () => MilestoneStatus.planned,
      ),
      category: MilestoneCategory.values.firstWhere(
        (MilestoneCategory value) => value.name == json['category']?.toString(),
        orElse: () => MilestoneCategory.other,
      ),
      priority: MilestonePriority.values.firstWhere(
        (MilestonePriority value) => value.name == json['priority']?.toString(),
        orElse: () => MilestonePriority.medium,
      ),
      targetDate: json['targetDate'] == null
          ? null
          : DateTime.tryParse(json['targetDate'].toString()),
      completionPercent: parsedCompletion.clamp(0, 100),
      reward: json['reward']?.toString(),
      reminderAt: json['reminderAt'] == null
          ? null
          : DateTime.tryParse(json['reminderAt'].toString()),
      note: json['note']?.toString(),
      reflection: json['reflection']?.toString(),
      dependencies:
          (json['dependencies'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'].toString()),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.tryParse(json['archivedAt'].toString()),
    );
  }
}
