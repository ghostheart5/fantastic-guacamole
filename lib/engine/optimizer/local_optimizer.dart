import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class LocalOptimizer {
  const LocalOptimizer();

  OptimizationConfig compute({required int streak}) {
    final double multiplier;
    if (streak >= 14) {
      multiplier = 1.15;
    } else if (streak >= 7) {
      multiplier = 1.08;
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
