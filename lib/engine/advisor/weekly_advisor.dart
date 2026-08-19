import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';

class WeeklyAdvisor {
  const WeeklyAdvisor();

  String summarize(List<ProductRecommendation> recommendations) {
    if (recommendations.isEmpty) {
      return 'Not enough data yet. Keep using the app to build recommendations.';
    }

    if (recommendations.length == 1 &&
        recommendations.first.issue == 'No major issues detected') {
      return 'This week the system is performing well. '
          'Keep up the current habits and activity rhythm.';
    }

    if (recommendations.length == 1 &&
        recommendations.first.issue == 'Not enough data yet') {
      return 'Not enough data yet. Keep using the app to build recommendations.';
    }

    final parts = <String>[];

    for (final recommendation in recommendations) {
      if (recommendation.issue.contains("don't start")) {
        parts.add('users are seeing next steps but not acting on them');
      } else if (recommendation.issue.contains('Low momentum')) {
        parts.add('momentum chains are short — actions are not flowing');
      } else if (recommendation.issue.contains('not completed')) {
        parts.add('tasks are being started but not finished');
      }
    }

    if (parts.isEmpty) {
      return recommendations.first.recommendation;
    }

    final top = recommendations.first;
    final body = parts.join(', and ');
    return 'This week ${body.substring(0, 1).toUpperCase()}${body.substring(1)}. '
        'Recommendation: ${top.recommendation}.';
  }
}
