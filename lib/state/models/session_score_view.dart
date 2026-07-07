import 'package:fantastic_guacamole/engine/scoring/session_score.dart';

class SessionScoreView {
  const SessionScoreView({
    required this.xp,
    required this.quality,
    required this.feedback,
    this.durationSeconds = 0,
    this.taskTitle,
  });

  final int xp;
  final double quality;
  final String feedback;
  final int durationSeconds;
  final String? taskTitle;

  factory SessionScoreView.fromScore(
    SessionScore score, {
    int durationSeconds = 0,
    String? taskTitle,
  }) {
    return SessionScoreView(
      xp: score.xp,
      quality: score.quality,
      feedback: score.feedback,
      durationSeconds: durationSeconds,
      taskTitle: taskTitle,
    );
  }
}
