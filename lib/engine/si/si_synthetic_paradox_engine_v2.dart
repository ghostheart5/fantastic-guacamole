// lib/engine/si/si_synthetic_paradox_engine_v2.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIParadoxV2 {
  const SIParadoxV2({
    required this.detected,
    required this.code,
    required this.severity,
    required this.memory,
  });
  final bool detected;
  final String code;
  final double severity;
  final SIMemoryStore memory;
}

class SISyntheticParadoxEngineV2 {
  const SISyntheticParadoxEngineV2();

  SIParadoxV2 detect({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    SIDecision? decision,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    String code = 'none';
    double sev = 0;
    if (instinct.safetyFirst &&
        decision != null &&
        decision.action != 'respond_conversationally') {
      code = 'safety_vs_action';
      sev = .75;
    } else if (intent.confidence < .45 &&
        decision != null &&
        decision.action != 'respond_conversationally') {
      code = 'uncertainty_vs_action';
      sev = .55;
    }
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'paradox_v2|$code|severity=${sev.toStringAsFixed(2)}',
            timestamp: t,
            relevance: sev,
            confidence: .7,
            emotionalWeight: sev,
          ),
        )
        .dedupe()
        .decay(t);
    return SIParadoxV2(
      detected: sev >= .45,
      code: code,
      severity: siClamp01(sev),
      memory: next,
    );
  }
}
