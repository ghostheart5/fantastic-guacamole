// Friction Engine — behavioral resistance scoring
// Measures: skip rate, session drop-offs, avg focus time
// Feedback deltas: complete −0.1 | skip +0.15 | session_complete −0.2

class FrictionSignal {
  const FrictionSignal({
    required this.score,
    required this.isHigh,
    required this.triggers,
  });

  final double score;
  final bool isHigh;
  final List<String> triggers;
}

class FrictionEngine {
  const FrictionEngine();

  FrictionSignal evaluate({
    required int tasksSkipped,
    required int tasksCompleted,
    required int sessionDropOffs,
    required double avgFocusTime,
  }) {
    final int total = tasksSkipped + tasksCompleted;
    final double skipRatio = total == 0 ? 0.0 : tasksSkipped / total;
    final double dropPenalty = (sessionDropOffs * 0.1).clamp(0.0, 0.4);
    final double focusPenalty =
        avgFocusTime < 10 ? 0.3 : (avgFocusTime < 20 ? 0.15 : 0.0);

    final double score =
        (skipRatio * 0.5 + dropPenalty + focusPenalty).clamp(0.0, 1.0);

    final List<String> triggers = <String>[];
    if (skipRatio > 0.5) triggers.add('high_skip_rate');
    if (sessionDropOffs > 2) triggers.add('frequent_dropoffs');
    if (avgFocusTime < 10) triggers.add('low_focus_duration');

    return FrictionSignal(score: score, isHigh: score > 0.6, triggers: triggers);
  }

  double onTaskComplete(double current) => (current - 0.1).clamp(0.0, 1.0);
  double onTaskSkip(double current) => (current + 0.15).clamp(0.0, 1.0);
  double onSessionComplete(double current) => (current - 0.2).clamp(0.0, 1.0);
}
