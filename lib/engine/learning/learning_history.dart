enum LearningEventType { completed, skipped, simulated }

class LearningHistoryEntry {
  const LearningHistoryEntry({
    required this.timestamp,
    required this.type,
    required this.difficulty,
    required this.effortWeight,
    required this.priorityWeight,
    required this.completed,
    required this.skipped,
  });

  final DateTime timestamp;
  final LearningEventType type;
  final int difficulty;
  final double effortWeight;
  final double priorityWeight;
  final int completed;
  final int skipped;
}
