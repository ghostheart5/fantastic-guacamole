import 'package:fantastic_guacamole/engine/scoring/completion_score.dart';

class CompletionScoreView {
  const CompletionScoreView({
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

  factory CompletionScoreView.fromScore(
    CompletionScore score, {
    int durationSeconds = 0,
    String? taskTitle,
  }) {
    return CompletionScoreView(
      xp: score.xp,
      quality: score.quality,
      feedback: score.feedback,
      durationSeconds: durationSeconds,
      taskTitle: taskTitle,
    );
  }
}
