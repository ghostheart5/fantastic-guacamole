import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';

class MilestoneDraft {
  const MilestoneDraft({
    required this.title,
    this.description,
    this.goalId,
    this.projectId,
    this.habitId,
    required this.category,
    required this.priority,
    this.targetDate,
    this.reward,
    this.note,
    this.reminderAt,
    this.dependencies = const <String>[],
  });

  final String title;
  final String? description;
  final String? goalId;
  final String? projectId;
  final String? habitId;
  final MilestoneCategory category;
  final MilestonePriority priority;
  final DateTime? targetDate;
  final String? reward;
  final String? note;
  final DateTime? reminderAt;
  final List<String> dependencies;
}
