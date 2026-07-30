// lib/engine/si/si_synthetic_dream_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIDreamFrame {
  const SIDreamFrame({
    required this.symbol,
    required this.reframe,
    required this.safeForOutput,
    required this.memory,
  });
  final String symbol;
  final String reframe;
  final bool safeForOutput;
  final SIMemoryStore memory;
}

class SISyntheticDreamEngine {
  const SISyntheticDreamEngine();

  SIDreamFrame dream({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final safe = !instinct.safetyFirst && !instinct.avoidOverwhelm;
    final symbol = intent.primary.label == 'reflect'
        ? 'mirror'
        : intent.primary.label == 'insight_request'
        ? 'constellation'
        : intent.primary.label == 'start_focus'
        ? 'lens'
        : 'compass';
    final reframe = safe
        ? 'Turn the moment into a clear symbol: $symbol guiding one next step.'
        : 'Keep the frame literal and simple.';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'synthetic_dream|$symbol|$reframe',
            timestamp: t,
            relevance: safe ? .62 : .32,
            confidence: safe ? .68 : .45,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIDreamFrame(
      symbol: symbol,
      reframe: reframe,
      safeForOutput: safe,
      memory: next,
    );
  }
}
