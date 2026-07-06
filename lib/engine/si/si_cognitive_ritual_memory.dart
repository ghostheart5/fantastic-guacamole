// lib/engine/si/si_ritual_memory_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class RitualMemory {
  const RitualMemory({
    required this.name,
    required this.trigger,
    required this.action,
    required this.strength,
    required this.evidence,
  });

  final String name;
  final String trigger;
  final String action;
  final double strength;
  final List<String> evidence;
}

class RitualMemoryReport {
  const RitualMemoryReport({
    required this.rituals,
    required this.primary,
    required this.memory,
  });

  final List<RitualMemory> rituals;
  final RitualMemory? primary;
  final SIMemoryStore memory;
}

class SIRitualMemoryEngine {
  const SIRitualMemoryEngine();

  RitualMemoryReport detect({
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<RitualMemory> rituals = <RitualMemory>[];

    final int completed = memory.snapshots
        .take(10)
        .fold<int>(0, (int s, SISnapshot x) => s + x.completed);
    final int skipped = memory.snapshots
        .take(10)
        .fold<int>(0, (int s, SISnapshot x) => s + x.skipped);

    if (completed >= 3 && completed > skipped) {
      rituals.add(
        RitualMemory(
          name: 'focus_start_ritual',
          trigger: 'momentum_available',
          action: 'start_one_short_focus_block',
          strength: siClamp01(completed / (completed + skipped + 1)),
          evidence: <String>['completed=$completed', 'skipped=$skipped'],
        ),
      );
    }

    if (context.userState.fatigue >= 0.68) {
      rituals.add(
        RitualMemory(
          name: 'recovery_ritual',
          trigger: 'fatigue_high',
          action: 'shrink_next_step_and_reassess',
          strength: context.userState.fatigue,
          evidence: <String>[
            'fatigue=${context.userState.fatigue.toStringAsFixed(2)}',
          ],
        ),
      );
    }

    rituals.sort(
      (RitualMemory a, RitualMemory b) => b.strength.compareTo(a.strength),
    );
    final RitualMemory? primary = rituals.isEmpty ? null : rituals.first;

    SIMemoryStore next = memory;
    if (primary != null) {
      next = next
          .pushRecord(
            MemoryTier.longTerm,
            MemoryRecord(
              content:
                  'ritual|${primary.name}|trigger=${primary.trigger}|action=${primary.action}',
              timestamp: t,
              relevance: primary.strength,
              confidence: 0.7,
              emotionalWeight: context.userState.fatigue,
              reinforcement: primary.strength >= 0.7 ? 2 : 1,
            ),
          )
          .dedupe()
          .decay(t);
    }

    return RitualMemoryReport(
      rituals: List<RitualMemory>.unmodifiable(rituals),
      primary: primary,
      memory: next,
    );
  }
}
