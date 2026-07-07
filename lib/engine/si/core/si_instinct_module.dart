// lib/engine/si/core/si_instinct_module.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIInstinctModule {
  const SIInstinctModule();

  InstinctGuidance evaluate({
    required SIContext context,
    required SIIntent intent,
  }) {
    final SIUserState user = context.userState;
    final double confidence = siClamp01(intent.confidence);
    final String mood = siNormalizeMood(user.emotion);

    final bool lowConfidence = confidence < 0.55;
    final bool emotionalRisk =
        mood == 'stressed' ||
        mood == 'confused' ||
        mood == 'frustrated' ||
        user.stress >= 0.65 ||
        user.cognitiveLoad >= 0.72;

    final bool confusionRisk =
        lowConfidence ||
        mood == 'confused' ||
        user.cognitiveLoad >= 0.7 ||
        intent.isComplex;

    final bool overwhelmed =
        emotionalRisk ||
        context.input.latent.hesitation >= 0.65 ||
        context.input.latent.confusion >= 0.65;

    return InstinctGuidance(
      protectUser: emotionalRisk || lowConfidence,
      reduceConfusion: confusionRisk,
      increaseClarity: true,
      maintainEmotionalSafety: emotionalRisk,
      avoidOverwhelm: overwhelmed,
      encourageProgress: !overwhelmed || confidence >= 0.7,
      maintainContinuity: confidence >= 0.4,
      primaryInstinct: _primary(
        emotionalRisk: emotionalRisk,
        overwhelmed: overwhelmed,
        confidence: confidence,
      ),
    );
  }

  String _primary({
    required bool emotionalRisk,
    required bool overwhelmed,
    required double confidence,
  }) {
    if (emotionalRisk || overwhelmed) return 'safety_first';
    if (confidence < 0.4) return 'stabilize_first';
    return 'progress_first';
  }
}
