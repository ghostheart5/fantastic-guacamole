// lib/engine/si/si_synthetic_paracosm_generator.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIParacosmFrame {
  const SIParacosmFrame({
    required this.worldMode,
    required this.rule,
    required this.safeForOutput,
    required this.memory,
  });
  final String worldMode;
  final String rule;
  final bool safeForOutput;
  final SIMemoryStore memory;
}

class SISyntheticParacosmGenerator {
  const SISyntheticParacosmGenerator();

  SIParacosmFrame generate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final safe = !instinct.safetyFirst && !instinct.avoidOverwhelm;
    final mode = safe && intent.primary.label == 'insight_request'
        ? 'constellation_room'
        : safe
        ? 'command_center'
        : 'quiet_room';
    final rule = safe
        ? 'Use symbolic framing only if it clarifies the next action.'
        : 'Keep language literal, brief, and supportive.';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'paracosm|$mode|safe=$safe',
            timestamp: t,
            relevance: safe ? .55 : .35,
            confidence: .65,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIParacosmFrame(
      worldMode: mode,
      rule: rule,
      safeForOutput: safe,
      memory: next,
    );
  }
}
