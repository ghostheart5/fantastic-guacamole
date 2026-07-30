// lib/engine/si/si_cognitive_genesis_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class GenesisSeed {
  const GenesisSeed({
    required this.originIntent,
    required this.originMood,
    required this.initialMode,
    required this.seedConfidence,
    required this.memory,
  });

  final String originIntent;
  final String originMood;
  final String initialMode;
  final double seedConfidence;
  final SIMemoryStore memory;
}

class SICognitiveGenesisEngine {
  const SICognitiveGenesisEngine();

  GenesisSeed seed({
    required SIContext context,
    required SIIntent intent,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final String mode = context.userState.stress >= 0.7
        ? 'stabilize'
        : intent.primary.label == 'insight_request'
        ? 'analyze'
        : intent.primary.label == 'reflect'
        ? 'reflect'
        : 'act';

    final double confidence = siClamp01(
      intent.confidence * 0.55 +
          context.userState.engagement * 0.25 +
          (1 - context.userState.cognitiveLoad) * 0.2,
    );

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'genesis|intent=${intent.primary.label}|mood=${context.userState.emotion}|mode=$mode',
            timestamp: t,
            relevance: confidence,
            confidence: confidence,
            emotionalWeight: context.userState.stress,
            reinforcement: confidence >= 0.7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return GenesisSeed(
      originIntent: intent.primary.label,
      originMood: context.userState.emotion,
      initialMode: mode,
      seedConfidence: confidence,
      memory: next,
    );
  }
}
