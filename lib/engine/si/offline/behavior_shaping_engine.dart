// Behavior Shaping Engine — progressive micro-progression
// Session length ladder: 10→12→15→18→22→30 min
// Tracks consistency, capacity, and stability across sessions.

class BehaviorState {
  const BehaviorState({
    required this.consistency,
    required this.capacity,
    required this.stability,
  });

  final double consistency; // 0.0–1.0
  final double capacity;
  final double stability;

  BehaviorState copyWith({
    double? consistency,
    double? capacity,
    double? stability,
  }) => BehaviorState(
    consistency: consistency ?? this.consistency,
    capacity: capacity ?? this.capacity,
    stability: stability ?? this.stability,
  );
}

class BehaviorTarget {
  const BehaviorTarget({
    required this.targetDifficulty,
    required this.targetSessionLength,
  });

  final double targetDifficulty; // 1.0–5.0
  final int targetSessionLength; // minutes
}

class BehaviorShapingEngine {
  const BehaviorShapingEngine();

  static const List<int> _ladder = <int>[10, 12, 15, 18, 22, 30];

  BehaviorState update({
    required BehaviorState current,
    required bool sessionCompleted,
    required bool taskCompleted,
    required double frictionScore,
  }) {
    return BehaviorState(
      consistency: (current.consistency + (sessionCompleted ? 0.05 : -0.03))
          .clamp(0.0, 1.0),
      capacity: (current.capacity + (taskCompleted ? 0.03 : -0.02))
          .clamp(0.0, 1.0),
      stability: (current.stability + (frictionScore < 0.4 ? 0.02 : -0.04))
          .clamp(0.0, 1.0),
    );
  }

  BehaviorTarget generateTarget(BehaviorState state) {
    final double avg =
        (state.consistency + state.capacity + state.stability) / 3.0;
    final int index =
        (avg * (_ladder.length - 1)).round().clamp(0, _ladder.length - 1);
    return BehaviorTarget(
      targetDifficulty: (avg * 4.0 + 1.0).clamp(1.0, 5.0),
      targetSessionLength: _ladder[index],
    );
  }

  int adjustSession(int current, BehaviorState state) {
    final int target = generateTarget(state).targetSessionLength;
    return current < target ? target : current.clamp(target, 60);
  }
}
