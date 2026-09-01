// Identity Engine — language-based identity reinforcement
// Tracks discipline, attention, and growth identity dimensions (0.0–1.0).
// Wraps SI responses with identity-affirming language when thresholds are met.

class IdentityState {
  const IdentityState({
    required this.disciplineIdentity,
    required this.executionIdentity,
    required this.growthIdentity,
  });

  final double disciplineIdentity; // 0.0–1.0
  final double executionIdentity;
  final double growthIdentity;

  bool get hasMeaningfulEvidence {
    final List<double> scores = <double>[
      disciplineIdentity,
      executionIdentity,
      growthIdentity,
    ]..sort();
    return scores.last >= .16 && scores.last - scores.first >= .02;
  }

  IdentityState copyWith({
    double? disciplineIdentity,
    double? executionIdentity,
    double? growthIdentity,
  }) => IdentityState(
    disciplineIdentity: disciplineIdentity ?? this.disciplineIdentity,
    executionIdentity: executionIdentity ?? this.executionIdentity,
    growthIdentity: growthIdentity ?? this.growthIdentity,
  );
}

class IdentityEngine {
  const IdentityEngine();

  IdentityState update({
    required IdentityState current,
    required bool completionRecorded,
    required bool taskCompleted,
    required bool streakMaintained,
  }) {
    return IdentityState(
      disciplineIdentity:
          (current.disciplineIdentity + (taskCompleted ? 0.02 : -0.01)).clamp(
            0.0,
            1.0,
          ),
      executionIdentity:
          (current.executionIdentity + (completionRecorded ? 0.03 : -0.01))
              .clamp(0.0, 1.0),
      growthIdentity: (current.growthIdentity + (streakMaintained ? 0.02 : 0.0))
          .clamp(0.0, 1.0),
    );
  }

  String reinforceIdentity(IdentityState state, String baseMessage) {
    if (state.disciplineIdentity > 0.7) {
      return 'You are someone who follows through. $baseMessage';
    }
    if (state.executionIdentity > 0.7) {
      return 'Sustained attention is becoming your default. $baseMessage';
    }
    if (state.growthIdentity > 0.7) {
      return 'You are building something real. $baseMessage';
    }
    return baseMessage;
  }
}
