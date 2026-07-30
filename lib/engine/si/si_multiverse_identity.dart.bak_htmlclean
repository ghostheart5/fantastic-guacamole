// lib/engine/si/si_multiverse_identity.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIMultiverseIdentityProfile {
  const SIMultiverseIdentityProfile({
    required this.mode,
    required this.identityLabel,
    required this.weight,
    required this.responseBias,
    required this.memory,
  });

  final String mode;
  final String identityLabel;
  final double weight;
  final String responseBias;
  final SIMemoryStore memory;
}

class SIMultiverseIdentity {
  const SIMultiverseIdentity();

  SIMultiverseIdentityProfile resolve({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final String mode = instinct.safetyFirst
        ? 'guardian'
        : context.userState.fatigue >= .68
        ? 'restorer'
        : intent.primary.label == 'insight_request'
        ? 'analyst'
        : intent.primary.label == 'get_task' ||
              intent.primary.label == 'start_focus'
        ? 'builder'
        : 'guide';

    final String label = 'chronospark_$mode';
    final double weight = siClamp01(
      intent.confidence * .35 +
          context.userState.engagement * .3 +
          (1 - context.userState.stress) * .35,
    );

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'multiverse_identity|mode=$mode|label=$label|weight=${weight.toStringAsFixed(2)}',
            timestamp: t,
            relevance: weight,
            confidence: .72,
            emotionalWeight: context.userState.stress,
            reinforcement: mode == 'builder' ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return SIMultiverseIdentityProfile(
      mode: mode,
      identityLabel: label,
      weight: weight,
      responseBias: _bias(mode),
      memory: next,
    );
  }

  String _bias(String mode) {
    switch (mode) {
      case 'guardian':
        return 'calm, safe, low-pressure';
      case 'restorer':
        return 'recovery-first, minimal scope';
      case 'analyst':
        return 'pattern-focused, concise';
      case 'builder':
        return 'action-first, momentum-aware';
      default:
        return 'supportive, clear, practical';
    }
  }
}
