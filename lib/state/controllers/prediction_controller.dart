import 'dart:convert';

import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final predictionProvider = FutureProvider.family<Prediction, String>((
  ref,
  String taskTitle,
) async {
  final secureStore = ref.watch(accountSecureStoreProvider);
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

  return buildObservedFollowThroughPrediction(
    history: history,
    taskTitle: taskTitle,
  );
});

Prediction buildObservedFollowThroughPrediction({
  required List<NeuralEntry> history,
  required String taskTitle,
}) {
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

  final int completed = sample
      .where((NeuralEntry entry) => entry.observedCompleted)
      .length;
  final int skipped = sample.length - completed;
  // Beta(1, 1) smoothing avoids absolute 0% or 100% claims from a tiny
  // ledger. This is an observed follow-through estimate, not an ML forecast.
  final double probability = (completed + 1) / (sample.length + 2);
  final double evidenceStrength = (sample.length / 10).clamp(0.0, 1.0);
  final String outcome = probability >= .7
      ? 'Higher observed follow-through'
      : probability <= .4
      ? 'Lower observed follow-through'
      : 'Mixed observed follow-through';

  return Prediction(
    outcome: outcome,
    probability: probability,
    confidence: evidenceStrength,
    sampleSize: sample.length,
    explanation: matching.isEmpty
        ? 'No exact task history exists, so this estimate uses all recorded completed and skipped task outcomes.'
        : 'This estimate uses recorded completed and skipped outcomes for this task title.',
    signals: <String>[
      'completed:$completed',
      'skipped:$skipped',
      'sample:${sample.length}',
    ],
  );
}
