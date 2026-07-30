// lib/engine/si/si_cognitive_hyper_context_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class HyperContextSignal {
  const HyperContextSignal({
    required this.key,
    required this.value,
    required this.weight,
  });

  final String key;
  final String value;
  final double weight;
}

class HyperContextFrame {
  const HyperContextFrame({
    required this.signals,
    required this.center,
    required this.contextDensity,
    required this.guidance,
  });

  final List<HyperContextSignal> signals;
  final String center;
  final double contextDensity;
  final String guidance;
}

class SICognitiveHyperContextEngine {
  const SICognitiveHyperContextEngine();

  HyperContextFrame build({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIMemoryStore memory = const SIMemoryStore(),
  }) {
    final List<HyperContextSignal> signals =
        <HyperContextSignal>[
          HyperContextSignal(
            key: 'text',
            value: siClean(context.input.text),
            weight: 0.55,
          ),
          HyperContextSignal(
            key: 'intent',
            value: intent.primary.label,
            weight: intent.confidence,
          ),
          HyperContextSignal(
            key: 'mood',
            value: context.userState.emotion,
            weight: _stateWeight(context),
          ),
          HyperContextSignal(
            key: 'instinct',
            value: instinct.primaryInstinct,
            weight: instinct.safetyFirst ? 0.9 : 0.55,
          ),
          HyperContextSignal(
            key: 'history',
            value: '${context.input.history.length}',
            weight: siClamp01(context.input.history.length / 8),
          ),
          HyperContextSignal(
            key: 'memory',
            value: '${memory.tiered.shortTerm.length}',
            weight: siClamp01(memory.tiered.shortTerm.length / 10),
          ),
        ]..sort(
          (HyperContextSignal a, HyperContextSignal b) =>
              b.weight.compareTo(a.weight),
        );

    final double density = siClamp01(
      signals.fold<double>(
            0,
            (double s, HyperContextSignal x) => s + x.weight,
          ) /
          signals.length,
    );
    final String center = signals.first.key;

    return HyperContextFrame(
      signals: List<HyperContextSignal>.unmodifiable(signals),
      center: center,
      contextDensity: density,
      guidance: instinct.avoidOverwhelm || density > 0.75
          ? 'Use only the strongest context signals.'
          : 'Use current context plus recent memory.',
    );
  }

  double _stateWeight(SIContext context) {
    final SIUserState u = context.userState;
    return siClamp01(
      (u.stress + u.cognitiveLoad + u.motivation + u.engagement) / 4,
    );
  }
}
