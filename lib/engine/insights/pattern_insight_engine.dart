import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';

class PatternInsightEngine {
  String generate(List<NeuralEntry> history) {
    if (history.isEmpty) return 'No data yet.';

    final int avgDuration =
        history
            .map((NeuralEntry e) => e.duration)
            .reduce((int a, int b) => a + b) ~/
        history.length;

    final double avgQuality =
        history
            .map((NeuralEntry e) => e.quality)
            .reduce((double a, double b) => a + b) /
        history.length;

    if (avgDuration < 60) {
      return 'Your sessions are short. Try increasing duration.';
    }

    if (avgQuality > 0.7) {
      return 'You perform best with your current rhythm.';
    }

    return 'Consistency is improving. Keep going.';
  }
}
