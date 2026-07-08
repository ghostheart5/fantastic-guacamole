// lib/engine/si/si_synthetic_emergent_persona_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIEmergentPersona {
  const SIEmergentPersona({
    required this.persona,
    required this.traits,
    required this.reason,
    required this.memory,
  });
  final SIPersona persona;
  final PersonalityTraits traits;
  final String reason;
  final SIMemoryStore memory;
}

class SISyntheticEmergentPersonaEngine {
  const SISyntheticEmergentPersonaEngine();

  SIEmergentPersona resolve({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final p = instinct.safetyFirst
        ? SIPersona.mentor
        : intent.primary.label == 'insight_request'
        ? SIPersona.analyst
        : (intent.primary.label == 'get_task' ||
              intent.primary.label == 'start_focus')
        ? SIPersona.coach
        : context.userState.emotion == 'confused'
        ? SIPersona.assistant
        : SIPersona.companion;
    final traits = PersonalityTraits(
      warmth: p == SIPersona.mentor ? .9 : .72,
      directness: p == SIPersona.coach ? .9 : .68,
      humor: instinct.safetyFirst ? 0 : .12,
      curiosity: .6,
      empathy: instinct.safetyFirst ? .95 : .75,
    );
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'emergent_persona|${p.name}',
            timestamp: t,
            relevance: .68,
            confidence: .7,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIEmergentPersona(
      persona: p,
      traits: traits,
      reason: 'persona_selected_from_state_intent_instinct',
      memory: next,
    );
  }
}
