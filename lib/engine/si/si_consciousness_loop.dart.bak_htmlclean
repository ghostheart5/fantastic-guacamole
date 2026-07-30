// lib/engine/si/si_consciousness_loop.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_ethics_layer.dart';

class ConsciousnessIteration {
  const ConsciousnessIteration({
    required this.index,
    required this.message,
    required this.score,
    required this.reason,
  });

  final int index;
  final String message;
  final double score;
  final String reason;
}

class ConsciousnessLoopResult {
  const ConsciousnessLoopResult({
    required this.iterations,
    required this.finalMessage,
    required this.finalScore,
    required this.stable,
  });

  final List<ConsciousnessIteration> iterations;
  final String finalMessage;
  final double finalScore;
  final bool stable;
}

class SIConsciousnessLoop {
  const SIConsciousnessLoop({this.ethicsLayer = const SIEthicsLayer()});

  final SIEthicsLayer ethicsLayer;

  ConsciousnessLoopResult run({
    required String message,
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIDecision? decision,
    int maxIterations = 3,
  }) {
    String current = siClean(message, fallback: 'Choose one small next step.');
    final List<ConsciousnessIteration> iterations = <ConsciousnessIteration>[];

    for (int i = 0; i < maxIterations.clamp(1, 6); i++) {
      final EthicsLayerReport ethics = ethicsLayer.enforce(
        message: current,
        context: context,
        intent: intent,
        instinct: instinct,
        decision: decision,
      );

      current = ethics.adjustedMessage;
      final double score = siClamp01(
        ethics.score - (current.length > 420 ? 0.12 : 0),
      );

      iterations.add(
        ConsciousnessIteration(
          index: i,
          message: current,
          score: score,
          reason: ethics.recommendation,
        ),
      );

      if (score >= 0.82 && !ethics.blocked) break;
    }

    final ConsciousnessIteration last = iterations.last;
    return ConsciousnessLoopResult(
      iterations: List<ConsciousnessIteration>.unmodifiable(iterations),
      finalMessage: last.message,
      finalScore: last.score,
      stable: last.score >= 0.72,
    );
  }
}
