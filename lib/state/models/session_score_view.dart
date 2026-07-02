import 'package:fantastic_guacamole/engine/scoring/session_score.dart';

class SessionScoreView {
  const SessionScoreView({
    required this.xp,
    required this.quality,
    required this.feedback,
  });

  final int xp;
  final double quality;
  final String feedback;

  factory SessionScoreView.fromScore(SessionScore score) {
    return SessionScoreView(
      xp: score.xp,
      quality: score.quality,
      feedback: score.feedback,
    );
  }
}
