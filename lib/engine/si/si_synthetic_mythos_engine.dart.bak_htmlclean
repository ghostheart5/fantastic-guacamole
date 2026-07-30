// lib/engine/si/si_synthetic_mythos_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIMythos {
  const SIMythos({
    required this.arc,
    required this.symbol,
    required this.meaning,
    required this.memory,
  });
  final String arc;
  final String symbol;
  final String meaning;
  final SIMemoryStore memory;
}

class SISyntheticMythosEngine {
  const SISyntheticMythosEngine();

  SIMythos build({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final arc = instinct.safetyFirst
        ? 'guardian_arc'
        : context.userState.motivation >= .68
        ? 'builder_arc'
        : context.userState.fatigue >= .68
        ? 'restoration_arc'
        : 'guide_arc';
    final symbol = arc == 'guardian_arc'
        ? 'anchor'
        : arc == 'builder_arc'
        ? 'forge'
        : arc == 'restoration_arc'
        ? 'hearth'
        : 'lantern';
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content: 'mythos|$arc|$symbol',
            timestamp: t,
            relevance: .65,
            confidence: .68,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIMythos(
      arc: arc,
      symbol: symbol,
      meaning: 'Use $symbol framing to support one clear next step.',
      memory: next,
    );
  }
}
