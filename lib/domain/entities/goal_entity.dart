enum GoalStatus { active, completed, archived }

class GoalEntity {
  const GoalEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description,
    this.targetDate,
    this.colorHex = 0xFF9B8AFB,
    this.userId,
    this.status = GoalStatus.active,
    this.completedAt,
    this.archivedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String? description;
  final DateTime? targetDate;
  final int colorHex;
  final String? userId;
  final GoalStatus status;
  final DateTime? completedAt;
  final DateTime? archivedAt;

  bool get isActive => status == GoalStatus.active;
  bool get isCompleted => status == GoalStatus.completed || completedAt != null;
  bool get isArchived => status == GoalStatus.archived || archivedAt != null;

  GoalEntity copyWith({
    String? title,
    String? description,
    DateTime? targetDate,
    int? colorHex,
    String? userId,
    GoalStatus? status,
    DateTime? completedAt,
    DateTime? archivedAt,
  }) => GoalEntity(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    description: description ?? this.description,
    targetDate: targetDate ?? this.targetDate,
    colorHex: colorHex ?? this.colorHex,
    userId: userId ?? this.userId,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    archivedAt: archivedAt ?? this.archivedAt,
  );

  GoalEntity markCompleted([DateTime? when]) {
    final DateTime at = when ?? DateTime.now();
    return copyWith(status: GoalStatus.completed, completedAt: at);
  }

  GoalEntity archive([DateTime? when]) {
    final DateTime at = when ?? DateTime.now();
    return copyWith(status: GoalStatus.archived, archivedAt: at);
  }

  GoalEntity activate() {
    return copyWith(status: GoalStatus.active);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    if (description != null) 'description': description,
    if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
    'colorHex': colorHex,
    if (userId != null) 'userId': userId,
    'status': status.name,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
  };

  factory GoalEntity.fromJson(Map<String, dynamic> j) => GoalEntity(
    id: j['id'] as String,
    title: j['title'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    description: j['description'] as String?,
    targetDate: j['targetDate'] != null
        ? DateTime.tryParse(j['targetDate'] as String)
        : null,
    colorHex: (j['colorHex'] as num?)?.toInt() ?? 0xFF9B8AFB,
    userId: j['userId']?.toString(),
    status: GoalStatus.values.firstWhere(
      (GoalStatus value) => value.name == j['status']?.toString(),
      orElse: () {
        if (j['archivedAt'] != null || j['isArchived'] == true) {
          return GoalStatus.archived;
        }
        if (j['completedAt'] != null || j['isCompleted'] == true) {
          return GoalStatus.completed;
        }
        return GoalStatus.active;
      },
    ),
    completedAt: j['completedAt'] != null
        ? DateTime.tryParse(j['completedAt'].toString())
        : null,
    archivedAt: j['archivedAt'] != null
        ? DateTime.tryParse(j['archivedAt'].toString())
        : null,
  );
}
