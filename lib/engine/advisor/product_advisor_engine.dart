class ProductRecommendation {
  const ProductRecommendation({
    required this.issue,
    required this.cause,
    required this.recommendation,
  });

  final String issue;
  final String cause;
  final String recommendation;
}

class ProductAdvisorEngine {
  const ProductAdvisorEngine();

  static const _fallback = [
    ProductRecommendation(
      issue: 'Not enough data yet',
      cause: 'More execution history is required',
      recommendation: 'Complete tasks to unlock recommendations',
    ),
  ];

  List<ProductRecommendation> analyze({
    required int nextSeen,
    required int started,
    required int completed,
    required int momentumPeak,
  }) {
    final recommendations = <ProductRecommendation>[];

    if (nextSeen > 10 && started < 2) {
      recommendations.add(
        const ProductRecommendation(
          issue: "Users see next step but don't start",
          cause: 'Next step not compelling',
          recommendation: 'Simplify next step or reduce task size',
        ),
      );
    }

    if (momentumPeak < 2 && completed > 0) {
      recommendations.add(
        const ProductRecommendation(
          issue: 'Low momentum',
          cause: 'Users not chaining actions',
          recommendation: 'Make next step easier and faster',
        ),
      );
    }

    if (started > 5 && completed < started ~/ 2) {
      recommendations.add(
        const ProductRecommendation(
          issue: 'Tasks started but not completed',
          cause: 'Tasks may be too complex or scope is unclear',
          recommendation: 'Break tasks into smaller subtasks',
        ),
      );
    }

    if (recommendations.isEmpty && completed == 0) {
      return _fallback;
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        const ProductRecommendation(
          issue: 'No major issues detected',
          cause: 'System performing well',
          recommendation: 'Maintain current behavior',
        ),
      );
    }

    return recommendations;
  }

  List<ProductRecommendation> fromSnapshot(
    Map<String, dynamic> snapshot,
    int momentumChainCount,
  ) {
    // Task creation is not evidence that a task was seen or started. Only use
    // the dedicated counters when instrumentation has supplied them.
    return analyze(
      nextSeen: (snapshot['tasks_seen'] as num?)?.toInt() ?? 0,
      started: (snapshot['tasks_started'] as num?)?.toInt() ?? 0,
      completed: snapshot['tasks_completed'] as int? ?? 0,
      momentumPeak: momentumChainCount,
    );
  }
}
