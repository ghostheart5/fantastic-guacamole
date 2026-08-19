class OptimizationConfig {
  const OptimizationConfig({
    required this.executionDurationMultiplier,
    required this.taskDifficultyScale,
    required this.nextActionAggressiveness,
  });

  final double executionDurationMultiplier;
  final double taskDifficultyScale;
  final double nextActionAggressiveness;

  factory OptimizationConfig.neutral() => const OptimizationConfig(
    executionDurationMultiplier: 1.0,
    taskDifficultyScale: 1.0,
    nextActionAggressiveness: 1.0,
  );

  OptimizationConfig lerp(OptimizationConfig other, double t) {
    return OptimizationConfig(
      executionDurationMultiplier: _lerp(
        executionDurationMultiplier,
        other.executionDurationMultiplier,
        t,
      ),
      taskDifficultyScale: _lerp(
        taskDifficultyScale,
        other.taskDifficultyScale,
        t,
      ),
      nextActionAggressiveness: _lerp(
        nextActionAggressiveness,
        other.nextActionAggressiveness,
        t,
      ),
    );
  }

  static double _lerp(double start, double end, double amount) {
    return start + (end - start) * amount;
  }
}
