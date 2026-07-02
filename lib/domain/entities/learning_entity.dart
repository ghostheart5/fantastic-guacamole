class LearningEntity {
  const LearningEntity({
    this.effortWeight = 1.0,
    this.priorityWeight = 1.0,
    this.completed = 0,
    this.skipped = 0,
  });

  final double effortWeight;
  final double priorityWeight;
  final int completed;
  final int skipped;

  LearningEntity copyWith({
    double? effortWeight,
    double? priorityWeight,
    int? completed,
    int? skipped,
  }) {
    return LearningEntity(
      effortWeight: effortWeight ?? this.effortWeight,
      priorityWeight: priorityWeight ?? this.priorityWeight,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
    );
  }
}
