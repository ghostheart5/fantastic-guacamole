// lib/engine/si/ai_personality.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum AIPersonality { coach, strategist, strict }

class AIStyleDirective {
  const AIStyleDirective({
    required this.tone,
    required this.maxWords,
    required this.useSteps,
    required this.allowHumor,
    required this.pressureLevel,
  });

  final String tone;
  final int maxWords;
  final bool useSteps;
  final bool allowHumor;
  final double pressureLevel;

  AIStyleDirective copyWith({
    String? tone,
    int? maxWords,
    bool? useSteps,
    bool? allowHumor,
    double? pressureLevel,
  }) {
    return AIStyleDirective(
      tone: tone ?? this.tone,
      maxWords: maxWords ?? this.maxWords,
      useSteps: useSteps ?? this.useSteps,
      allowHumor: allowHumor ?? this.allowHumor,
      pressureLevel: pressureLevel ?? this.pressureLevel,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tone': tone,
    'max_words': maxWords,
    'use_steps': useSteps,
    'allow_humor': allowHumor,
    'pressure_level': siClamp01(pressureLevel),
  };
}

class AIPersonalityProfile {
  const AIPersonalityProfile({
    required this.persona,
    required this.traits,
    required this.style,
    required this.identity,
  });

  final SIPersona persona;
  final PersonalityTraits traits;
  final AIStyleDirective style;
  final String identity;

  factory AIPersonalityProfile.fromResponse(SIResponse response) {
    return AIPersonalityProfile(
      persona: response.persona,
      traits: response.traits,
      style: AIStyleDirective(
        tone: _toneFor(response.persona),
        maxWords: response.emotion == 'stressed' ? 42 : 64,
        useSteps: response.emotion == 'confused',
        allowHumor: response.persona == SIPersona.companion,
        pressureLevel: response.emotion == 'stressed' ? 0.1 : 0.35,
      ),
      identity: _identityFor(response.persona),
    );
  }

  AIPersonalityProfile adapt({
    required SIContext context,
    InstinctGuidance? instinct,
  }) {
    final bool safety = instinct?.safetyFirst ?? false;
    final bool overwhelm = instinct?.avoidOverwhelm ?? false;
    final bool confused = context.userState.emotion == 'confused';

    return AIPersonalityProfile(
      persona: safety
          ? SIPersona.mentor
          : confused
          ? SIPersona.assistant
          : persona,
      traits: PersonalityTraits(
        warmth: siClamp01(traits.warmth + (safety ? 0.08 : 0)),
        directness: siClamp01(traits.directness - (overwhelm ? 0.1 : 0)),
        humor: safety ? 0 : siClamp01(traits.humor),
        curiosity: siClamp01(traits.curiosity),
        empathy: siClamp01(traits.empathy + (safety ? 0.1 : 0)),
      ),
      style: style.copyWith(
        tone: safety ? 'calm_supportive' : style.tone,
        maxWords: overwhelm ? 36 : style.maxWords,
        useSteps: confused || style.useSteps,
        allowHumor: safety ? false : style.allowHumor,
        pressureLevel: safety ? 0.05 : style.pressureLevel,
      ),
      identity: identity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'persona': persona.name,
    'identity': identity,
    'traits': <String, dynamic>{
      'warmth': siClamp01(traits.warmth),
      'directness': siClamp01(traits.directness),
      'humor': siClamp01(traits.humor),
      'curiosity': siClamp01(traits.curiosity),
      'empathy': siClamp01(traits.empathy),
    },
    'style': style.toJson(),
  };

  static String _toneFor(SIPersona persona) {
    switch (persona) {
      case SIPersona.mentor:
        return 'calm_supportive';
      case SIPersona.assistant:
        return 'clear_direct';
      case SIPersona.coach:
        return 'focused_motivating';
      case SIPersona.companion:
        return 'warm_grounded';
      case SIPersona.analyst:
        return 'precise_practical';
    }
  }

  static String _identityFor(SIPersona persona) {
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
