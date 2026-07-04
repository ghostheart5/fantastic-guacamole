import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

class Task {
  final String id;
  final String title;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final String? goalId;
  final List<String> subtasks;
  final RecurrenceRule recurrenceRule;

  const Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
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
    if (goalId != null) 'goalId': goalId,
    if (subtasks.isNotEmpty) 'subtasks': subtasks,
    if (recurrenceRule != RecurrenceRule.none)
      'recurrenceRule': recurrenceRule.name,
  };
}
