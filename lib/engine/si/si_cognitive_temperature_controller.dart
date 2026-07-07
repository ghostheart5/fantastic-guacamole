// lib/engine/si/si_cognitive_temperature_controller.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CognitiveTemperature {
  const CognitiveTemperature({
    required this.responseIntensity,
    required this.variation,
    required this.directness,
    required this.empathy,
    required this.maxOutputLoad,
  });

  final double responseIntensity;
  final double variation;
  final double directness;
  final double empathy;
  final double maxOutputLoad;
}

class SICognitiveTemperatureController {
  const SICognitiveTemperatureController();

  CognitiveTemperature regulate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    SIDecision? decision,
  }) {
    final double stress = siClamp01(context.userState.stress);
    final double load = siClamp01(context.userState.cognitiveLoad);
    final double confidence = siClamp01(
      decision?.confidence ?? intent.confidence,
    );
    final double risk = siClamp01(cognition?.meta.misunderstandingRisk ?? 0.35);

    double intensity = 0.45;
    double variation = 0.35;
    double directness = 0.7;
    double empathy = 0.7;
    double maxLoad = 0.55;

    if (intent.primary.label == 'start_focus' ||
        intent.primary.label == 'get_task') {
      directness += 0.12;
      intensity += 0.08;
    }

    if (intent.primary.label == 'insight_request') {
      variation += 0.1;
      directness -= 0.05;
    }

    if (stress >= 0.65 || instinct.safetyFirst) {
      intensity -= 0.22;
      variation -= 0.14;
      directness -= 0.08;
      empathy += 0.18;
      maxLoad -= 0.2;
    }

    if (load >= 0.7 || instinct.avoidOverwhelm) {
      intensity -= 0.12;
      variation -= 0.1;
      maxLoad -= 0.18;
    }

    if (confidence >= 0.75 && risk < 0.35 && !instinct.safetyFirst) {
      intensity += 0.1;
      directness += 0.08;
      maxLoad += 0.08;
    }

    if (decision != null && !decision.safe) {
      intensity = 0.15;
      variation = 0.1;
      directness = 0.45;
      empathy = 0.95;
      maxLoad = 0.25;
    }

    return CognitiveTemperature(
      responseIntensity: siClamp01(intensity),
      variation: siClamp01(variation),
      directness: siClamp01(directness),
      empathy: siClamp01(empathy),
      maxOutputLoad: siClamp01(maxLoad),
    );
  }

  int maxWords(CognitiveTemperature temperature) {
    final double load = siClamp01(temperature.maxOutputLoad);
    if (load <= 0.3) return 38;
    if (load <= 0.45) return 58;
    if (load <= 0.65) return 86;
    return 120;
  }

  String intensityLabel(CognitiveTemperature temperature) {
    final double value = siClamp01(temperature.responseIntensity);
    if (value < 0.25) return 'low';
    if (value < 0.55) return 'steady';
    if (value < 0.78) return 'active';
    return 'high';
  }
}
