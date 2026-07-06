// lib/engine/si/si_synthetic_memory_weather_system.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_attention_system.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_intuition.dart';

enum MemoryWeatherCondition { clear, active, stormy, stale, heavy }

class MemoryWeatherProfile {
  const MemoryWeatherProfile({
    required this.condition,
    required this.emotionalIntensity,
    required this.usageFrequency,
    required this.decayPressure,
    required this.attentionBias,
    required this.intuitionBias,
    required this.memory,
  });

  final MemoryWeatherCondition condition;
  final double emotionalIntensity;
  final double usageFrequency;
  final double decayPressure;
  final double attentionBias;
  final double intuitionBias;
  final SIMemoryStore memory;
}

class SISyntheticMemoryWeatherSystem {
  const SISyntheticMemoryWeatherSystem();

  MemoryWeatherProfile evaluate({
    required SIMemoryStore memory,
    required SIContext context,
    AttentionProfile? attention,
    SyntheticIntuitionResult? intuition,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<MemoryRecord> records = <MemoryRecord>[
      ...memory.tiered.shortTerm,
      ...memory.tiered.midTerm,
      ...memory.tiered.longTerm,
    ];

    final double emotional = records.isEmpty
        ? siClamp01(context.userState.stress)
        : siClamp01(
            records.fold<double>(
                  0,
                  (double s, MemoryRecord r) =>
                      s + siClamp01(r.emotionalWeight),
                ) /
                records.length,
          );

    final double usage = siClamp01(memory.tiered.shortTerm.length / 10);
    final double decay = records.isEmpty
        ? 0.2
        : siClamp01(
            records.where((MemoryRecord r) => r.score(t) < 0.25).length /
                records.length,
          );

    final MemoryWeatherCondition condition = _condition(
      emotional,
      usage,
      decay,
    );

    final double attentionBias = siClamp01(
      (attention?.focusScore ?? 0.5) + (usage * 0.15) - (decay * 0.12),
    );

    final double intuitionBias = siClamp01(
      (intuition?.score ?? 0.5) + ((1 - emotional) * 0.1) - (decay * 0.1),
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'memory_weather|${condition.name}|emotional=${emotional.toStringAsFixed(2)}|usage=${usage.toStringAsFixed(2)}|decay=${decay.toStringAsFixed(2)}',
            timestamp: t,
            relevance: attentionBias,
            confidence: 0.72,
            emotionalWeight: emotional,
            reinforcement: condition == MemoryWeatherCondition.clear ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return MemoryWeatherProfile(
      condition: condition,
      emotionalIntensity: emotional,
      usageFrequency: usage,
      decayPressure: decay,
      attentionBias: attentionBias,
      intuitionBias: intuitionBias,
      memory: nextMemory,
    );
  }

  MemoryWeatherCondition _condition(
    double emotional,
    double usage,
    double decay,
  ) {
    if (emotional >= 0.7 && usage >= 0.55) return MemoryWeatherCondition.stormy;
    if (decay >= 0.55) return MemoryWeatherCondition.stale;
    if (emotional >= 0.65) return MemoryWeatherCondition.heavy;
    if (usage >= 0.55) return MemoryWeatherCondition.active;
    return MemoryWeatherCondition.clear;
  }
}
