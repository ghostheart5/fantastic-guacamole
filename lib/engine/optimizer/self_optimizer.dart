import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class SelfOptimizer {
  const SelfOptimizer();

  OptimizationConfig adjust(
    OptimizationConfig current,
    List<ProductInsight> insights,
  ) {
    if (insights.isEmpty ||
        insights.first.issue == 'No major issues detected' ||
        insights.first.issue == 'Not enough data yet') {
      return current;
    }

    var focusMult = current.focusDurationMultiplier;
    var diffScale = current.taskDifficultyScale;
    var aggression = current.nextActionAggressiveness;

    for (final insight in insights) {
      if (insight.issue.contains("don't start")) {
        aggression = (aggression * 0.9).clamp(0.5, 1.5);
      }
      if (insight.issue.contains('Low momentum') ||
          insight.issue.contains('not completed')) {
        diffScale = (diffScale * 0.85).clamp(0.5, 1.5);
        aggression = (aggression * 0.9).clamp(0.5, 1.5);
      }
    }

    return OptimizationConfig(
      focusDurationMultiplier: focusMult,
      taskDifficultyScale: diffScale,
      nextActionAggressiveness: aggression,
    );
  }
}
