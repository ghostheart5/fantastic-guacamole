import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/engine/si/prediction_engine.dart';
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

  return const PredictionEngine().predict(history: history, task: taskTitle);
});
