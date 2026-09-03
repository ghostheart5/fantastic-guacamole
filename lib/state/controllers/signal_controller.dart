import 'dart:convert';

import 'package:fantastic_guacamole/engine/signals/signal_engine.dart';
import 'package:fantastic_guacamole/engine/signals/pattern_signal_engine.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/completion_signal_view.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final completionSignalEngineProvider = Provider<CompletionSignalEngine>((ref) {
  return CompletionSignalEngine();
});

final patternSignalEngineProvider = Provider<PatternSignalEngine>((ref) {
  return PatternSignalEngine();
});

final completionSignalProvider = Provider<CompletionSignalView?>((ref) {
  final score = ref.watch(completionScoreProvider);
  final energy = ref.watch(energyProvider);

  if (score == null) return null;

  final CompletionSignalEngine engine = ref.read(
    completionSignalEngineProvider,
  );
  return CompletionSignalView.fromSignal(
    engine.generate(seconds: score.durationSeconds, energy: energy),
  );
});

final patternSignalProvider = FutureProvider<String>((ref) async {
  final storage = ref.watch(accountSecureStoreProvider);
  final PatternSignalEngine engine = ref.read(patternSignalEngineProvider);
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
