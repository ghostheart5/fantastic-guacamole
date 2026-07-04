class GlobalMetrics {
  const GlobalMetrics({
    required this.avgFocusCompletionRate,
    required this.avgTaskCompletionRate,
    required this.avgMomentumPeak,
    required this.avgSessionDuration,
  });

  final double avgFocusCompletionRate;
  final double avgTaskCompletionRate;
  final double avgMomentumPeak;
  final double avgSessionDuration;

  factory GlobalMetrics.empty() => const GlobalMetrics(
    avgFocusCompletionRate: 0,
    avgTaskCompletionRate: 0,
    avgMomentumPeak: 0,
    avgSessionDuration: 0,
  );

  factory GlobalMetrics.fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return GlobalMetrics.empty();

    double totalCompletion = 0;
    double totalTaskRate = 0;
    double totalMomentumPeak = 0;
    double totalSessionDuration = 0;

    for (final row in rows) {
      final int sessions = (row['focus_sessions'] as num?)?.toInt() ?? 0;
      final int completed = (row['focus_completed'] as num?)?.toInt() ?? 0;
      final int tasksCreated = (row['tasks_created'] as num?)?.toInt() ?? 0;
      final int tasksCompleted = (row['tasks_completed'] as num?)?.toInt() ?? 0;
      final double focusSeconds =
          (row['total_focus_seconds'] as num?)?.toDouble() ?? 0;
      final double momentumPeak =
          (row['momentum_peak'] as num?)?.toDouble() ?? 0;

      totalCompletion += sessions > 0 ? completed / sessions : 0;
      totalTaskRate += tasksCreated > 0 ? tasksCompleted / tasksCreated : 0;
      totalMomentumPeak += momentumPeak;
      totalSessionDuration += completed > 0 ? focusSeconds / completed : 0;
    }

    final int count = rows.length;
    return GlobalMetrics(
      avgFocusCompletionRate: totalCompletion / count,
      avgTaskCompletionRate: totalTaskRate / count,
      avgMomentumPeak: totalMomentumPeak / count,
      avgSessionDuration: totalSessionDuration / count,
    );
  }
}
