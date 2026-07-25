import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final String? kind;
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
    this.description,
    this.kind,
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
      description: json['description'] as String?,
      kind: json['kind'] as String?,
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
    if (description != null) 'description': description,
    if (kind != null) 'kind': kind,
    'priority': priority,
    'difficulty': difficulty,
    'energyRequired': energyRequired,
    if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
    if (goalId != null) 'goalId': goalId,
    if (subtasks.isNotEmpty) 'subtasks': subtasks,
    if (recurrenceRule != RecurrenceRule.none)
      'recurrenceRule': recurrenceRule.name,
  };

  bool get hasSubtasks => subtasks.isNotEmpty;
  bool get isRecurring => recurrenceRule != RecurrenceRule.none;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? kind,
    int? priority,
    int? difficulty,
    int? energyRequired,
    DateTime? scheduledFor,
    String? goalId,
    List<String>? subtasks,
    RecurrenceRule? recurrenceRule,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      goalId: goalId ?? this.goalId,
      subtasks: subtasks ?? this.subtasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}
