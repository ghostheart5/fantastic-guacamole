// lib/engine/si/si_synthetic_temporal_loop_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SITemporalLoop {
  const SITemporalLoop({
    required this.detected,
    required this.loopKey,
    required this.strength,
    required this.advice,
    required this.memory,
  });
  final bool detected;
  final String loopKey;
  final double strength;
  final String advice;
  final SIMemoryStore memory;
}

class SISyntheticTemporalLoopEngine {
  const SISyntheticTemporalLoopEngine();

  SITemporalLoop detect({
    required SIMemoryStore memory,
    required SIContext context,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final counts = <String, int>{};
    for (final s in memory.snapshots.take(24)) {
      final key = siClean(s.taskId);
      if (key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
    }
    final entry = counts.entries.isEmpty
        ? const MapEntry('none', 0)
        : (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .first;
    final strength = siClamp01(entry.value / 6);
    final detected = strength >= .5;
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'temporal_loop|key=${entry.key}|strength=${strength.toStringAsFixed(2)}',
            timestamp: t,
            relevance: strength,
            confidence: memory.snapshots.length >= 4 ? .7 : .42,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SITemporalLoop(
      detected: detected,
      loopKey: entry.key,
      strength: strength,
      advice: detected
          ? 'Use the loop intentionally or shrink the repeated task.'
          : 'No strong loop detected.',
      memory: next,
    );
  }
}
