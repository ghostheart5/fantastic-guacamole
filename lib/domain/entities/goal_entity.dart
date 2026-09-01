/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Carries completion state; CompleteGoal marks, DeleteGoal removes.
class GoalEntity {
  const GoalEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description,
    this.targetDate,
    this.colorHex = 0xFF9B8AFB,
    this.completedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String? description;
  final DateTime? targetDate;
  final int colorHex;

  /// When the goal was completed, or null while it is still active. Completion
  /// is a state change, not a deletion — `DeleteGoal` is the only destructive
  /// path.
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
  bool get isActive => !isCompleted;

  GoalEntity copyWith({
    String? title,
    String? description,
    DateTime? targetDate,
    int? colorHex,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => GoalEntity(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    description: description ?? this.description,
    targetDate: targetDate ?? this.targetDate,
    colorHex: colorHex ?? this.colorHex,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
  );

  /// Marks the goal complete. Idempotent: re-completing keeps the original
  /// completion timestamp.
  GoalEntity markCompleted(DateTime at) {
    return completedAt != null ? this : copyWith(completedAt: at);
  }

  GoalEntity reopen() => copyWith(clearCompletedAt: true);

  void validate() {
    if (id.trim().isEmpty) {
      throw StateError('Goals require an id.');
    }
    if (title.trim().isEmpty) {
      throw StateError('Goals require a title.');
    }
    if (completedAt?.isBefore(createdAt) ?? false) {
      throw StateError('Goal completion cannot predate creation.');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    if (description != null) 'description': description,
    if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
    'colorHex': colorHex,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
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
    completedAt: j['completedAt'] != null
        ? DateTime.tryParse(j['completedAt'] as String)
        : null,
  );
}
