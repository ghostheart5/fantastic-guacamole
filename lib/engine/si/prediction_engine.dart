import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';

class PredictionEngine {
  Prediction predict({
    required List<NeuralEntry> history,
    required String task,
  }) {
    if (history.isEmpty) {
      return Prediction(
        outcome: 'Unknown outcome',
        probability: 0.5,
        explanation: 'Not enough data yet.',
      );
    }

    final List<NeuralEntry> matches = history
        .where((NeuralEntry e) => e.task == task)
        .toList();

    if (matches.isEmpty) {
      return Prediction(
        outcome: 'No past data for this task',
        probability: 0.5,
        explanation: 'First time attempting this.',
      );
    }

    final double avgQuality =
        matches
            .map((NeuralEntry e) => e.quality)
            .reduce((double a, double b) => a + b) /
        matches.length;

    final double probability = avgQuality.clamp(0.0, 1.0);

    return Prediction(
      outcome: avgQuality > 0.7
          ? 'High chance of successful focus'
          : 'Moderate difficulty expected',
      probability: probability,
      explanation: 'Based on previous sessions with this task.',
    );
  }
}
