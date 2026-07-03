class SISnapshot {
  const SISnapshot({
    required this.timestamp,
    required this.energy,
    required this.fatigue,
    required this.completed,
    required this.skipped,
    this.taskId,
    this.reasoning,
  });

  final DateTime timestamp;
  final double energy;
  final double fatigue;
  final int completed;
  final int skipped;
  final String? taskId;
  final String? reasoning;
}
