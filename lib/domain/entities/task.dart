import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

/// CHRONOSPARK-CLASS: LEGACY | Feature: Goals/tasks
///
/// Older task shape still used by the UI and engine. Migration target is
/// TaskEntity; do not add fields here.
/// Compatibility note: [Task] and `TaskEntity` model the same concept.
/// `TaskEntity` is a strict superset — it additionally carries `description`,
/// `createdAt`, `isCompleted`, `completedAt`, `dueDate`, `isCanceled` and
/// `estimatedDuration`. Anything mapping `TaskEntity -> Task` therefore DROPS
/// those seven fields, and mapping back cannot recover them.
///
/// Current split: the UI/engine layers use [Task]; repositories and use cases
/// use `TaskEntity`. Converting the whole app in one pass is too risky, so the
/// agreed migration is: (1) cover every mapping boundary with tests — see
/// `test/domain/entities/task_mapping_test.dart`, (2) migrate one feature at a
/// time onto `TaskEntity`, (3) delete this type. Do not add fields here.
class Task {
  final String id;
  final String title;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final DateTime? scheduledFor;
  final String? goalId;
  final List<String> subtasks;
  final RecurrenceRule recurrenceRule;

  const Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
    this.scheduledFor,
    this.goalId,
    this.subtasks = const [],
    this.recurrenceRule = RecurrenceRule.none,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      energyRequired: (json['energyRequired'] as num?)?.toInt() ?? 3,
      scheduledFor: DateTime.tryParse(json['scheduledFor']?.toString() ?? ''),
      goalId: json['goalId'] as String?,
      subtasks:
          (json['subtasks'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      recurrenceRule: RecurrenceRule.values.firstWhere(
        (r) => r.name == json['recurrenceRule'],
        orElse: () => RecurrenceRule.none,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'priority': priority,
    'difficulty': difficulty,
    'energyRequired': energyRequired,
    if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
    if (goalId != null) 'goalId': goalId,
    if (subtasks.isNotEmpty) 'subtasks': subtasks,
    if (recurrenceRule != RecurrenceRule.none)
      'recurrenceRule': recurrenceRule.name,
  };

  // Optional ergonomic helpers
  bool get hasSubtasks => subtasks.isNotEmpty;
  bool get isRecurring => recurrenceRule != RecurrenceRule.none;

  Task copyWith({
    String? id,
    String? title,
    int? priority,
    int? difficulty,
    int? energyRequired,
    String? goalId,
    List<String>? subtasks,
    RecurrenceRule? recurrenceRule,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      goalId: goalId ?? this.goalId,
      subtasks: subtasks ?? this.subtasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}
