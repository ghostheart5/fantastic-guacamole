class UserNarrative {
  const UserNarrative({required this.summary, required this.trajectory});
  final String summary;
  final String trajectory;
}

class NarrativeEngine {
  const NarrativeEngine();

  UserNarrative generate({
    required int streak,
    required int completedTasks,
    required double consistency,
  }) {
    return UserNarrative(
      summary: _summary(streak, completedTasks),
      trajectory: _trajectory(consistency),
    );
  }

  String _summary(int streak, int tasks) {
    if (streak >= 7 && tasks >= 20) return 'You are building real discipline.';
    if (streak >= 3) return 'You are building momentum. Keep going.';
    if (tasks >= 5) return 'You have completed $tasks tasks. Making progress.';
    return 'Getting started. Every action counts.';
  }

  String _trajectory(double consistency) {
    if (consistency >= 0.8) return 'On track to hit your goals this week.';
    if (consistency >= 0.5) {
      return 'Slightly inconsistent — small sessions still count.';
    }
    return 'Rebuilding the habit. Start with just one session today.';
  }
}
