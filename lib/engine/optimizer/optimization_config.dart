import 'dart:ui';

class OptimizationConfig {
  const OptimizationConfig({
    required this.focusDurationMultiplier,
    required this.taskDifficultyScale,
    required this.nextActionAggressiveness,
  });

  final double focusDurationMultiplier;
  final double taskDifficultyScale;
  final double nextActionAggressiveness;

  factory OptimizationConfig.neutral() => const OptimizationConfig(
    focusDurationMultiplier: 1.0,
    taskDifficultyScale: 1.0,
    nextActionAggressiveness: 1.0,
  );

  OptimizationConfig lerp(OptimizationConfig other, double t) {
    return OptimizationConfig(
      focusDurationMultiplier: lerpDouble(
        focusDurationMultiplier,
        other.focusDurationMultiplier,
        t,
      )!,
      taskDifficultyScale: lerpDouble(
        taskDifficultyScale,
        other.taskDifficultyScale,
        t,
      )!,
      nextActionAggressiveness: lerpDouble(
        nextActionAggressiveness,
        other.nextActionAggressiveness,
        t,
      )!,
    );
  }
}
