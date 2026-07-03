// Module 7 — Response
// Pipeline step: SIDecision + InstinctGuidance → SIResponse
// Merges: si_response_engine + ai_response + si_personality_engine + si_emotion_engine + style

import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/si/core/si_input_module.dart';
import 'package:fantastic_guacamole/engine/si/offline/identity_engine.dart';

// ─── Data contracts ───────────────────────────────────────────────────────────

enum SIPersona { mentor, assistant, coach, companion, analyst }

class PersonalityTraits {
  const PersonalityTraits({
    required this.warmth,
    required this.directness,
    required this.humor,
    required this.curiosity,
    required this.empathy,
  });

  final double warmth;
  final double directness;
  final double humor;
  final double curiosity;
  final double empathy;
}

class EmotionalSignal {
  const EmotionalSignal({
    required this.mood,
    required this.intensity,
    required this.shift,
  });

  final String mood;
  final double intensity;
  final String shift;
}

class SIResponse {
  const SIResponse({
    required this.message,
    required this.emotion,
    required this.persona,
    required this.traits,
    required this.confidence,
    this.task,
  });

  final String message;
  final String emotion;
  final SIPersona persona;
  final PersonalityTraits traits;
  final double confidence;
  final Task? task;

  String get taskTitle => task?.title ?? 'No active tasks';
}

// ─── Module ───────────────────────────────────────────────────────────────────

class SIResponseModule {
  const SIResponseModule();

  SIResponse generate({
    required String intent,
    required String mood,
    required String reasoning,
    required double confidence,
    required bool safetyFirst,
    required bool avoidOverwhelm,
    required SILatentInputs latent,
    Task? task,
    String? previousMood,
    IdentityState? identityState,
  }) {
    final EmotionalSignal signal = _inferEmotion(
      text: reasoning,
      latent: latent,
      previousMood: previousMood,
    );
    final SIPersona persona = _choosePersona(mood: mood, intent: intent);
    final PersonalityTraits traits = _traitsFor(persona);

    String message = _buildMessage(
      intent: intent,
      task: task,
      confidence: confidence,
      safetyFirst: safetyFirst,
    );
    message = _shapeForEmotion(message, signal);
    if (avoidOverwhelm && message.length > 280) {
      message = _truncate(message, 280);
    }
    if (identityState != null) {
      message = const IdentityEngine().reinforceIdentity(identityState, message);
    }

    return SIResponse(
      message: message,
      emotion: signal.mood,
      persona: persona,
      traits: traits,
      confidence: confidence,
      task: task,
    );
  }

  EmotionalSignal _inferEmotion({
    required String text,
    required SILatentInputs latent,
    String? previousMood,
  }) {
    final String lowered = text.toLowerCase();
    String mood = 'neutral';
    if (latent.frustration > 0.6 || lowered.contains('frustrated')) {
      mood = 'stressed';
    } else if (latent.excitement > 0.6 || lowered.contains('excited')) {
      mood = 'excited';
    } else if (latent.confusion > 0.5 || lowered.contains('confused')) {
      mood = 'confused';
    }

    final double intensity =
        (latent.frustration +
                latent.excitement +
                latent.confusion +
                latent.hesitation) /
            4;
    final String shift =
        previousMood == null || previousMood == mood
            ? 'stable'
            : '$previousMood->$mood';

    return EmotionalSignal(
      mood: mood,
      intensity: intensity.clamp(0.0, 1.0),
      shift: shift,
    );
  }

  SIPersona _choosePersona({required String mood, required String intent}) {
    if (mood == 'stressed') return SIPersona.mentor;
    if (intent == 'insight_request') return SIPersona.analyst;
    if (intent == 'start_focus') return SIPersona.coach;
    if (mood == 'confused') return SIPersona.assistant;
    return SIPersona.companion;
  }

  PersonalityTraits _traitsFor(SIPersona persona) {
    switch (persona) {
      case SIPersona.mentor:
        return const PersonalityTraits(
          warmth: 0.9,
          directness: 0.7,
          humor: 0.2,
          curiosity: 0.6,
          empathy: 0.95,
        );
      case SIPersona.assistant:
        return const PersonalityTraits(
          warmth: 0.6,
          directness: 0.85,
          humor: 0.15,
          curiosity: 0.55,
          empathy: 0.7,
        );
      case SIPersona.coach:
        return const PersonalityTraits(
          warmth: 0.7,
          directness: 0.9,
          humor: 0.2,
          curiosity: 0.5,
          empathy: 0.65,
        );
      case SIPersona.companion:
        return const PersonalityTraits(
          warmth: 0.88,
          directness: 0.55,
          humor: 0.45,
          curiosity: 0.7,
          empathy: 0.85,
        );
      case SIPersona.analyst:
        return const PersonalityTraits(
          warmth: 0.45,
          directness: 0.8,
          humor: 0.1,
          curiosity: 0.8,
          empathy: 0.5,
        );
    }
  }

  String _buildMessage({
    required String intent,
    required double confidence,
    required bool safetyFirst,
    Task? task,
  }) {
    if (safetyFirst) {
      return 'Let us slow down and take this one step at a time. '
          '${task != null ? "I suggest focusing on: ${task.title}." : ""}';
    }
    if (task != null) {
      return confidence >= 0.7
          ? 'High-energy window detected. Your next focus: ${task.title}.'
          : 'Good momentum. I recommend: ${task.title}.';
    }
    return confidence >= 0.7
        ? 'You are in a strong state. Keep building.'
        : 'Steady progress. One step at a time.';
  }

  String _shapeForEmotion(String reply, EmotionalSignal signal) {
    switch (signal.mood) {
      case 'confused':
        return '$reply\n\nI will keep this simple and step-by-step.';
      case 'stressed':
        return '$reply\n\nLet us take one action at a time.';
      case 'excited':
        return '$reply\n\nMomentum looks great — keep it rolling.';
      default:
        return reply;
    }
  }

  String _truncate(String text, int maxChars) {
    final String shortened = text.substring(0, maxChars);
    final int lastPeriod = shortened.lastIndexOf('.');
    if (lastPeriod > 80) return shortened.substring(0, lastPeriod + 1);
    return '$shortened...';
  }
}
