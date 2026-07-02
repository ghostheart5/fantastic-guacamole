import 'package:fantastic_guacamole/engine/scoring/session_score.dart';

class SessionScoringEngine {
  SessionScore calculate({
    required int seconds,
    required double energy,
    required int taskPriority,
  }) {
    final int baseXp = (seconds ~/ 60).clamp(1, 60);
    final int priorityBonus = taskPriority * 4;
    final int energyBonus = (energy * 12).round();
    final int xp = baseXp + priorityBonus + energyBonus;

    final double quality = (seconds / 300).clamp(0.0, 1.0);

    final String feedback;
    if (quality >= 0.8) {
      feedback = 'Excellent session — peak performance.';
    } else if (quality >= 0.5) {
      feedback = 'Solid effort — keep building momentum.';
    } else if (quality >= 0.25) {
      feedback = 'Good start — push a bit further next time.';
    } else {
      feedback = 'Short session — every rep counts.';
    }

    return SessionScore(xp: xp, quality: quality, feedback: feedback);
  }
}
