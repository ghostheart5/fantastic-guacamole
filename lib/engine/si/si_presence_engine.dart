// lib/engine/si/si_presence_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';

enum PresenceMode { quiet, steady, active, directive }

class PresenceProfile {
  const PresenceProfile({
    required this.mode,
    required this.assertiveness,
    required this.warmth,
    required this.guidanceDensity,
    required this.allowNudge,
    required this.reason,
  });

  final PresenceMode mode;
  final double assertiveness;
  final double warmth;
  final double guidanceDensity;
  final bool allowNudge;
  final String reason;
}

class SIPresenceEngine {
  const SIPresenceEngine();

  PresenceProfile calibrate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    CognitiveTemperature? temperature,
  }) {
    final double stress = siClamp01(context.userState.stress);
    final double load = siClamp01(context.userState.cognitiveLoad);
    final double confidence = siClamp01(
      cognition?.meta.misunderstandingRisk == null
          ? intent.confidence
          : 1 - cognition!.meta.misunderstandingRisk,
    );

    if (instinct.safetyFirst || stress >= 0.72) {
      return const PresenceProfile(
        mode: PresenceMode.quiet,
        assertiveness: 0.22,
        warmth: 0.92,
        guidanceDensity: 0.25,
        allowNudge: false,
        reason: 'Safety or stress requires quiet supportive presence.',
      );
    }

    if (load >= 0.7 || instinct.reduceConfusion || confidence < 0.45) {
      return const PresenceProfile(
        mode: PresenceMode.steady,
        assertiveness: 0.45,
        warmth: 0.82,
        guidanceDensity: 0.38,
        allowNudge: false,
        reason: 'Uncertainty or load requires steady clarification.',
      );
    }

    if (intent.primary.label == 'start_focus' ||
        intent.primary.label == 'get_task') {
      return PresenceProfile(
        mode: PresenceMode.directive,
        assertiveness: siClamp01(0.72 + (temperature?.directness ?? 0.0) * 0.1),
        warmth: 0.74,
        guidanceDensity: 0.62,
        allowNudge: true,
        reason: 'Action intent supports a more directive presence.',
      );
    }

    return const PresenceProfile(
      mode: PresenceMode.active,
      assertiveness: 0.58,
      warmth: 0.78,
      guidanceDensity: 0.52,
      allowNudge: true,
      reason: 'Normal state supports active assistant presence.',
    );
  }

  String applyPresence(String message, PresenceProfile profile) {
    final String clean = siClean(
      message,
      fallback: 'Tell me what you want to work on.',
    );
    switch (profile.mode) {
      case PresenceMode.quiet:
        return _truncate('$clean\n\nOne small step is enough.', 220);
      case PresenceMode.steady:
        return _truncate('$clean\n\nI’ll keep this clear.', 280);
      case PresenceMode.active:
        return _truncate(clean, 360);
      case PresenceMode.directive:
        return _truncate(clean, 340);
    }
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    final String cut = text.substring(0, max).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
