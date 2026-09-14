class UserNarrative {
  const UserNarrative({
    required this.summary,
    required this.trajectory,
    this.spanishSummary = '',
  });
  final String summary;
  final String spanishSummary;
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
      spanishSummary: _summary(streak, completedTasks, spanish: true),
      trajectory: _trajectory(consistency),
    );
  }

  String _summary(int streak, int tasks, {bool spanish = false}) {
    if (streak >= 7 && tasks >= 20) {
      return spanish
          ? 'Estás desarrollando una disciplina sólida.'
          : 'You are building real discipline.';
    }
    if (streak >= 3) {
      return spanish
          ? 'Estás generando impulso. Sigue adelante.'
          : 'You are building momentum. Keep going.';
    }
    if (tasks >= 5) {
      return spanish
          ? 'Has completado $tasks tareas. Estás avanzando.'
          : 'You have completed $tasks tasks. Making progress.';
    }
    return spanish
        ? 'Estás comenzando. Cada acción cuenta.'
        : 'Getting started. Every action counts.';
  }

  String _trajectory(double consistency) {
    if (consistency >= 0.8) return 'On track to hit your goals this week.';
    if (consistency >= 0.5) {
      return 'Slightly inconsistent — small efforts still count.';
    }
    return 'Rebuilding the habit. Start with one small effort today.';
  }
}
