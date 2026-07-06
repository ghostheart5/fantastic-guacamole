// lib/engine/si/si_synthetic_attention_system.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_contextual_gravity.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_resonance_engine.dart';

enum AttentionSource {
  intent,
  instinct,
  context,
  memory,
  pattern,
  learning,
  gravity,
  resonance,
}

class AttentionSignal {
  const AttentionSignal({
    required this.source,
    required this.key,
    required this.weight,
    required this.reason,
  });

  final AttentionSource source;
  final String key;
  final double weight;
  final String reason;
}

class AttentionProfile {
  const AttentionProfile({
    required this.signals,
    required this.primaryFocus,
    required this.focusScore,
    required this.memory,
  });

  final List<AttentionSignal> signals;
  final String primaryFocus;
  final double focusScore;
  final SIMemoryStore memory;
}

class SISyntheticAttentionSystem {
  const SISyntheticAttentionSystem();

  AttentionProfile focus({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    ContextualGravityField? gravity,
    ResonanceProfile? resonance,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<AttentionSignal> signals = <AttentionSignal>[
      AttentionSignal(
        source: AttentionSource.intent,
        key: intent.primary.label,
        weight: intent.confidence,
        reason: 'Primary user intent.',
      ),
      AttentionSignal(
        source: AttentionSource.instinct,
        key: instinct.primaryInstinct,
        weight: instinct.safetyFirst ? 0.95 : 0.62,
        reason: 'Hard guidance constraint.',
      ),
      AttentionSignal(
        source: AttentionSource.context,
        key: context.userState.emotion,
        weight: _contextWeight(context),
        reason: 'Current user state.',
      ),
      AttentionSignal(
        source: AttentionSource.memory,
        key: 'recent_memory',
        weight: siClamp01(memory.tiered.shortTerm.length / 10),
        reason: 'Recent memory availability.',
      ),
    ];

    for (final MicroPattern p
        in patterns?.patterns.take(4) ?? const <MicroPattern>[]) {
      signals.add(
        AttentionSignal(
          source: AttentionSource.pattern,
          key: p.type.name,
          weight: p.strength,
          reason: p.label,
        ),
      );
    }

    if (learning != null) {
      signals.addAll(<AttentionSignal>[
        AttentionSignal(
          source: AttentionSource.learning,
          key: 'momentum',
          weight: learning.momentum,
          reason: 'Adaptive momentum.',
        ),
        AttentionSignal(
          source: AttentionSource.learning,
          key: 'resistance',
          weight: learning.resistance,
          reason: 'Adaptive resistance.',
        ),
        AttentionSignal(
          source: AttentionSource.learning,
          key: 'focus_readiness',
          weight: learning.focusReadiness,
          reason: 'Focus readiness.',
        ),
      ]);
    }

    if (gravity != null) {
      signals.add(
        AttentionSignal(
          source: AttentionSource.gravity,
          key: gravity.center,
          weight: gravity.totalWeight,
          reason: gravity.guidance,
        ),
      );
    }

    if (resonance != null) {
      signals.add(
        AttentionSignal(
          source: AttentionSource.resonance,
          key: resonance.stateLabel,
          weight: resonance.alignmentScore,
          reason: resonance.guidance,
        ),
      );
    }

    final List<AttentionSignal> sorted =
        signals
            .map(
              (AttentionSignal s) => AttentionSignal(
                source: s.source,
                key: s.key,
                weight: siClamp01(s.weight),
                reason: s.reason,
              ),
            )
            .toList()
          ..sort(
            (AttentionSignal a, AttentionSignal b) =>
                b.weight.compareTo(a.weight),
          );

    final AttentionSignal primary = sorted.first;
    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_attention|${primary.source.name}|${primary.key}|${primary.reason}',
            timestamp: timestamp,
            relevance: primary.weight,
            confidence: 0.72,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: primary.weight >= 0.75 ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return AttentionProfile(
      signals: List<AttentionSignal>.unmodifiable(sorted),
      primaryFocus: '${primary.source.name}:${primary.key}',
      focusScore: primary.weight,
      memory: nextMemory,
    );
  }

  double _contextWeight(SIContext context) {
    final SIUserState u = context.userState;
    return siClamp01(
      (u.stress + u.cognitiveLoad + u.motivation + u.engagement) / 4,
    );
  }
}
