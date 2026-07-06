// lib/engine/si/si_contextual_gravity.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_resonance_engine.dart';

class GravitySignal {
  const GravitySignal({
    required this.key,
    required this.weight,
    required this.reason,
  });

  final String key;
  final double weight;
  final String reason;
}

class ContextualGravityField {
  const ContextualGravityField({
    required this.signals,
    required this.center,
    required this.totalWeight,
    required this.guidance,
  });

  final List<GravitySignal> signals;
  final String center;
  final double totalWeight;
  final String guidance;
}

class SIContextualGravity {
  const SIContextualGravity();

  ContextualGravityField calculate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    ResonanceProfile? resonance,
    SIMemoryStore memory = const SIMemoryStore(),
  }) {
    final List<GravitySignal> signals = <GravitySignal>[
      GravitySignal(
        key: 'intent:${intent.primary.label}',
        weight: intent.confidence,
        reason: 'Current user intent.',
      ),
      GravitySignal(
        key: 'emotion:${context.userState.emotion}',
        weight: _emotionWeight(context),
        reason: 'Current emotional/cognitive state.',
      ),
      GravitySignal(
        key: 'instinct:${instinct.primaryInstinct}',
        weight: instinct.safetyFirst ? 0.9 : 0.55,
        reason: 'Hard behavioral constraint.',
      ),
    ];

    if (patterns != null) {
      for (final MicroPattern pattern in patterns.patterns.take(5)) {
        signals.add(
          GravitySignal(
            key: 'pattern:${pattern.type.name}',
            weight: pattern.strength,
            reason: pattern.label,
          ),
        );
      }
    }

    if (learning != null) {
      signals.addAll(<GravitySignal>[
        GravitySignal(
          key: 'learning:momentum',
          weight: learning.momentum,
          reason: 'Adaptive momentum.',
        ),
        GravitySignal(
          key: 'learning:resistance',
          weight: learning.resistance,
          reason: 'Adaptive resistance.',
        ),
        GravitySignal(
          key: 'learning:focus',
          weight: learning.focusReadiness,
          reason: 'Focus readiness.',
        ),
      ]);
    }

    if (resonance != null) {
      signals.add(
        GravitySignal(
          key: 'resonance:${resonance.stateLabel}',
          weight: resonance.alignmentScore,
          reason: resonance.guidance,
        ),
      );
    }

    final int recentMemory = memory.tiered.shortTerm.length;
    if (recentMemory > 0) {
      signals.add(
        GravitySignal(
          key: 'memory:recent',
          weight: siClamp01(recentMemory / 10),
          reason: 'Recent memory context available.',
        ),
      );
    }

    final List<GravitySignal> sorted =
        signals
            .map(
              (GravitySignal s) => GravitySignal(
                key: s.key,
                weight: siClamp01(s.weight),
                reason: s.reason,
              ),
            )
            .toList()
          ..sort(
            (GravitySignal a, GravitySignal b) => b.weight.compareTo(a.weight),
          );

    final double total = siClamp01(
      sorted.fold<double>(0, (double sum, GravitySignal s) => sum + s.weight) /
          (sorted.isEmpty ? 1 : sorted.length),
    );

    final String center = sorted.isEmpty ? 'none' : sorted.first.key;

    return ContextualGravityField(
      signals: List<GravitySignal>.unmodifiable(sorted),
      center: center,
      totalWeight: total,
      guidance: _guidance(center, context, instinct),
    );
  }

  double _emotionWeight(SIContext context) {
    final SIUserState u = context.userState;
    return siClamp01(
      (u.stress + u.cognitiveLoad + u.engagement + u.fatigue) / 4,
    );
  }

  String _guidance(
    String center,
    SIContext context,
    InstinctGuidance instinct,
  ) {
    if (instinct.safetyFirst) {
      return 'Prioritize safety, clarity, and low pressure.';
    }
    if (center.startsWith('pattern:')) {
      return 'Respect detected behavior patterns.';
    }
    if (center.startsWith('learning:resistance')) {
      return 'Reduce scope and reframe the next action.';
    }
    if (context.userState.motivation >= 0.7) {
      return 'Use momentum for one focused action.';
    }
    return 'Keep guidance grounded in the strongest current signal.';
  }
}
