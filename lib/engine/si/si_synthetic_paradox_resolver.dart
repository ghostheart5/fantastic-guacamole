// lib/engine/si/si_synthetic_paradox_resolver.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_paradox_engine_v2.dart';

class SIParadoxResolution {
  const SIParadoxResolution({
    required this.resolved,
    required this.action,
    required this.message,
    required this.memory,
  });
  final bool resolved;
  final String action;
  final String message;
  final SIMemoryStore memory;
}

class SISyntheticParadoxResolver {
  const SISyntheticParadoxResolver();

  SIParadoxResolution resolve({
    required SIParadoxV2 paradox,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final action = paradox.detected ? 'respond_conversationally' : 'continue';
    final msg = paradox.code == 'safety_vs_action'
        ? 'Let’s pause and choose one safe next step.'
        : paradox.code == 'uncertainty_vs_action'
        ? 'I need one detail before acting.'
        : 'No paradox adjustment needed.';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'paradox_resolution|${paradox.code}|action=$action',
            timestamp: t,
            relevance: paradox.severity,
            confidence: .7,
            emotionalWeight: paradox.severity,
          ),
        )
        .dedupe()
        .decay(t);
    return SIParadoxResolution(
      resolved: true,
      action: action,
      message: msg,
      memory: next,
    );
  }
}
