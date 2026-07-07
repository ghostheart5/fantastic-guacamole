// lib/engine/si/si_synthetic_archetype_system.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIArchetypeState {
  const SIArchetypeState({
    required this.name,
    required this.symbol,
    required this.weight,
    required this.guidance,
    required this.memory,
  });
  final String name;
  final String symbol;
  final double weight;
  final String guidance;
  final SIMemoryStore memory;
}

class SISyntheticArchetypeSystem {
  const SISyntheticArchetypeSystem();

  SIArchetypeState resolve({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final name = instinct.safetyFirst
        ? 'guardian'
        : context.userState.fatigue >= .68
        ? 'restorer'
        : intent.primary.label == 'insight_request'
        ? 'analyst'
        : intent.primary.label == 'reflect'
        ? 'seeker'
        : (intent.primary.label == 'get_task' ||
              intent.primary.label == 'start_focus')
        ? 'builder'
        : 'guide';
    final symbol = {
      'guardian': 'anchor',
      'restorer': 'hearth',
      'analyst': 'constellation',
      'seeker': 'mirror',
      'builder': 'forge',
      'guide': 'lantern',
    }[name]!;
    final weight = siClamp01(
      intent.confidence * .4 +
          context.userState.engagement * .3 +
          (1 - context.userState.stress) * .3,
    );
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content: 'synthetic_archetype|$name|$symbol',
            timestamp: t,
            relevance: weight,
            confidence: .7,
            emotionalWeight: context.userState.stress,
            reinforcement: weight >= .7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);
    return SIArchetypeState(
      name: name,
      symbol: symbol,
      weight: weight,
      guidance: _guidance(name),
      memory: next,
    );
  }

  String _guidance(String name) => switch (name) {
    'guardian' => 'protect_agency_and_reduce_pressure',
    'restorer' => 'lower_load_and_rebuild_capacity',
    'analyst' => 'name_one_pattern',
    'seeker' => 'reflect_without_judgment',
    'builder' => 'turn_intent_into_action',
    _ => 'make_next_step_clear',
  };
}
