// lib/engine/si/si_cognitive_resonance_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class ResonanceProfile {
  const ResonanceProfile({
    required this.alignmentScore,
    required this.stateLabel,
    required this.emphasis,
    required this.guidance,
    required this.warnings,
  });

  final double alignmentScore;
  final String stateLabel;
  final List<String> emphasis;
  final String guidance;
  final List<String> warnings;

  bool get aligned => alignmentScore >= 0.65;
}

class SICognitiveResonanceEngine {
  const SICognitiveResonanceEngine();

  ResonanceProfile resonate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIDecision? decision,
  }) {
    final SIUserState user = context.userState;
    final List<String> emphasis = <String>[];
    final List<String> warnings = <String>[];

    double score = 0.65;

    if (instinct.safetyFirst) {
      emphasis.add('stability');
      score -= 0.08;
    }

    if (user.stress >= 0.65) {
      emphasis.add('calm');
      warnings.add('stress_high');
      score -= 0.08;
    }

    if (user.cognitiveLoad >= 0.7) {
      emphasis.add('simplicity');
      warnings.add('cognitive_load_high');
      score -= 0.08;
    }

    if (user.motivation >= 0.65 && !instinct.avoidOverwhelm) {
      emphasis.add('momentum');
      score += 0.08;
    }

    if (intent.primary.label == 'get_task' ||
        intent.primary.label == 'start_focus') {
      emphasis.add('next_action');
      score += 0.05;
    }

    if (decision != null && !decision.safe) {
      emphasis.add('safety');
      warnings.add('decision_unsafe');
      score -= 0.2;
    }

    return ResonanceProfile(
      alignmentScore: siClamp01(score),
      stateLabel: _stateLabel(user, instinct),
      emphasis: List<String>.unmodifiable(emphasis.toSet()),
      guidance: _guidance(user, instinct, intent),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  String _stateLabel(SIUserState user, InstinctGuidance instinct) {
    if (instinct.safetyFirst) return 'stabilize';
    if (user.stress >= 0.65) return 'calm';
    if (user.cognitiveLoad >= 0.7) return 'simplify';
    if (user.motivation >= 0.7) return 'momentum';
    return 'steady';
  }

  String _guidance(
    SIUserState user,
    InstinctGuidance instinct,
    SIIntent intent,
  ) {
    if (instinct.safetyFirst) return 'Use a calm, low-pressure response.';
    if (user.cognitiveLoad >= 0.7) {
      return 'Reduce complexity and give one step.';
    }
    if (intent.primary.label == 'insight_request') {
      return 'Explain the pattern briefly.';
    }
    if (intent.primary.label == 'get_task') {
      return 'Recommend one action with a short reason.';
    }
    return 'Keep the response practical and supportive.';
  }
}
