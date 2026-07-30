class GlobalMetrics {
  const GlobalMetrics({
    required this.avgTaskCompletionRate,
    required this.avgMomentumPeak,
  });

  final double avgTaskCompletionRate;
  final double avgMomentumPeak;

  factory GlobalMetrics.empty() =>
      const GlobalMetrics(avgTaskCompletionRate: 0, avgMomentumPeak: 0);

  factory GlobalMetrics.fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return GlobalMetrics.empty();

    double totalTaskRate = 0;
    double totalMomentumPeak = 0;

    for (final row in rows) {
      final int tasksCreated = (row['tasks_created'] as num?)?.toInt() ?? 0;
      final int tasksCompleted = (row['tasks_completed'] as num?)?.toInt() ?? 0;
      final double momentumPeak =
          (row['momentum_peak'] as num?)?.toDouble() ?? 0;

      totalTaskRate += tasksCreated > 0 ? tasksCompleted / tasksCreated : 0;
      totalMomentumPeak += momentumPeak;
    }

    final int count = rows.length;
    return GlobalMetrics(
      avgTaskCompletionRate: totalTaskRate / count,
      avgMomentumPeak: totalMomentumPeak / count,
    );
  }
}
