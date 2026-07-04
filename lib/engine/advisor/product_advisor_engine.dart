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
      recommendation: 'Complete focus sessions and tasks to unlock insights',
    ),
  ];

  List<ProductInsight> analyze({
    required int nextSeen,
    required int started,
    required int completed,
    required int focusStarted,
    required int focusCompleted,
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

    if (focusStarted > 5 && focusCompleted == 0) {
      insights.add(
        const ProductInsight(
          issue: 'Focus sessions abandoned',
          cause: 'Sessions too long or too hard',
          recommendation: 'Reduce default session length',
        ),
      );
    } else if (focusStarted > 0 &&
        focusCompleted / focusStarted < 0.4 &&
        focusStarted >= 3) {
      insights.add(
        const ProductInsight(
          issue: 'Focus completion rate is low',
          cause: 'Sessions may be too long for current energy levels',
          recommendation:
              'Try shorter sessions (10–15 min) until streak builds',
        ),
      );
    }

    if (momentumPeak < 2 && (focusCompleted > 0 || completed > 0)) {
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

    if (insights.isEmpty && focusStarted == 0 && completed == 0) {
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
      focusStarted: snapshot['focus_sessions'] as int? ?? 0,
      focusCompleted: snapshot['focus_completed'] as int? ?? 0,
      momentumPeak: momentumChainCount,
    );
  }
}
