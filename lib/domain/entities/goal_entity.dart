class GoalEntity {
  final String id;
  final String title;
  final double progress;
  final DateTime? dueDate;

  const GoalEntity({
    required this.id,
    required this.title,
    required this.progress,
    this.dueDate,
  });
}
