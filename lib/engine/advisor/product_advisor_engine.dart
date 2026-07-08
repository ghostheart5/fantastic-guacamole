class ProductInsight {
  const ProductInsight({
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
    ProductInsight(
      issue: 'Not enough data yet',
      cause: 'Keep using the app to generate insights',
      recommendation: 'Complete tasks to unlock insights',
    ),
  ];

  List<ProductInsight> analyze({
    required int nextSeen,
    required int started,
    required int completed,
    required int momentumPeak,
  }) {
    final insights = <ProductInsight>[];

    if (nextSeen > 10 && started < 2) {
      insights.add(
        const ProductInsight(
          issue: "Users see next step but don't start",
          cause: 'Next step not compelling',
          recommendation: 'Simplify next step or reduce task size',
        ),
      );
    }

    if (momentumPeak < 2 && completed > 0) {
      insights.add(
        const ProductInsight(
          issue: 'Low momentum',
          cause: 'Users not chaining actions',
          recommendation: 'Make next step easier and faster',
        ),
      );
    }

    if (started > 5 && completed < started ~/ 2) {
      insights.add(
        const ProductInsight(
          issue: 'Tasks started but not completed',
          cause: 'Tasks may be too complex or scope is unclear',
          recommendation: 'Break tasks into smaller subtasks',
        ),
      );
    }

    if (insights.isEmpty && completed == 0) {
      return _fallback;
    }

    if (insights.isEmpty) {
      insights.add(
        const ProductInsight(
          issue: 'No major issues detected',
          cause: 'System performing well',
          recommendation: 'Maintain current behavior',
        ),
      );
    }

    return insights;
  }

  List<ProductInsight> fromSnapshot(
    Map<String, dynamic> snapshot,
    int momentumChainCount,
  ) {
    return analyze(
      nextSeen: snapshot['tasks_created'] as int? ?? 0,
      started: snapshot['tasks_created'] as int? ?? 0,
      completed: snapshot['tasks_completed'] as int? ?? 0,
      momentumPeak: momentumChainCount,
    );
  }
}
