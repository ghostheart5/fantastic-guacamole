class TrajectorySummaryView {
  const TrajectorySummaryView({
    required this.pendingTasks,
    required this.completedTasks,
    required this.completedToday,
    required this.level,
    required this.streak,
    required this.energy,
    required this.momentum,
    required this.adaptability,
    required this.lastCompletionXp,
    required this.lastCompletionQuality,
    required this.pressureIndex,
    required this.behaviorDivergence,
    required this.alert,
    required this.predictionTitle,
    required this.predictionOutcome,
    required this.predictionProbability,
    required this.predictionExplanation,
  });

  final int pendingTasks;
  final int completedTasks;
  final int completedToday;
  final int level;
  final int streak;
  final double energy;
  final double momentum;
  final double adaptability;
  final int lastCompletionXp;
  final double lastCompletionQuality;
  final int pressureIndex;
  final int behaviorDivergence;
  final String alert;
  final String? predictionTitle;
  final String? predictionOutcome;
  final double? predictionProbability;
  final String? predictionExplanation;

  bool get hasPrediction =>
      predictionTitle != null &&
      predictionOutcome != null &&
      predictionProbability != null &&
      predictionExplanation != null;
}
