import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/engine/insights/insight_engine.dart';
import 'package:fantastic_guacamole/engine/insights/pattern_insight_engine.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/completion_insight_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final completionInsightEngineProvider = Provider<CompletionInsightEngine>((
  ref,
) {
  return CompletionInsightEngine();
});

final patternInsightEngineProvider = Provider<PatternInsightEngine>((ref) {
  return PatternInsightEngine();
});

final completionInsightProvider = Provider<CompletionInsightView?>((ref) {
  final score = ref.watch(sessionScoreProvider);
  final energy = ref.watch(energyProvider);

  if (score == null) return null;

  final CompletionInsightEngine engine = ref.read(
    completionInsightEngineProvider,
  );
  return CompletionInsightView.fromInsight(
    engine.generate(seconds: score.durationSeconds, energy: energy),
  );
});

final patternInsightProvider = FutureProvider<String>((ref) async {
  final storage = ref.read(secureStoreProvider);
  final PatternInsightEngine engine = ref.read(patternInsightEngineProvider);
  final String? raw = await storage.readString('neural_dump');

  if (raw == null || raw.trim().isEmpty) {
    return engine.generate(const <NeuralEntry>[]);
  }

  try {
    final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
    final List<NeuralEntry> history = data
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => NeuralEntry.fromJson(e))
        .toList();
    return engine.generate(history);
  } catch (_) {
    return 'No data yet.';
  }
});
