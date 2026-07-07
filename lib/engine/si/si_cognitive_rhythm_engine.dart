// lib/engine/si/si_cognitive_rhythm_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum CognitiveRhythm { calm, steady, focused, overloaded, recovering }

class RhythmReport {
  const RhythmReport({
    required this.rhythm,
    required this.cadence,
    required this.cycleStrength,
    required this.recommendation,
    required this.memory,
  });

  final CognitiveRhythm rhythm;
  final double cadence;
  final double cycleStrength;
  final String recommendation;
  final SIMemoryStore memory;
}

class SICognitiveRhythmEngine {
  const SICognitiveRhythmEngine();

  RhythmReport detect({
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final double cadence = _cadence(memory);
    final double cycle = _cycle(memory);
    final CognitiveRhythm rhythm = _rhythm(context, cadence, cycle);

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'cognitive_rhythm|${rhythm.name}|cadence=${cadence.toStringAsFixed(2)}|cycle=${cycle.toStringAsFixed(2)}',
            timestamp: t,
            relevance: cadence,
            confidence: memory.snapshots.length >= 4 ? 0.72 : 0.45,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: rhythm == CognitiveRhythm.focused ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return RhythmReport(
      rhythm: rhythm,
      cadence: cadence,
      cycleStrength: cycle,
      recommendation: _recommendation(rhythm),
      memory: next,
    );
  }

  double _cadence(SIMemoryStore memory) {
    final List<SISnapshot> s = memory.snapshots.take(12).toList();
    if (s.length < 2) return 0.5;
    final int completed = s.fold<int>(
      0,
      (int sum, SISnapshot x) => sum + x.completed,
    );
    final int skipped = s.fold<int>(
      0,
      (int sum, SISnapshot x) => sum + x.skipped,
    );
    return siClamp01((completed + 1) / (completed + skipped + 2));
  }

  double _cycle(SIMemoryStore memory) {
    final Map<String, int> hits = <String, int>{};
    for (final SISnapshot s in memory.snapshots.take(24)) {
      final String id = siClean(s.taskId);
      if (id.isNotEmpty) hits[id] = (hits[id] ?? 0) + 1;
    }
    if (hits.isEmpty) return 0.2;
    return siClamp01(hits.values.reduce((int a, int b) => a > b ? a : b) / 6);
  }

  CognitiveRhythm _rhythm(SIContext context, double cadence, double cycle) {
    if (context.userState.stress >= 0.7 ||
        context.userState.cognitiveLoad >= 0.75) {
      return CognitiveRhythm.overloaded;
    }
    if (context.userState.fatigue >= 0.68) return CognitiveRhythm.recovering;
    if (cadence >= 0.68 && context.userState.engagement >= 0.65) {
      return CognitiveRhythm.focused;
    }
    if (cadence >= 0.48) return CognitiveRhythm.steady;
    return CognitiveRhythm.calm;
  }

  String _recommendation(CognitiveRhythm rhythm) {
    switch (rhythm) {
      case CognitiveRhythm.overloaded:
        return 'Reduce output and choose one small step.';
      case CognitiveRhythm.recovering:
        return 'Use lighter pacing and shorter sessions.';
      case CognitiveRhythm.focused:
        return 'Protect the focus window.';
      case CognitiveRhythm.steady:
        return 'Keep the next action clear and consistent.';
      case CognitiveRhythm.calm:
        return 'Build momentum gently.';
    }
  }
}
