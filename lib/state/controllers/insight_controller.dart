import 'package:fantastic_guacamole/engine/insights/insight_engine.dart';
import 'package:fantastic_guacamole/engine/insights/pattern_insight_engine.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/completion_insight_view.dart';
import 'package:fantastic_guacamole/state/providers/neural_history_provider.dart';
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
  final PatternInsightEngine engine = ref.read(patternInsightEngineProvider);
  final List<NeuralEntry> history = await ref
      .watch(neuralHistoryStoreProvider)
      .loadNeuralHistory();
  return engine.generate(history);
});
