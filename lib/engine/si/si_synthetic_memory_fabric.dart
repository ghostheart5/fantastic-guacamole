// lib/engine/si/si_synthetic_memory_fabric.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class MemoryQuery {
  const MemoryQuery({
    this.tier,
    this.contains,
    this.after,
    this.before,
    this.minRelevance = 0,
    this.minConfidence = 0,
    this.limit = 20,
  });

  final MemoryTier? tier;
  final String? contains;
  final DateTime? after;
  final DateTime? before;
  final double minRelevance;
  final double minConfidence;
  final int limit;
}

class MemoryFabricResult {
  const MemoryFabricResult({
    required this.store,
    required this.changed,
    required this.summary,
  });

  final SIMemoryStore store;
  final bool changed;
  final String summary;
}

class SISyntheticMemoryFabric {
  const SISyntheticMemoryFabric();

  List<MemoryRecord> read(SIMemoryStore store, {MemoryTier? tier}) {
    if (tier == MemoryTier.shortTerm) return store.tiered.shortTerm;
    if (tier == MemoryTier.midTerm) return store.tiered.midTerm;
    if (tier == MemoryTier.longTerm) return store.tiered.longTerm;
    return <MemoryRecord>[
      ...store.tiered.shortTerm,
      ...store.tiered.midTerm,
      ...store.tiered.longTerm,
    ];
  }

  List<MemoryRecord> query(
    SIMemoryStore store,
    MemoryQuery query, {
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final String needle = siClean(query.contains).toLowerCase();

    final List<MemoryRecord> results =
        read(store, tier: query.tier).where((MemoryRecord r) {
          if (needle.isNotEmpty &&
              !siClean(r.content).toLowerCase().contains(needle)) {
            return false;
          }
          if (query.after != null && r.timestamp.isBefore(query.after!)) {
            return false;
          }
          if (query.before != null && r.timestamp.isAfter(query.before!)) {
            return false;
          }
          if (siClamp01(r.relevance) < query.minRelevance) return false;
          if (siClamp01(r.confidence) < query.minConfidence) return false;
          return true;
        }).toList()..sort(
          (MemoryRecord a, MemoryRecord b) => b.score(t).compareTo(a.score(t)),
        );

    return List<MemoryRecord>.unmodifiable(
      results.take(query.limit.clamp(1, 200)),
    );
  }

  MemoryFabricResult write({
    required SIMemoryStore store,
    required MemoryRecord record,
    MemoryTier tier = MemoryTier.shortTerm,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final SIMemoryStore next = store.pushRecord(tier, record).dedupe().decay(t);
    return MemoryFabricResult(
      store: next,
      changed: true,
      summary: 'memory_written:${tier.name}',
    );
  }

  MemoryFabricResult merge({
    required SIMemoryStore base,
    required SIMemoryStore incoming,
    DateTime? now,
  }) {
    SIMemoryStore next = base;
    for (final SISnapshot s in incoming.snapshots) {
      next = next.pushSnapshot(s);
    }
    for (final MemoryRecord r in incoming.tiered.shortTerm) {
      next = next.pushRecord(MemoryTier.shortTerm, r);
    }
    for (final MemoryRecord r in incoming.tiered.midTerm) {
      next = next.pushRecord(MemoryTier.midTerm, r);
    }
    for (final MemoryRecord r in incoming.tiered.longTerm) {
      next = next.pushRecord(MemoryTier.longTerm, r);
    }
    next = rebalance(next, now: now).store;
    return MemoryFabricResult(
      store: next,
      changed: true,
      summary: 'memory_merged',
    );
  }

  MemoryFabricResult rebalance(SIMemoryStore store, {DateTime? now}) {
    final DateTime t = now ?? DateTime.now();
    SIMemoryStore next = SIMemoryStore(
      snapshots: store.snapshots,
      tiered: const SITieredMemory(),
    );

    for (final MemoryRecord r in read(store)) {
      final double s = r.score(t);
      final MemoryTier tier = s >= 0.72
          ? MemoryTier.longTerm
          : s >= 0.45
          ? MemoryTier.midTerm
          : MemoryTier.shortTerm;
      next = next.pushRecord(tier, r);
    }

    next = next.dedupe().decay(t);
    return MemoryFabricResult(
      store: next,
      changed: true,
      summary: 'memory_rebalanced',
    );
  }

  Map<String, dynamic> toJson(SIMemoryStore store) => <String, dynamic>{
    'snapshots': store.snapshots.map(_snapshotToJson).toList(),
    'shortTerm': store.tiered.shortTerm.map(_recordToJson).toList(),
    'midTerm': store.tiered.midTerm.map(_recordToJson).toList(),
    'longTerm': store.tiered.longTerm.map(_recordToJson).toList(),
  };

  SIMemoryStore fromJson(Map<String, dynamic> json) {
    final List<SISnapshot> snapshots =
        ((json['snapshots'] as List?) ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> m) =>
                  _snapshotFromJson(Map<String, dynamic>.from(m)),
            )
            .toList();

    List<MemoryRecord> records(String key) =>
        ((json[key] as List?) ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> m) =>
                  _recordFromJson(Map<String, dynamic>.from(m)),
            )
            .toList();

    return SIMemoryStore(
      snapshots: List<SISnapshot>.unmodifiable(snapshots),
      tiered: SITieredMemory(
        shortTerm: List<MemoryRecord>.unmodifiable(records('shortTerm')),
        midTerm: List<MemoryRecord>.unmodifiable(records('midTerm')),
        longTerm: List<MemoryRecord>.unmodifiable(records('longTerm')),
      ),
    );
  }

  Map<String, dynamic> _recordToJson(MemoryRecord r) => <String, dynamic>{
    'content': r.content,
    'timestamp': r.timestamp.toIso8601String(),
    'relevance': siClamp01(r.relevance),
    'recency': siClamp01(r.recency),
    'confidence': siClamp01(r.confidence),
    'emotionalWeight': siClamp01(r.emotionalWeight),
    'reinforcement': r.reinforcement,
  };

  MemoryRecord _recordFromJson(Map<String, dynamic> j) => MemoryRecord(
    content: siClean(j['content']?.toString(), fallback: 'memory_record'),
    timestamp:
        DateTime.tryParse(j['timestamp']?.toString() ?? '') ?? DateTime.now(),
    relevance: siClamp01(j['relevance'] as num?),
    recency: siClamp01(j['recency'] as num?, fallback: 1),
    confidence: siClamp01(j['confidence'] as num?),
    emotionalWeight: siClamp01(j['emotionalWeight'] as num?),
    reinforcement: (j['reinforcement'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> _snapshotToJson(SISnapshot s) => <String, dynamic>{
    'timestamp': s.timestamp.toIso8601String(),
    'energy': siClamp01(s.energy),
    'fatigue': siClamp01(s.fatigue),
    'completed': s.completed,
    'skipped': s.skipped,
    'taskId': s.taskId,
    'reasoning': s.reasoning,
  };

  SISnapshot _snapshotFromJson(Map<String, dynamic> j) => SISnapshot(
    timestamp:
        DateTime.tryParse(j['timestamp']?.toString() ?? '') ?? DateTime.now(),
    energy: siClamp01(j['energy'] as num?),
    fatigue: siClamp01(j['fatigue'] as num?),
    completed: (j['completed'] as num?)?.toInt() ?? 0,
    skipped: (j['skipped'] as num?)?.toInt() ?? 0,
    taskId: j['taskId']?.toString(),
    reasoning: j['reasoning']?.toString(),
  );
}
