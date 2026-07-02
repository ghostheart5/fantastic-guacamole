class GoalContinuity {
  const GoalContinuity({
    required this.activeGoals,
    required this.linkedGoal,
    required this.progressHint,
  });

  final List<String> activeGoals;
  final String? linkedGoal;
  final String progressHint;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'active_goals': activeGoals,
      'linked_goal': linkedGoal,
      'progress_hint': progressHint,
    };
  }
}

class GoalContinuityEngine {
  const GoalContinuityEngine();

  GoalContinuity evaluate({
    required List<String> knownGoals,
    required String input,
    required String intent,
  }) {
    final String lowered = input.toLowerCase();
    String? linked;
    for (final String goal in knownGoals) {
      if (lowered.contains(goal.toLowerCase())) {
        linked = goal;
        break;
      }
    }
    linked ??= knownGoals.isEmpty ? null : knownGoals.first;

    final String hint = linked == null
        ? 'No long-term goal linked yet. Capture one to track continuity.'
        : 'Tie this $intent action to goal "$linked" and log progress.';

    return GoalContinuity(
      activeGoals: knownGoals,
      linkedGoal: linked,
      progressHint: hint,
    );
  }
}
