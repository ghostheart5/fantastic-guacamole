import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final predictionProvider = FutureProvider.family<Prediction, String>((
  ref,
  String taskTitle,
) async {
  final secureStore = ref.read(secureStoreProvider);
  final String? raw = await secureStore.readString('neural_dump');

  List<NeuralEntry> history;
  if (raw == null || raw.trim().isEmpty) {
    history = <NeuralEntry>[];
  } else {
    try {
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      history = data
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => NeuralEntry.fromJson(e))
          .toList();
    } catch (_) {
      history = <NeuralEntry>[];
    }
  }

  if (history.isEmpty) {
    return const Prediction(
      outcome: 'Unknown',
      probability: 0.5,
      confidence: 0.35,
      sampleSize: 0,
      explanation: 'No prior execution history is available for this task yet.',
      signals: <String>['cold-start'],
    );
  }

  final List<NeuralEntry> matching = history
      .where(
        (NeuralEntry entry) =>
            entry.task.trim().toLowerCase() == taskTitle.trim().toLowerCase(),
      )
      .toList(growable: false);
  final List<NeuralEntry> sample = matching.isEmpty ? history : matching;

  final double meanQuality =
      sample
          .map((NeuralEntry entry) => entry.quality.clamp(0.0, 1.0))
          .fold<double>(0, (double a, double b) => a + b) /
      sample.length;
  final double meanConfidence =
      sample
          .map((NeuralEntry entry) => entry.confidence.clamp(0.0, 1.0))
          .fold<double>(0, (double a, double b) => a + b) /
      sample.length;
  final double probability =
      (((meanQuality * 0.65) + (meanConfidence * 0.35)) as num)
          .toDouble()
          .clamp(0.0, 1.0);

  return Prediction(
    outcome: probability >= 0.6 ? 'Likely Success' : 'Risk of Failure',
    probability: probability,
    confidence: meanConfidence,
    sampleSize: sample.length,
    explanation: matching.isEmpty
        ? 'Prediction is based on global history because this task has no exact history match.'
        : 'Prediction is based on previous runs of this specific task.',
    signals: <String>[
      'mean-quality:${meanQuality.toStringAsFixed(2)}',
      'mean-confidence:${meanConfidence.toStringAsFixed(2)}',
      'sample:${sample.length}',
    ],
  );
});
