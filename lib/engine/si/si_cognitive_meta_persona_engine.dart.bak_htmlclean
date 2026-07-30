// lib/engine/si/si_cognitive_meta_persona_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_resonance_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';

class PersonaBlend {
  const PersonaBlend({
    required this.primary,
    required this.secondary,
    required this.blendWeight,
    required this.reason,
    required this.traits,
  });

  final SIPersona primary;
  final SIPersona? secondary;
  final double blendWeight;
  final String reason;
  final PersonalityTraits traits;
}

class SICognitiveMetaPersonaEngine {
  const SICognitiveMetaPersonaEngine();

  PersonaBlend resolve({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    ResonanceProfile? resonance,
    CognitiveLoadPlan? loadPlan,
    CognitiveTemperature? temperature,
    AdaptiveLearningWeights? learning,
  }) {
    final String mood = siNormalizeMood(context.userState.emotion);
    final bool safety = instinct.safetyFirst || instinct.avoidOverwhelm;
    final bool confused = instinct.reduceConfusion || mood == 'confused';
    final bool insight = intent.primary.label == 'insight_request';
    final bool action =
        intent.primary.label == 'get_task' ||
        intent.primary.label == 'start_focus';

    SIPersona primary;
    SIPersona? secondary;
    String reason;

    if (safety) {
      primary = SIPersona.mentor;
      secondary = confused ? SIPersona.assistant : null;
      reason = 'Safety and cognitive load require a calm mentor voice.';
    } else if (confused) {
      primary = SIPersona.assistant;
      secondary = SIPersona.mentor;
      reason = 'Confusion requires clarity and gentle support.';
    } else if (insight) {
      primary = SIPersona.analyst;
      secondary = SIPersona.mentor;
      reason = 'Insight requests need practical analysis with warmth.';
    } else if (action) {
      primary = SIPersona.coach;
      secondary = mood == 'stressed' ? SIPersona.mentor : null;
      reason = 'Action intent benefits from focused coaching.';
    } else {
      primary = SIPersona.companion;
      secondary = SIPersona.assistant;
      reason = 'General conversation benefits from warm guidance.';
    }

    final double blendWeight = _blendWeight(
      context: context,
      instinct: instinct,
      cognition: cognition,
      resonance: resonance,
      loadPlan: loadPlan,
      temperature: temperature,
      learning: learning,
    );

    return PersonaBlend(
      primary: primary,
      secondary: secondary,
      blendWeight: blendWeight,
      reason: reason,
      traits: _traits(primary, secondary, blendWeight, safety),
    );
  }

  double _blendWeight({
    required SIContext context,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    ResonanceProfile? resonance,
    CognitiveLoadPlan? loadPlan,
    CognitiveTemperature? temperature,
    AdaptiveLearningWeights? learning,
  }) {
    double value = 0.35;
    if (instinct.safetyFirst) value += 0.2;
    if (instinct.reduceConfusion) value += 0.15;
    if ((cognition?.meta.misunderstandingRisk ?? 0) >= 0.65) value += 0.15;
    if ((resonance?.alignmentScore ?? 1) < 0.55) value += 0.1;
    if (loadPlan?.detailLevel == CognitiveDetailLevel.minimal) value += 0.1;
    if ((temperature?.empathy ?? 0.5) >= 0.75) value += 0.08;
    if ((learning?.resistance ?? 0.5) >= 0.65) value += 0.08;
    if (context.userState.stress >= 0.65) value += 0.1;
    return siClamp01(value);
  }

  PersonalityTraits _traits(
    SIPersona primary,
    SIPersona? secondary,
    double weight,
    bool safety,
  ) {
    final PersonalityTraits a = _base(primary);
    final PersonalityTraits b = secondary == null ? a : _base(secondary);

    double blend(double x, double y) =>
        siClamp01((x * (1 - weight)) + (y * weight));

    return PersonalityTraits(
      warmth: siClamp01(blend(a.warmth, b.warmth) + (safety ? 0.08 : 0)),
      directness: siClamp01(
        blend(a.directness, b.directness) - (safety ? 0.08 : 0),
      ),
      humor: safety ? 0 : blend(a.humor, b.humor),
      curiosity: blend(a.curiosity, b.curiosity),
      empathy: siClamp01(blend(a.empathy, b.empathy) + (safety ? 0.1 : 0)),
    );
  }

  PersonalityTraits _base(SIPersona persona) {
    switch (persona) {
      case SIPersona.mentor:
        return const PersonalityTraits(
          warmth: .9,
          directness: .65,
          humor: .05,
          curiosity: .55,
          empathy: .95,
        );
      case SIPersona.assistant:
        return const PersonalityTraits(
          warmth: .68,
          directness: .86,
          humor: .08,
          curiosity: .55,
          empathy: .75,
        );
      case SIPersona.coach:
        return const PersonalityTraits(
          warmth: .72,
          directness: .9,
          humor: .12,
          curiosity: .45,
          empathy: .7,
        );
      case SIPersona.companion:
        return const PersonalityTraits(
          warmth: .88,
          directness: .55,
          humor: .3,
          curiosity: .7,
          empathy: .85,
        );
      case SIPersona.analyst:
        return const PersonalityTraits(
          warmth: .52,
          directness: .82,
          humor: .03,
          curiosity: .82,
          empathy: .55,
        );
    }
  }
}
