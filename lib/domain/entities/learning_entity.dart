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

  // Domain behavior
  double get score {
    final base = completed * effortWeight;
    final penalty = skipped * (effortWeight * 0.5);
    return base - penalty;
  }

  double get weightedScore {
    return (completed * effortWeight * priorityWeight) -
        (skipped * effortWeight * 0.5);
  }

  double get progressRatio {
    final total = completed + skipped;
    if (total == 0) return 0.0;
    return completed / total;
  }

  LearningEntity markCompleted() => copyWith(completed: completed + 1);

  LearningEntity markSkipped() => copyWith(skipped: skipped + 1);

  void validate() {
    if (effortWeight <= 0 || priorityWeight <= 0) {
      throw StateError('Weights must be positive');
    }
  }
}
