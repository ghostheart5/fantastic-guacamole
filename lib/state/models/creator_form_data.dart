import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

enum CreatorFormKind {
  task,
  goal,
  habit,
  note;

  static CreatorFormKind fromType(String type) {
    return switch (type.trim().toLowerCase()) {
      'goal' => CreatorFormKind.goal,
      'habit' ||
      'routine' ||
      'daily rhythm' ||
      'daily_rhythm' => CreatorFormKind.habit,
      'note' => CreatorFormKind.note,
      _ => CreatorFormKind.task,
    };
  }
}

class CreatorFormData {
  const CreatorFormData({
    required this.title,
    this.description,
    required this.type,
    required this.priority,
    this.scheduledFor,
    this.recurrenceRule = RecurrenceRule.none,
    this.goalId,
    this.estimatedDuration,
    this.dueDate,
    this.targetDate,
    this.goalColorHex = 0xFF9B8AFB,
    this.habitCadence = HabitCadence.daily,
    this.habitTargetCount = 1,
  }) : assert(habitTargetCount > 0);

  final String title;
  final String? description;
  final String type;
  final int priority;
  final DateTime? scheduledFor;
  final RecurrenceRule recurrenceRule;
  final String? goalId;
  final Duration? estimatedDuration;
  final DateTime? dueDate;
  final DateTime? targetDate;
  final int goalColorHex;
  final HabitCadence habitCadence;
  final int habitTargetCount;

  CreatorFormKind get kind => CreatorFormKind.fromType(type);
}
