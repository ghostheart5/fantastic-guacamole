import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class GlobalOptimizer {
  const GlobalOptimizer();

  OptimizationConfig compute({required double averageTaskCompletionRate}) {
    final double rate = averageTaskCompletionRate;
    final double multiplier;
    if (rate > 0.7) {
      // Most users finish long sessions — push harder
      multiplier = 1.1;
    } else if (rate > 0 && rate < 0.4) {
      // Most users bail early — dial back
      multiplier = 0.9;
    } else {
      multiplier = 1.0;
    }
    return OptimizationConfig(
      focusDurationMultiplier: multiplier,
      taskDifficultyScale: 1.0,
      nextActionAggressiveness: 1.0,
    );
  }
}
