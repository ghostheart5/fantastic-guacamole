// lib/engine/si/si_cognitive_phase_shift_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum SIPhase { stabilize, clarify, act, reflect, analyze, recover }

class PhaseShiftPlan {
  const PhaseShiftPlan({
    required this.phase,
    required this.previousPhase,
    required this.changed,
    required this.reason,
    required this.intensity,
  });

  final SIPhase phase;
  final SIPhase? previousPhase;
  final bool changed;
  final String reason;
  final double intensity;
}

class SICognitivePhaseShiftEngine {
  const SICognitivePhaseShiftEngine();

  PhaseShiftPlan shift({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    SIPhase? previousPhase,
  }) {
    final double stress = siClamp01(context.userState.stress);
    final double load = siClamp01(context.userState.cognitiveLoad);
    final double risk = siClamp01(cognition?.meta.misunderstandingRisk ?? 0.35);

    late final SIPhase next;
    late final String reason;
    late final double intensity;

    if (instinct.safetyFirst || stress >= 0.72) {
      next = SIPhase.stabilize;
      reason = 'Safety or stress requires stabilization.';
      intensity = 0.85;
    } else if (intent.confidence < 0.5 ||
        risk >= 0.65 ||
        instinct.reduceConfusion) {
      next = SIPhase.clarify;
      reason = 'Uncertainty requires clarification.';
      intensity = 0.65;
    } else if (intent.primary.label == 'reflect') {
      next = SIPhase.reflect;
      reason = 'Reflection intent detected.';
      intensity = 0.55;
    } else if (intent.primary.label == 'insight_request') {
      next = SIPhase.analyze;
      reason = 'Insight request detected.';
      intensity = 0.6;
    } else if (load >= 0.75) {
      next = SIPhase.recover;
      reason = 'High cognitive load suggests recovery pacing.';
      intensity = 0.7;
    } else {
      next = SIPhase.act;
      reason = 'State supports action.';
      intensity = 0.55;
    }

    return PhaseShiftPlan(
      phase: next,
      previousPhase: previousPhase,
      changed: previousPhase != next,
      reason: reason,
      intensity: siClamp01(intensity),
    );
  }

  String phaseInstruction(SIPhase phase) {
    switch (phase) {
      case SIPhase.stabilize:
        return 'Use calm tone and one small step.';
      case SIPhase.clarify:
        return 'Ask one short question or offer a safe default.';
      case SIPhase.act:
        return 'Recommend one action with a short reason.';
      case SIPhase.reflect:
        return 'Guide review without judgment.';
      case SIPhase.analyze:
        return 'Surface one practical pattern.';
      case SIPhase.recover:
        return 'Reduce scope and prioritize recovery.';
    }
  }
}
