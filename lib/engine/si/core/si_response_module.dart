// lib/engine/si/core/si_response_module.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/offline/identity_engine.dart';

class SIResponseModule {
  const SIResponseModule();

  SIResponse generate({
    required SIDecision decision,
    required InstinctGuidance instinct,
    required SIContext context,
    SICognitionState? cognition,
    String? previousMood,
    IdentityState? identityState,
  }) {
    final double confidence = decision.confidence;
    final EmotionalSignal signal = _emotion(
      context,
      decision.reasoning,
      previousMood,
    );
    final SIPersona persona = _persona(
      decision,
      instinct,
      signal.mood,
      confidence,
    );

    String message = _message(decision, instinct, cognition, confidence);
    message = _shape(message, signal, instinct);
    message = _constrain(message, instinct, decision);
    message = _identity(message, identityState);
    message = siClean(
      message,
      fallback: 'Tell me the task, goal, or decision you want help with.',
    );

    return SIResponse(
      message: message,
      emotion: signal.mood,
      persona: persona,
      traits: _traits(
        persona,
        safetyFirst: instinct.safetyFirst || !decision.safe,
      ),
      confidence: confidence,
      task: decision.task,
    );
  }

  EmotionalSignal _emotion(
    SIContext context,
    String text,
    String? previousMood,
  ) {
    final SIUserState u = context.userState;
    final SILatentInputs l = context.input.latent;
    final String lower = text.toLowerCase();

    final double stress = <double>[
      siClamp01(u.stress),
      siClamp01(u.frustration),
      siClamp01(l.frustration),
      lower.contains('stressed') ? 0.55 : 0,
    ].reduce((double a, double b) => a > b ? a : b);

    final double confusion = <double>[
      siClamp01(l.confusion),
      siClamp01(u.cognitiveLoad) >= 0.75 ? 0.65 : 0,
      lower.contains('confused') ? 0.55 : 0,
    ].reduce((double a, double b) => a > b ? a : b);

    final double excitement = <double>[
      siClamp01(u.excitement),
      siClamp01(l.excitement),
      lower.contains('excited') ? 0.5 : 0,
    ].reduce((double a, double b) => a > b ? a : b);

    String mood = siNormalizeMood(u.emotion);
    if (stress >= 0.65) {
      mood = 'stressed';
    } else if (confusion >= 0.6) {
      mood = 'confused';
    } else if (excitement >= 0.65 && stress < 0.5) {
      mood = 'excited';
    }

    final String prev = previousMood == null
        ? ''
        : siNormalizeMood(previousMood);
    return EmotionalSignal(
      mood: mood,
      intensity: <double>[
        stress,
        confusion,
        excitement,
      ].reduce((a, b) => a > b ? a : b),
      shift: prev.isEmpty || prev == mood ? 'stable' : '$prev->$mood',
    );
  }

  SIPersona _persona(
    SIDecision decision,
    InstinctGuidance instinct,
    String mood,
    double confidence,
  ) {
    if (!decision.safe || instinct.safetyFirst) return SIPersona.mentor;
    if (instinct.reduceConfusion || mood == 'confused' || confidence < 0.5) {
      return SIPersona.assistant;
    }
    switch (decision.action) {
      case 'launch_focus_session':
      case 'present_task_recommendation':
        return SIPersona.coach;
      case 'show_insight_summary':
        return SIPersona.analyst;
      case 'open_reflection_flow':
        return SIPersona.mentor;
      default:
        return mood == 'stressed' ? SIPersona.mentor : SIPersona.companion;
    }
  }

  PersonalityTraits _traits(SIPersona p, {required bool safetyFirst}) {
    final PersonalityTraits base = switch (p) {
      SIPersona.mentor => const PersonalityTraits(
        warmth: .9,
        directness: .65,
        humor: .1,
        curiosity: .55,
        empathy: .95,
      ),
      SIPersona.assistant => const PersonalityTraits(
        warmth: .68,
        directness: .85,
        humor: .1,
        curiosity: .55,
        empathy: .75,
      ),
      SIPersona.coach => const PersonalityTraits(
        warmth: .72,
        directness: .9,
        humor: .15,
        curiosity: .45,
        empathy: .7,
      ),
      SIPersona.companion => const PersonalityTraits(
        warmth: .88,
        directness: .55,
        humor: .35,
        curiosity: .7,
        empathy: .85,
      ),
      SIPersona.analyst => const PersonalityTraits(
        warmth: .52,
        directness: .82,
        humor: .05,
        curiosity: .82,
        empathy: .55,
      ),
    };
    if (!safetyFirst) return base;
    return PersonalityTraits(
      warmth: siClamp01(base.warmth + .08),
      directness: siClamp01(base.directness - .08),
      humor: 0,
      curiosity: base.curiosity,
      empathy: siClamp01(base.empathy + .1),
    );
  }

  String _message(
    SIDecision decision,
    InstinctGuidance instinct,
    SICognitionState? cognition,
    double confidence,
  ) {
    final String task = siClean(decision.task?.title);
    if (!decision.safe) {
      return 'Let’s take a safer route. Pause, reset, and choose one small next step.';
    }
    if (instinct.safetyFirst) {
      return task.isNotEmpty
          ? 'Let’s slow this down. Focus on "$task" for one short block.'
          : 'Let’s slow this down. Pick one small step, finish it, then reassess.';
    }

    switch (decision.action) {
      case 'launch_focus_session':
        return task.isNotEmpty
            ? 'Start a focused block on "$task".'
            : 'Start a short focus block.';
      case 'present_task_recommendation':
        return task.isNotEmpty
            ? 'Best next task: "$task".'
            : 'Add or choose one task, then I can guide the next step.';
      case 'open_reflection_flow':
        return 'Capture what happened, what worked, and what should change next.';
      case 'show_insight_summary':
        return siClean(cognition?.summary, fallback: decision.reasoning);
      default:
        return siClean(
          decision.reasoning,
          fallback: confidence >= .7
              ? 'You have enough signal to move. Choose one clear next action.'
              : 'Tell me the task, goal, or decision you want help with.',
        );
    }
  }

  String _shape(
    String message,
    EmotionalSignal signal,
    InstinctGuidance instinct,
  ) {
    if (instinct.avoidOverwhelm) return '$message\n\nOne step only.';
    switch (signal.mood) {
      case 'confused':
        return '$message\n\nI’ll keep it step-by-step.';
      case 'stressed':
        return '$message\n\nNo pressure — just the next small move.';
      case 'excited':
        return '$message\n\nUse the momentum, but keep the scope clear.';
      default:
        return message;
    }
  }

  String _constrain(
    String message,
    InstinctGuidance instinct,
    SIDecision decision,
  ) {
    final int max = (!decision.safe || instinct.safetyFirst)
        ? 220
        : instinct.avoidOverwhelm
        ? 260
        : 420;
    final String softened = message
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could');
    return _truncate(softened, max);
  }

  String _identity(String message, IdentityState? identityState) {
    if (identityState == null) return message;
    try {
      final String result = const IdentityEngine()
          .reinforceIdentity(identityState, message)
          .trim();
      return result.isEmpty ? message : result;
    } catch (_) {
      return message;
    }
  }

  String _truncate(String text, int max) {
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    final String cut = clean.substring(0, max).trim();
    final int period = cut.lastIndexOf(RegExp(r'[.!?]'));
    if (period > 80) return cut.substring(0, period + 1);
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
