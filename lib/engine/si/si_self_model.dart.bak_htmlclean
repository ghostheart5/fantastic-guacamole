// lib/engine/si/si_self_model.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SISelfModelProfile {
  const SISelfModelProfile({
    required this.identity,
    required this.traits,
    required this.operatingMode,
    required this.confidence,
    required this.memory,
  });

  final String identity;
  final Map<String, double> traits;
  final String operatingMode;
  final double confidence;
  final SIMemoryStore memory;
}

class SISelfModelEngine {
  const SISelfModelEngine();

  SISelfModelProfile update({
    required SIContext context,
    required SIIntent intent,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final String mode = context.userState.stress >= .7
        ? 'guardian'
        : intent.primary.label == 'insight_request'
        ? 'analyst'
        : intent.primary.label == 'get_task' ||
              intent.primary.label == 'start_focus'
        ? 'coach'
        : 'companion';

    final Map<String, double> traits = <String, double>{
      'clarity': siClamp01(intent.confidence),
      'empathy': context.userState.stress >= .6 ? .9 : .72,
      'directness': mode == 'coach' ? .85 : .62,
      'restraint': context.userState.cognitiveLoad >= .7 ? .9 : .55,
    };

    final double confidence = siClamp01(
      traits.values.fold<double>(0, (double s, double v) => s + v) /
          traits.length,
    );

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content:
                'self_model|identity=chronospark_si|mode=$mode|confidence=${confidence.toStringAsFixed(2)}',
            timestamp: t,
            relevance: confidence,
            confidence: .74,
            emotionalWeight: context.userState.stress,
            reinforcement: confidence >= .7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return SISelfModelProfile(
      identity: 'chronospark_si',
      traits: Map<String, double>.unmodifiable(traits),
      operatingMode: mode,
      confidence: confidence,
      memory: next,
    );
  }
}
