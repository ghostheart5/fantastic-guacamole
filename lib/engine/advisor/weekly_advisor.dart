import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';

class WeeklyAdvisor {
  const WeeklyAdvisor();

  String summarize(List<ProductInsight> insights) {
    if (insights.isEmpty) {
      return 'Not enough data yet. Keep using the app to generate insights.';
    }

    if (insights.length == 1 &&
        insights.first.issue == 'No major issues detected') {
      return 'This week the system is performing well. '
          'Keep up the current habits and session rhythm.';
    }

    if (insights.length == 1 && insights.first.issue == 'Not enough data yet') {
      return 'Not enough data yet. Keep using the app to generate insights.';
    }

    final parts = <String>[];

    for (final insight in insights) {
      if (insight.issue.contains("don't start")) {
        parts.add('users are seeing next steps but not acting on them');
      } else if (insight.issue.contains('Low momentum')) {
        parts.add('momentum chains are short — actions are not flowing');
      } else if (insight.issue.contains('not completed')) {
        parts.add('tasks are being started but not finished');
      }
    }

    if (parts.isEmpty) {
      return insights.first.recommendation;
    }

    final top = insights.first;
    final body = parts.join(', and ');
    return 'This week ${body.substring(0, 1).toUpperCase()}${body.substring(1)}. '
        'Recommendation: ${top.recommendation}.';
  }
}
