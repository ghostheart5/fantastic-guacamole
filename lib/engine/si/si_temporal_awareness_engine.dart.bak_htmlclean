// lib/engine/si/si_temporal_awareness_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum TemporalTrend { improving, declining, stable, insufficientData }

class TemporalCycle {
  const TemporalCycle({
    required this.label,
    required this.strength,
    required this.evidence,
  });

  final String label;
  final double strength;
  final List<String> evidence;
}

class TemporalAwarenessReport {
  const TemporalAwarenessReport({
    required this.recencyBias,
    required this.momentum,
    required this.trend,
    required this.cycles,
    required this.timingAdvice,
    required this.memory,
  });

  final double recencyBias;
  final double momentum;
  final TemporalTrend trend;
  final List<TemporalCycle> cycles;
  final String timingAdvice;
  final SIMemoryStore memory;
}

class SITemporalAwarenessEngine {
  const SITemporalAwarenessEngine();

  TemporalAwarenessReport analyze({
    required SIMemoryStore memory,
    required SIContext context,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<SISnapshot> snapshots = memory.snapshots.take(24).toList();

    final double recency = _recencyBias(memory, t);
    final double momentum = _momentum(snapshots);
    final TemporalTrend trend = _trend(snapshots);
    final List<TemporalCycle> cycles = _cycles(snapshots);
    final String advice = _advice(trend, momentum, context);

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'temporal_awareness|trend=${trend.name}|momentum=${momentum.toStringAsFixed(2)}|cycles=${cycles.length}|$advice',
            timestamp: t,
            relevance: siClamp01((recency + momentum) / 2),
            confidence: snapshots.length >= 4 ? 0.72 : 0.42,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: trend == TemporalTrend.improving ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return TemporalAwarenessReport(
      recencyBias: recency,
      momentum: momentum,
      trend: trend,
      cycles: List<TemporalCycle>.unmodifiable(cycles),
      timingAdvice: advice,
      memory: nextMemory,
    );
  }

  double _recencyBias(SIMemoryStore memory, DateTime now) {
    final List<MemoryRecord> records = <MemoryRecord>[
      ...memory.tiered.shortTerm,
      ...memory.tiered.midTerm,
      ...memory.tiered.longTerm,
    ];
    if (records.isEmpty) return 0.5;
    final double avg =
        records.fold<double>(
          0,
          (double s, MemoryRecord r) => s + r.score(now),
        ) /
        records.length;
    return siClamp01(avg);
  }

  double _momentum(List<SISnapshot> snapshots) {
    if (snapshots.length < 2) return 0.5;
    final int completed = snapshots.fold<int>(
      0,
      (int s, SISnapshot x) => s + x.completed,
    );
    final int skipped = snapshots.fold<int>(
      0,
      (int s, SISnapshot x) => s + x.skipped,
    );
    return siClamp01((completed + 1) / (completed + skipped + 2));
  }

  TemporalTrend _trend(List<SISnapshot> snapshots) {
    if (snapshots.length < 4) return TemporalTrend.insufficientData;
    final List<SISnapshot> recent = snapshots
        .take(snapshots.length ~/ 2)
        .toList();
    final List<SISnapshot> older = snapshots
        .skip(snapshots.length ~/ 2)
        .toList();

    double quality(List<SISnapshot> items) {
      final int done = items.fold<int>(
        0,
        (int s, SISnapshot x) => s + x.completed,
      );
      final int skip = items.fold<int>(
        0,
        (int s, SISnapshot x) => s + x.skipped,
      );
      final double energy =
          items.fold<double>(
            0,
            (double s, SISnapshot x) => s + siClamp01(x.energy),
          ) /
          items.length;
      final double fatigue =
          items.fold<double>(
            0,
            (double s, SISnapshot x) => s + siClamp01(x.fatigue),
          ) /
          items.length;
      return siClamp01(
        ((done + 1) / (done + skip + 2)) * 0.6 +
            energy * 0.25 +
            (1 - fatigue) * 0.15,
      );
    }

    final double delta = quality(recent) - quality(older);
    if (delta >= 0.08) return TemporalTrend.improving;
    if (delta <= -0.08) return TemporalTrend.declining;
    return TemporalTrend.stable;
  }

  List<TemporalCycle> _cycles(List<SISnapshot> snapshots) {
    final Map<String, int> taskHits = <String, int>{};
    for (final SISnapshot s in snapshots) {
      final String id = siClean(s.taskId);
      if (id.isNotEmpty) taskHits[id] = (taskHits[id] ?? 0) + 1;
    }

    return taskHits.entries
        .where((MapEntry<String, int> e) => e.value >= 3)
        .map(
          (MapEntry<String, int> e) => TemporalCycle(
            label: 'repeating_task:${e.key}',
            strength: siClamp01(e.value / snapshots.length),
            evidence: <String>['hits=${e.value}', 'window=${snapshots.length}'],
          ),
        )
        .toList();
  }

  String _advice(TemporalTrend trend, double momentum, SIContext context) {
    if (context.userState.fatigue >= 0.7) {
      return 'Use shorter sessions and protect recovery.';
    }
    if (trend == TemporalTrend.improving && momentum >= 0.65) {
      return 'Use current momentum for one focused action.';
    }
    if (trend == TemporalTrend.declining) {
      return 'Reduce scope and rebuild consistency.';
    }
    if (trend == TemporalTrend.insufficientData) {
      return 'Collect more activity before making strong timing claims.';
    }
    return 'Keep timing steady and avoid overloading the next action.';
  }
}
