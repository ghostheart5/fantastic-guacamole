// lib/engine/si/prediction_engine.dart

import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';

class PredictionConfig {
  const PredictionConfig({
    this.neutralProbability = 0.5,
    this.minReliableSamples = 3,
    this.highThreshold = 0.75,
    this.manageableThreshold = 0.55,
    this.lowThreshold = 0.35,
  });

  final double neutralProbability;
  final int minReliableSamples;
  final double highThreshold;
  final double manageableThreshold;
  final double lowThreshold;
}

class PredictionEngine {
  const PredictionEngine({this.config = const PredictionConfig()});

  final PredictionConfig config;

  Prediction predict({
    required List<NeuralEntry> history,
    required String task,
  }) {
    final String normalizedTask = _normalize(task);
    final double neutral = siClamp01(config.neutralProbability);

    if (normalizedTask.isEmpty) {
      return Prediction(
        outcome: 'Unknown outcome',
        probability: neutral,
        confidence: 0.2,
        sampleSize: 0,
        explanation: 'No task was provided.',
        signals: const <String>['missing_task'],
      );
    }

    if (history.isEmpty) {
      return Prediction(
        outcome: 'Unknown outcome',
        probability: neutral,
        confidence: 0.25,
        sampleSize: 0,
        explanation: 'Not enough data yet.',
        signals: const <String>['empty_history'],
      );
    }

    final List<double> qualities = history
        .where((NeuralEntry e) => _normalize(e.task) == normalizedTask)
        .map((NeuralEntry e) => e.quality)
        .where((double q) => q.isFinite)
        .map((double q) => q.clamp(0.0, 1.0).toDouble())
        .toList(growable: false);

    if (qualities.isEmpty) {
      return Prediction(
        outcome: 'No past data for this task',
        probability: neutral,
        confidence: 0.3,
        sampleSize: 0,
        explanation: 'First time attempting this task.',
        signals: const <String>['no_matching_history'],
      );
    }

    final double avgQuality =
        qualities.fold<double>(0, (double s, double q) => s + q) /
        qualities.length;

    final double sampleConfidence =
        (qualities.length / config.minReliableSamples)
            .clamp(0.0, 1.0)
            .toDouble();

    final double probability =
        ((neutral * (1 - sampleConfidence)) + (avgQuality * sampleConfidence))
            .clamp(0.0, 1.0)
            .toDouble();

    return Prediction(
      outcome: _outcome(probability, qualities.length),
      probability: probability,
      confidence: sampleConfidence,
      sampleSize: qualities.length,
      explanation:
          'Based on ${qualities.length} matching session(s). Confidence is ${_confidenceLabel(sampleConfidence)}.',
      signals: <String>[
        'avg_quality:${avgQuality.toStringAsFixed(2)}',
        'samples:${qualities.length}',
      ],
    );
  }

  Prediction blend(List<Prediction> predictions) {
    final List<Prediction> valid = predictions
        .where(
          (Prediction p) => p.probability.isFinite && p.confidence.isFinite,
        )
        .toList(growable: false);

    if (valid.isEmpty) {
      return Prediction(
        outcome: 'Unknown outcome',
        probability: siClamp01(config.neutralProbability),
        confidence: 0.2,
        explanation: 'No valid prediction signals were available.',
      );
    }

    final double weightTotal = valid.fold<double>(
      0,
      (double sum, Prediction p) => sum + p.safeConfidence,
    );

    if (weightTotal <= 0) {
      return valid.first.copyWith(confidence: 0.25);
    }

    final double probability =
        valid.fold<double>(
          0,
          (double sum, Prediction p) =>
              sum + (p.safeProbability * p.safeConfidence),
        ) /
        weightTotal;

    final int samples = valid.fold<int>(
      0,
      (int sum, Prediction p) => sum + p.sampleSize,
    );

    return Prediction(
      outcome: _outcome(probability, samples),
      probability: probability,
      confidence: (weightTotal / valid.length).clamp(0.0, 1.0).toDouble(),
      sampleSize: samples,
      explanation: 'Blended ${valid.length} prediction signal(s).',
      signals: valid.expand((Prediction p) => p.signals).toList(),
    );
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _outcome(double probability, int samples) {
    if (samples < config.minReliableSamples) {
      return 'Early signal — more history needed';
    }
    if (probability >= config.highThreshold) {
      return 'High chance of successful focus';
    }
    if (probability >= config.manageableThreshold) {
      return 'Likely manageable';
    }
    if (probability >= config.lowThreshold) {
      return 'Moderate difficulty expected';
    }
    return 'Low focus success predicted';
  }

  String _confidenceLabel(double value) {
    if (value >= 0.85) return 'high';
    if (value >= 0.5) return 'medium';
    return 'low';
  }
}
