import 'dart:convert';

import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/engine/si/prediction_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final predictionEngineProvider = Provider<PredictionEngine>((ref) {
  return PredictionEngine();
});

final predictionProvider = FutureProvider.family<Prediction, String>((
  ref,
  String taskTitle,
) async {
  final prefs = ref.read(sharedPrefsStoreProvider);
  await prefs.init();
  final String? raw = prefs.load('neural_dump');

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

  return ref
      .read(predictionEngineProvider)
      .predict(history: history, task: taskTitle);
});
