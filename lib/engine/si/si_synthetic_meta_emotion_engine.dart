// lib/engine/si/si_synthetic_meta_emotion_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_emotion_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_attention_system.dart';

class MetaEmotionProfile {
  const MetaEmotionProfile({
    required this.primary,
    required this.secondary,
    required this.stability,
    required this.toneDirective,
    required this.outputPressure,
    required this.memory,
  });

  final String primary;
  final String secondary;
  final double stability;
  final String toneDirective;
  final double outputPressure;
  final SIMemoryStore memory;
}

class SISyntheticMetaEmotionEngine {
  const SISyntheticMetaEmotionEngine({
    this.emotionEngine = const SIEmotionEngine(),
  });

  final SIEmotionEngine emotionEngine;

  MetaEmotionProfile evaluate({
    required SIContext context,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    String? text,
    String? previousMood,
    CognitiveTemperature? temperature,
    AttentionProfile? attention,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final EmotionModulation modulation = emotionEngine.infer(
      context: context,
      text: text,
      previousMood: previousMood,
    );

    final String primary = modulation.signal.mood;
    final String secondary = _secondary(context, attention);
    final double stability = _stability(context, modulation, attention);
    final double pressure = _pressure(
      modulation: modulation,
      instinct: instinct,
      temperature: temperature,
    );

    final String directive = _directive(
      primary: primary,
      stability: stability,
      pressure: pressure,
      instinct: instinct,
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_meta_emotion|primary=$primary|secondary=$secondary|directive=$directive',
            timestamp: timestamp,
            relevance: 1 - pressure,
            confidence: stability,
            emotionalWeight: pressure,
            reinforcement: stability >= 0.65 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return MetaEmotionProfile(
      primary: primary,
      secondary: secondary,
      stability: stability,
      toneDirective: directive,
      outputPressure: pressure,
      memory: nextMemory,
    );
  }

  String _secondary(SIContext context, AttentionProfile? attention) {
    if (attention != null && attention.primaryFocus.startsWith('instinct:')) {
      return 'constraint-aware';
    }
    if (context.userState.motivation >= 0.7) return 'motivated';
    if (context.userState.fatigue >= 0.65) return 'capacity-limited';
    return 'steady';
  }

  double _stability(
    SIContext context,
    EmotionModulation modulation,
    AttentionProfile? attention,
  ) {
    final double base = context.userState.stability == 'stable' ? 0.72 : 0.48;
    final double attentionBoost = (attention?.focusScore ?? 0.5) * 0.15;
    return siClamp01(
      base + attentionBoost - modulation.signal.intensity * 0.12,
    );
  }

  double _pressure({
    required EmotionModulation modulation,
    required InstinctGuidance instinct,
    CognitiveTemperature? temperature,
  }) {
    double value = modulation.outputPressure;
    if (instinct.safetyFirst || instinct.avoidOverwhelm) value -= 0.12;
    if (temperature != null) {
      value = (value + temperature.responseIntensity) / 2;
    }
    return siClamp01(value);
  }

  String _directive({
    required String primary,
    required double stability,
    required double pressure,
    required InstinctGuidance instinct,
  }) {
    if (instinct.safetyFirst || pressure < 0.25) return 'calm_minimal';
    if (primary == 'confused') return 'clear_stepwise';
    if (primary == 'stressed') return 'supportive_low_pressure';
    if (primary == 'excited' && stability >= 0.55) return 'focused_momentum';
    return 'steady_supportive';
  }
}
