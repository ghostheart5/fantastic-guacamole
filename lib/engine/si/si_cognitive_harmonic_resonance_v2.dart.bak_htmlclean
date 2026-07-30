// lib/engine/si/si_cognitive_harmonic_resonance_v2.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class HarmonicResonanceV2 {
  const HarmonicResonanceV2({
    required this.clarity,
    required this.safety,
    required this.momentum,
    required this.resonance,
    required this.outputMode,
  });

  final double clarity;
  final double safety;
  final double momentum;
  final double resonance;
  final String outputMode;
}

class SICognitiveHarmonicResonanceV2 {
  const SICognitiveHarmonicResonanceV2();

  HarmonicResonanceV2 tune({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
  }) {
    final double clarity = siClamp01(
      (intent.confidence +
              (1 - (cognition?.meta.misunderstandingRisk ?? 0.35))) /
          2,
    );
    final double safety = siClamp01(
      instinct.safetyFirst ? 0.95 : 1 - context.userState.stress * 0.45,
    );
    final double momentum = siClamp01(
      (context.userState.motivation +
              context.userState.engagement +
              (1 - context.userState.fatigue)) /
          3,
    );
    final double resonance = siClamp01(
      (clarity * 0.35) + (safety * 0.35) + (momentum * 0.3),
    );

    return HarmonicResonanceV2(
      clarity: clarity,
      safety: safety,
      momentum: momentum,
      resonance: resonance,
      outputMode: instinct.safetyFirst || safety < 0.55
          ? 'calm_minimal'
          : resonance >= 0.72
          ? 'confident_action'
          : 'steady_guidance',
    );
  }

  String apply(String message, HarmonicResonanceV2 resonance) {
    final String clean = siClean(message);
    if (resonance.outputMode == 'calm_minimal' && !clean.contains('One step')) {
      return '$clean\n\nOne step is enough.';
    }
    return clean;
  }
}
