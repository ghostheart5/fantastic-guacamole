// lib/engine/si/si_cognitive_micro_pattern_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum MicroPatternType {
  completionMomentum,
  skipResistance,
  fatigueDrift,
  highLoadLoop,
  stableFocus,
  repeatedTopic,
  taskAffinity,
}

class MicroPattern {
  const MicroPattern({
    required this.type,
    required this.label,
    required this.strength,
    required this.confidence,
    required this.evidence,
    this.taskKey,
  });

  final MicroPatternType type;
  final String label;
  final double strength;
  final double confidence;
  final List<String> evidence;
  final String? taskKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'label': label,
    'strength': siClamp01(strength),
    'confidence': siClamp01(confidence),
    'evidence': evidence,
    'task_key': taskKey,
  };
}

class MicroPatternReport {
  const MicroPatternReport({
    required this.patterns,
    required this.predictionSignals,
    required this.summary,
  });

  final List<MicroPattern> patterns;
  final Map<String, double> predictionSignals;
  final String summary;

  bool get hasStrongPattern => patterns.any(
    (MicroPattern p) => p.strength >= 0.7 && p.confidence >= 0.55,
  );
}

class SICognitiveMicroPatternEngine {
  const SICognitiveMicroPatternEngine();

  MicroPatternReport detect({
    required SIContext context,
    required SIMemoryStore memory,
    int snapshotLimit = 12,
  }) {
    final List<SISnapshot> snapshots = memory.snapshots
        .take(snapshotLimit)
        .toList();
    final List<MicroPattern> patterns = <MicroPattern>[];

    if (snapshots.length >= 2) {
      patterns.addAll(_snapshotPatterns(snapshots));
    }

    patterns.addAll(_recordPatterns(memory.tiered.shortTerm));
    patterns.addAll(_contextPatterns(context));

    final List<MicroPattern> unique = _dedupe(patterns);
    final Map<String, double> signals = _predictionSignals(unique);

    return MicroPatternReport(
      patterns: List<MicroPattern>.unmodifiable(unique),
      predictionSignals: Map<String, double>.unmodifiable(signals),
      summary: _summary(unique),
    );
  }

  SIMemoryStore writeToMemory({
    required SIMemoryStore memory,
    required MicroPatternReport report,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    SIMemoryStore next = memory;

    for (final MicroPattern pattern in report.patterns.take(8)) {
      next = next.pushRecord(
        pattern.strength >= 0.72 ? MemoryTier.midTerm : MemoryTier.shortTerm,
        MemoryRecord(
          content:
              'pattern|${pattern.type.name}|${pattern.label}|task=${pattern.taskKey ?? ''}',
          timestamp: timestamp,
          relevance: pattern.strength,
          recency: 1.0,
          confidence: pattern.confidence,
          emotionalWeight: pattern.type == MicroPatternType.fatigueDrift
              ? 0.75
              : 0.45,
          reinforcement: pattern.strength >= 0.75 ? 2 : 1,
        ),
      );
    }

    return next.dedupe().decay(timestamp);
  }

  List<MicroPattern> _snapshotPatterns(List<SISnapshot> snapshots) {
    final int completed = snapshots.fold<int>(
      0,
      (int sum, SISnapshot s) => sum + s.completed,
    );
    final int skipped = snapshots.fold<int>(
      0,
      (int sum, SISnapshot s) => sum + s.skipped,
    );
    final double avgEnergy =
        snapshots.fold<double>(
          0,
          (double sum, SISnapshot s) => sum + siClamp01(s.energy),
        ) /
        snapshots.length;
    final double avgFatigue =
        snapshots.fold<double>(
          0,
          (double sum, SISnapshot s) => sum + siClamp01(s.fatigue),
        ) /
        snapshots.length;

    final List<MicroPattern> out = <MicroPattern>[];

    if (completed > skipped && completed >= 2) {
      out.add(
        MicroPattern(
          type: MicroPatternType.completionMomentum,
          label: 'Completion momentum is forming',
          strength: siClamp01(completed / (completed + skipped + 1)),
          confidence: _sampleConfidence(snapshots.length),
          evidence: <String>['completed=$completed', 'skipped=$skipped'],
        ),
      );
    }

    if (skipped > completed && skipped >= 2) {
      out.add(
        MicroPattern(
          type: MicroPatternType.skipResistance,
          label: 'Task resistance or overload may be forming',
          strength: siClamp01(skipped / (completed + skipped + 1)),
          confidence: _sampleConfidence(snapshots.length),
          evidence: <String>['completed=$completed', 'skipped=$skipped'],
        ),
      );
    }

    if (avgFatigue >= 0.65 && avgEnergy <= 0.45) {
      out.add(
        MicroPattern(
          type: MicroPatternType.fatigueDrift,
          label: 'Fatigue drift detected',
          strength: siClamp01((avgFatigue + (1 - avgEnergy)) / 2),
          confidence: _sampleConfidence(snapshots.length),
          evidence: <String>[
            'avg_fatigue=${avgFatigue.toStringAsFixed(2)}',
            'avg_energy=${avgEnergy.toStringAsFixed(2)}',
          ],
        ),
      );
    }

    final Map<String, int> taskHits = <String, int>{};
    for (final SISnapshot s in snapshots) {
      final String key = siClean(s.taskId);
      if (key.isNotEmpty) taskHits[key] = (taskHits[key] ?? 0) + 1;
    }

    for (final MapEntry<String, int> entry in taskHits.entries) {
      if (entry.value >= 2) {
        out.add(
          MicroPattern(
            type: MicroPatternType.taskAffinity,
            label: 'Repeated task focus detected',
            strength: siClamp01(entry.value / snapshots.length),
            confidence: _sampleConfidence(entry.value),
            evidence: <String>['task=${entry.key}', 'hits=${entry.value}'],
            taskKey: entry.key,
          ),
        );
      }
    }

    return out;
  }

  List<MicroPattern> _recordPatterns(List<MemoryRecord> records) {
    final Map<String, int> topicCounts = <String, int>{};

    for (final MemoryRecord record in records.take(20)) {
      final String content = siClean(record.content).toLowerCase();
      if (content.startsWith('pattern|')) continue;

      for (final String token in content.split(RegExp(r'[^a-z0-9_]+'))) {
        if (token.length < 5) continue;
        topicCounts[token] = (topicCounts[token] ?? 0) + 1;
      }
    }

    return topicCounts.entries
        .where((MapEntry<String, int> e) => e.value >= 3)
        .take(4)
        .map((MapEntry<String, int> e) {
          return MicroPattern(
            type: MicroPatternType.repeatedTopic,
            label: 'Repeated topic: ${e.key}',
            strength: siClamp01(e.value / 8),
            confidence: siClamp01(e.value / 5),
            evidence: <String>['mentions=${e.value}'],
            taskKey: e.key,
          );
        })
        .toList();
  }

  List<MicroPattern> _contextPatterns(SIContext context) {
    final List<MicroPattern> out = <MicroPattern>[];
    final SIUserState u = context.userState;

    if (u.cognitiveLoad >= 0.72 && u.stress >= 0.6) {
      out.add(
        MicroPattern(
          type: MicroPatternType.highLoadLoop,
          label: 'High-load loop detected',
          strength: siClamp01((u.cognitiveLoad + u.stress) / 2),
          confidence: 0.65,
          evidence: <String>[
            'load=${u.cognitiveLoad.toStringAsFixed(2)}',
            'stress=${u.stress.toStringAsFixed(2)}',
          ],
        ),
      );
    }

    if (u.engagement >= 0.65 && u.fatigue <= 0.45 && u.stress <= 0.45) {
      out.add(
        MicroPattern(
          type: MicroPatternType.stableFocus,
          label: 'Stable focus window',
          strength: siClamp01(
            (u.engagement + (1 - u.fatigue) + (1 - u.stress)) / 3,
          ),
          confidence: 0.6,
          evidence: <String>['engagement_high', 'fatigue_low', 'stress_low'],
        ),
      );
    }

    return out;
  }

  List<MicroPattern> _dedupe(List<MicroPattern> patterns) {
    final Map<String, MicroPattern> byKey = <String, MicroPattern>{};

    for (final MicroPattern p in patterns) {
      final String key = '${p.type.name}:${p.taskKey ?? p.label}';
      final MicroPattern? existing = byKey[key];
      if (existing == null || p.strength > existing.strength) {
        byKey[key] = p;
      }
    }

    return byKey.values.toList()..sort(
      (MicroPattern a, MicroPattern b) => b.strength.compareTo(a.strength),
    );
  }

  Map<String, double> _predictionSignals(List<MicroPattern> patterns) {
    final Map<String, double> signals = <String, double>{};

    for (final MicroPattern p in patterns) {
      switch (p.type) {
        case MicroPatternType.completionMomentum:
          signals['momentum_bias'] = siClamp01(p.strength);
          break;
        case MicroPatternType.skipResistance:
          signals['resistance_bias'] = siClamp01(p.strength);
          break;
        case MicroPatternType.fatigueDrift:
          signals['fatigue_bias'] = siClamp01(p.strength);
          break;
        case MicroPatternType.stableFocus:
          signals['focus_bias'] = siClamp01(p.strength);
          break;
        case MicroPatternType.taskAffinity:
          if (p.taskKey != null) {
            signals['task:${p.taskKey}'] = siClamp01(p.strength);
          }
          break;
        case MicroPatternType.highLoadLoop:
          signals['load_risk'] = siClamp01(p.strength);
          break;
        case MicroPatternType.repeatedTopic:
          if (p.taskKey != null) {
            signals['topic:${p.taskKey}'] = siClamp01(p.strength);
          }
          break;
      }
    }

    return signals;
  }

  String _summary(List<MicroPattern> patterns) {
    if (patterns.isEmpty) return 'No strong micro-patterns detected yet.';
    return patterns.take(3).map((MicroPattern p) => p.label).join(' · ');
  }

  double _sampleConfidence(int samples) {
    return siClamp01(samples / 5, fallback: 0.3);
  }
}
