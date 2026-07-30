// Identity Engine — language-based identity reinforcement
// Tracks discipline, focus, and growth identity dimensions (0.0–1.0).
// Wraps SI responses with identity-affirming language when thresholds are met.

class IdentityState {
  const IdentityState({
    required this.disciplineIdentity,
    required this.focusIdentity,
    required this.growthIdentity,
  });

  final double disciplineIdentity; // 0.0–1.0
  final double focusIdentity;
  final double growthIdentity;

  IdentityState copyWith({
    double? disciplineIdentity,
    double? focusIdentity,
    double? growthIdentity,
  }) => IdentityState(
    disciplineIdentity: disciplineIdentity ?? this.disciplineIdentity,
    focusIdentity: focusIdentity ?? this.focusIdentity,
    growthIdentity: growthIdentity ?? this.growthIdentity,
  );
}

class IdentityEngine {
  const IdentityEngine();

  IdentityState update({
    required IdentityState current,
    required bool sessionCompleted,
    required bool taskCompleted,
    required bool streakMaintained,
  }) {
    return IdentityState(
      disciplineIdentity:
          (current.disciplineIdentity + (taskCompleted ? 0.02 : -0.01)).clamp(
            0.0,
            1.0,
          ),
      focusIdentity: (current.focusIdentity + (sessionCompleted ? 0.03 : -0.01))
          .clamp(0.0, 1.0),
      growthIdentity: (current.growthIdentity + (streakMaintained ? 0.02 : 0.0))
          .clamp(0.0, 1.0),
    );
  }

  String reinforceIdentity(IdentityState state, String baseMessage) {
    if (state.disciplineIdentity > 0.7) {
      return 'You are someone who follows through. $baseMessage';
    }
    if (state.focusIdentity > 0.7) {
      return 'Deep focus is becoming your default. $baseMessage';
    }
    if (state.growthIdentity > 0.7) {
      return 'You are building something real. $baseMessage';
    }
    return baseMessage;
  }
}
