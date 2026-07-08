// lib/engine/si/si_adaptive_learning.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

class AdaptiveLearningWeights {
  const AdaptiveLearningWeights({
    this.momentum = 0.5,
    this.resistance = 0.5,
    this.fatigueSensitivity = 0.5,
    this.focusReadiness = 0.5,
    this.outputLoadModifier = 0.5,
  });

  final double momentum;
  final double resistance;
  final double fatigueSensitivity;
  final double focusReadiness;
  final double outputLoadModifier;

  AdaptiveLearningWeights copyWith({
    double? momentum,
    double? resistance,
    double? fatigueSensitivity,
    double? focusReadiness,
    double? outputLoadModifier,
  }) {
    return AdaptiveLearningWeights(
      momentum: siClamp01(momentum ?? this.momentum),
      resistance: siClamp01(resistance ?? this.resistance),
      fatigueSensitivity: siClamp01(
        fatigueSensitivity ?? this.fatigueSensitivity,
      ),
      focusReadiness: siClamp01(focusReadiness ?? this.focusReadiness),
      outputLoadModifier: siClamp01(
        outputLoadModifier ?? this.outputLoadModifier,
      ),
    );
  }

  Map<String, double> toPredictionBiases() => <String, double>{
    'momentum_bias': siClamp01(momentum),
    'resistance_bias': siClamp01(resistance),
    'fatigue_bias': siClamp01(fatigueSensitivity),
    'focus_bias': siClamp01(focusReadiness),
    'output_load_modifier': siClamp01(outputLoadModifier),
  };
}

class AdaptiveLearningUpdate {
  const AdaptiveLearningUpdate({
    required this.weights,
    required this.memory,
    required this.recommendations,
    required this.predictionSignals,
  });

  final AdaptiveLearningWeights weights;
  final SIMemoryStore memory;
  final List<String> recommendations;
  final Map<String, double> predictionSignals;
}

class SIAdaptiveLearning {
  const SIAdaptiveLearning();

  AdaptiveLearningUpdate update({
    required SIContext context,
    required SIMemoryStore memory,
    required MicroPatternReport patterns,
    AdaptiveLearningWeights previous = const AdaptiveLearningWeights(),
    SIDecision? decision,
    SIResponse? response,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    double momentum = previous.momentum;
    double resistance = previous.resistance;
    double fatigue = previous.fatigueSensitivity;
    double focus = previous.focusReadiness;
    double loadModifier = previous.outputLoadModifier;

    for (final MicroPattern p in patterns.patterns) {
      switch (p.type) {
        case MicroPatternType.completionMomentum:
          momentum = _blend(momentum, p.strength, 0.35);
          break;
        case MicroPatternType.skipResistance:
          resistance = _blend(resistance, p.strength, 0.35);
          break;
        case MicroPatternType.fatigueDrift:
        case MicroPatternType.highLoadLoop:
          fatigue = _blend(fatigue, p.strength, 0.35);
          loadModifier = _blend(loadModifier, 1 - p.strength, 0.3);
          break;
        case MicroPatternType.stableFocus:
          focus = _blend(focus, p.strength, 0.35);
          loadModifier = _blend(loadModifier, p.strength, 0.2);
          break;
        case MicroPatternType.taskAffinity:
        case MicroPatternType.repeatedTopic:
          break;
      }
    }

    if (decision != null) {
      momentum = _blend(
        momentum,
        decision.safe ? decision.confidence : 0.25,
        0.2,
      );
    }

    final AdaptiveLearningWeights next = previous.copyWith(
      momentum: momentum,
      resistance: resistance,
      fatigueSensitivity: fatigue,
      focusReadiness: focus,
      outputLoadModifier: loadModifier,
    );

    final List<String> recommendations = _recommendations(next, context);

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'adaptive_learning|momentum=${next.momentum.toStringAsFixed(2)}|resistance=${next.resistance.toStringAsFixed(2)}|fatigue=${next.fatigueSensitivity.toStringAsFixed(2)}|focus=${next.focusReadiness.toStringAsFixed(2)}',
            timestamp: timestamp,
            relevance: 0.75,
            recency: 1.0,
            confidence: 0.72,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: next.momentum >= 0.65 ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    final Map<String, double> signals = <String, double>{
      ...next.toPredictionBiases(),
      ...patterns.predictionSignals,
    };

    return AdaptiveLearningUpdate(
      weights: next,
      memory: nextMemory,
      recommendations: List<String>.unmodifiable(recommendations),
      predictionSignals: Map<String, double>.unmodifiable(signals),
    );
  }

  double predictionBiasForTask({
    required String taskKey,
    required AdaptiveLearningWeights weights,
    required MicroPatternReport patterns,
  }) {
    final String key = siClean(taskKey).toLowerCase();
    final double affinity = patterns.predictionSignals['task:$key'] ?? 0.5;
    final double bias =
        (weights.focusReadiness * 0.35) +
        (weights.momentum * 0.25) +
        ((1 - weights.resistance) * 0.2) +
        (affinity * 0.2);
    return siClamp01(bias);
  }

  double _blend(double oldValue, double newValue, double rate) {
    return siClamp01(oldValue * (1 - rate) + siClamp01(newValue) * rate);
  }

  List<String> _recommendations(AdaptiveLearningWeights w, SIContext context) {
    final List<String> out = <String>[];

    if (w.fatigueSensitivity >= 0.65 || context.userState.fatigue >= 0.65) {
      out.add('Reduce output load and recommend smaller focus blocks.');
    }
    if (w.resistance >= 0.65) {
      out.add('Reframe skipped work as a smaller next action.');
    }
    if (w.momentum >= 0.65 && w.focusReadiness >= 0.6) {
      out.add('Prioritize action-oriented recommendations.');
    }
    if (out.isEmpty) {
      out.add('Keep guidance steady and continue collecting behavior signals.');
    }

    return out;
  }
}
