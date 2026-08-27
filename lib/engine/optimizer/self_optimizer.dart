import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class SelfOptimizer {
  const SelfOptimizer();

  OptimizationConfig adjust(
    OptimizationConfig current,
    List<ProductRecommendation> recommendations,
  ) {
    if (recommendations.isEmpty ||
        recommendations.first.issue == 'No major issues detected' ||
        recommendations.first.issue == 'Not enough data yet') {
      return current;
    }

    var executionMult = current.executionDurationMultiplier;
    var diffScale = current.taskDifficultyScale;
    var aggression = current.nextActionAggressiveness;

    for (final recommendation in recommendations) {
      if (recommendation.issue.contains("don't start")) {
        aggression = (aggression * 0.9).clamp(0.5, 1.5);
      }
      if (recommendation.issue.contains('Low momentum') ||
          recommendation.issue.contains('not completed')) {
        diffScale = (diffScale * 0.85).clamp(0.5, 1.5);
        aggression = (aggression * 0.9).clamp(0.5, 1.5);
      }
    }

    return OptimizationConfig(
      executionDurationMultiplier: executionMult,
      taskDifficultyScale: diffScale,
      nextActionAggressiveness: aggression,
    );
  }
}
