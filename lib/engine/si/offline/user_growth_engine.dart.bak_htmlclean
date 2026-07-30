class UserGrowthState {
  const UserGrowthState({
    this.skillProgress = 0.0,
    this.adaptationRate = 0.0,
    this.growthVelocity = 0.0,
  });

  final double skillProgress; // 0.0–1.0
  final double adaptationRate; // 0.0–1.0
  final double growthVelocity; // 0.0–1.0

  UserGrowthState copyWith({
    double? skillProgress,
    double? adaptationRate,
    double? growthVelocity,
  }) => UserGrowthState(
    skillProgress: skillProgress ?? this.skillProgress,
    adaptationRate: adaptationRate ?? this.adaptationRate,
    growthVelocity: growthVelocity ?? this.growthVelocity,
  );
}

class UserGrowthEngine {
  const UserGrowthEngine();

  UserGrowthState update(
    UserGrowthState current, {
    required int completedTasks,
    required int streak,
    required double consistency,
  }) {
    final double taskBoost = (completedTasks / 100.0).clamp(0.0, 1.0);
    final double streakBoost = (streak / 30.0).clamp(0.0, 1.0);
    return UserGrowthState(
      skillProgress: (current.skillProgress + taskBoost * 0.02).clamp(0.0, 1.0),
      adaptationRate: (current.adaptationRate + consistency * 0.01).clamp(
        0.0,
        1.0,
      ),
      growthVelocity: (current.growthVelocity + streakBoost * 0.015).clamp(
        0.0,
        1.0,
      ),
    );
  }

  String growthTitle(UserGrowthState state) {
    final double avg =
        (state.skillProgress + state.adaptationRate + state.growthVelocity) /
        3.0;
    if (avg >= 0.75) return 'Architect';
    if (avg >= 0.5) return 'Catalyst';
    if (avg >= 0.25) return 'Builder';
    return 'Beginner';
  }
}
