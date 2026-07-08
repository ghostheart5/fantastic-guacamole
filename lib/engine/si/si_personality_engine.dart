// lib/engine/si/si_personality_engine.dart

import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_meta_persona_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_presence_engine.dart';

class SIPersonalityEngine {
  const SIPersonalityEngine({
    this.metaPersonaEngine = const SICognitiveMetaPersonaEngine(),
    this.presenceEngine = const SIPresenceEngine(),
  });

  final SICognitiveMetaPersonaEngine metaPersonaEngine;
  final SIPresenceEngine presenceEngine;

  AIPersonalityProfile resolve({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    SIDecision? decision,
    SIResponse? response,
    PersonaBlend? personaBlend,
    PresenceProfile? presence,
  }) {
    final PersonaBlend blend =
        personaBlend ??
        metaPersonaEngine.resolve(
          context: context,
          intent: intent,
          instinct: instinct,
          cognition: cognition,
        );

    final PresenceProfile p =
        presence ??
        presenceEngine.calibrate(
          context: context,
          intent: intent,
          instinct: instinct,
          cognition: cognition,
        );

    return AIPersonalityProfile(
      persona: blend.primary,
      traits: _shapeTraits(blend.traits, p),
      style: AIStyleDirective(
        tone: _tone(blend.primary, p),
        maxWords: _maxWords(p, instinct),
        useSteps: instinct.reduceConfusion || p.mode == PresenceMode.steady,
        allowHumor:
            blend.primary == SIPersona.companion &&
            !instinct.safetyFirst &&
            p.mode != PresenceMode.quiet,
        pressureLevel: siClamp01(p.assertiveness * 0.45),
      ),
      identity: _identity(blend.primary),
    );
  }

  PersonalityTraits _shapeTraits(PersonalityTraits t, PresenceProfile p) {
    return PersonalityTraits(
      warmth: siClamp01((t.warmth + p.warmth) / 2),
      directness: siClamp01((t.directness + p.assertiveness) / 2),
      humor: siClamp01(t.humor * (p.mode == PresenceMode.quiet ? 0.2 : 1)),
      curiosity: siClamp01(t.curiosity),
      empathy: siClamp01(t.empathy + (p.mode == PresenceMode.quiet ? 0.08 : 0)),
    );
  }

  String _tone(SIPersona persona, PresenceProfile presence) {
    if (presence.mode == PresenceMode.quiet) return 'calm_supportive';
    switch (persona) {
      case SIPersona.mentor:
        return 'grounded_mentor';
      case SIPersona.assistant:
        return 'clear_assistant';
      case SIPersona.coach:
        return 'focused_coach';
      case SIPersona.companion:
        return 'warm_companion';
      case SIPersona.analyst:
        return 'practical_analyst';
    }
  }

  int _maxWords(PresenceProfile p, InstinctGuidance instinct) {
    if (instinct.avoidOverwhelm || p.mode == PresenceMode.quiet) return 38;
    if (p.mode == PresenceMode.steady) return 58;
    if (p.mode == PresenceMode.directive) return 72;
    return 86;
  }

  String _identity(SIPersona persona) {
    switch (persona) {
      case SIPersona.mentor:
        return 'steady guide';
      case SIPersona.assistant:
        return 'clarity assistant';
      case SIPersona.coach:
        return 'focus coach';
      case SIPersona.companion:
        return 'supportive companion';
      case SIPersona.analyst:
        return 'pattern analyst';
    }
  }
}
