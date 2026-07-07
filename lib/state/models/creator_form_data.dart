import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

class CreatorFormData {
  const CreatorFormData({
    required this.title,
    this.description,
    required this.type,
    required this.priority,
    this.scheduledFor,
    this.recurrenceRule = RecurrenceRule.none,
  });

  final String title;
  final String? description;
  final String type;
  final int priority;
  final DateTime? scheduledFor;
  final RecurrenceRule recurrenceRule;
}
