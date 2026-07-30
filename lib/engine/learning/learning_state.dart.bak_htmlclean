class LearningState {
  const LearningState({
    this.effortWeight = 1.0,
    this.priorityWeight = 1.0,
    this.completed = 0,
    this.skipped = 0,
  });

  final double effortWeight;
  final double priorityWeight;
  final int completed;
  final int skipped;

  LearningState copyWith({
    double? effortWeight,
    double? priorityWeight,
    int? completed,
    int? skipped,
  }) {
    return LearningState(
      effortWeight: effortWeight ?? this.effortWeight,
      priorityWeight: priorityWeight ?? this.priorityWeight,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'effortWeight': effortWeight,
    'priorityWeight': priorityWeight,
    'completed': completed,
    'skipped': skipped,
  };

  factory LearningState.fromJson(Map<String, dynamic> json) {
    return LearningState(
      effortWeight: ((json['effortWeight'] as num?) ?? 1.0).toDouble(),
      priorityWeight: ((json['priorityWeight'] as num?) ?? 1.0).toDouble(),
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
    );
  }
}
