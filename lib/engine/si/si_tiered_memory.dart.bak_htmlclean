// lib/engine/si/si_tiered_memory.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

export 'package:fantastic_guacamole/engine/si/models/si_state.dart'
    show
        MemoryTier,
        MemoryRecord,
        SITieredMemory,
        SIMemoryStore,
        SISnapshot,
        SIMemoryUpdate;

class TieredMemoryQuery {
  const TieredMemoryQuery({
    this.tier,
    this.contains,
    this.after,
    this.before,
    this.minScore = 0,
    this.minRelevance = 0,
    this.minConfidence = 0,
    this.limit = 20,
  });

  final MemoryTier? tier;
  final String? contains;
  final DateTime? after;
  final DateTime? before;
  final double minScore;
  final double minRelevance;
  final double minConfidence;
  final int limit;
}

class TieredMemoryStats {
  const TieredMemoryStats({
    required this.shortTermCount,
    required this.midTermCount,
    required this.longTermCount,
    required this.totalCount,
    required this.averageScore,
    required this.strongestTier,
  });

  final int shortTermCount;
  final int midTermCount;
  final int longTermCount;
  final int totalCount;
  final double averageScore;
  final MemoryTier strongestTier;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'short_term_count': shortTermCount,
    'mid_term_count': midTermCount,
    'long_term_count': longTermCount,
    'total_count': totalCount,
    'average_score': siClamp01(averageScore),
    'strongest_tier': strongestTier.name,
  };
}

class TieredMemoryUpdate {
  const TieredMemoryUpdate({
    required this.store,
    required this.changed,
    required this.summary,
    required this.stats,
  });

  final SIMemoryStore store;
  final bool changed;
  final String summary;
  final TieredMemoryStats stats;
}

class SITieredMemoryEngine {
  const SITieredMemoryEngine();

  List<MemoryRecord> records(SIMemoryStore store, {MemoryTier? tier}) {
    switch (tier) {
      case MemoryTier.shortTerm:
        return store.tiered.shortTerm;
      case MemoryTier.midTerm:
        return store.tiered.midTerm;
      case MemoryTier.longTerm:
        return store.tiered.longTerm;
      case null:
        return <MemoryRecord>[
          ...store.tiered.shortTerm,
          ...store.tiered.midTerm,
          ...store.tiered.longTerm,
        ];
    }
  }

  TieredMemoryUpdate write({
    required SIMemoryStore store,
    required MemoryRecord record,
    MemoryTier tier = MemoryTier.shortTerm,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final SIMemoryStore next = store
        .pushRecord(tier, _safeRecord(record))
        .dedupe()
        .decay(timestamp);

    return TieredMemoryUpdate(
      store: next,
      changed: true,
      summary: 'tiered_memory_write|tier=${tier.name}',
      stats: stats(next, now: timestamp),
    );
  }

  TieredMemoryUpdate writeStructured({
    required SIMemoryStore store,
    required String type,
    required String label,
    required String value,
    MemoryTier tier = MemoryTier.shortTerm,
    double relevance = 0.5,
    double confidence = 0.5,
    double emotionalWeight = 0.35,
    int reinforcement = 0,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    return write(
      store: store,
      tier: tier,
      now: timestamp,
      record: MemoryRecord(
        content:
            '${siClean(type, fallback: 'memory')}|${siClean(label, fallback: 'label')}|${siClean(value, fallback: 'value')}',
        timestamp: timestamp,
        relevance: siClamp01(relevance),
        confidence: siClamp01(confidence),
        emotionalWeight: siClamp01(emotionalWeight),
        reinforcement: reinforcement,
      ),
    );
  }

  List<MemoryRecord> query(
    SIMemoryStore store,
    TieredMemoryQuery query, {
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final String needle = siClean(query.contains).toLowerCase();
    final int cappedLimit = query.limit.clamp(1, 300).toInt();

    final List<MemoryRecord> output = records(store, tier: query.tier).where((
      MemoryRecord record,
    ) {
      final String content = siClean(record.content).toLowerCase();

      if (needle.isNotEmpty && !content.contains(needle)) return false;
      if (query.after != null && record.timestamp.isBefore(query.after!)) {
        return false;
      }
      if (query.before != null && record.timestamp.isAfter(query.before!)) {
        return false;
      }
      if (record.score(timestamp) < siClamp01(query.minScore, fallback: 0)) {
        return false;
      }
      if (siClamp01(record.relevance) <
          siClamp01(query.minRelevance, fallback: 0)) {
        return false;
      }
      if (siClamp01(record.confidence) <
          siClamp01(query.minConfidence, fallback: 0)) {
        return false;
      }

      return true;
    }).toList();

    output.sort(
      (MemoryRecord a, MemoryRecord b) =>
          b.score(timestamp).compareTo(a.score(timestamp)),
    );

    return List<MemoryRecord>.unmodifiable(output.take(cappedLimit));
  }

  TieredMemoryUpdate rebalance({required SIMemoryStore store, DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();

    SIMemoryStore next = SIMemoryStore(
      snapshots: store.snapshots,
      tiered: const SITieredMemory(),
    );

    for (final MemoryRecord record in records(store)) {
      final double score = record.score(timestamp);
      final MemoryTier nextTier = score >= 0.72
          ? MemoryTier.longTerm
          : score >= 0.45
          ? MemoryTier.midTerm
          : MemoryTier.shortTerm;

      next = next.pushRecord(nextTier, record);
    }

    next = next.dedupe().decay(timestamp);

    return TieredMemoryUpdate(
      store: next,
      changed: true,
      summary: 'tiered_memory_rebalanced',
      stats: stats(next, now: timestamp),
    );
  }

  TieredMemoryUpdate merge({
    required SIMemoryStore base,
    required SIMemoryStore incoming,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    SIMemoryStore next = base;

    for (final SISnapshot snapshot in incoming.snapshots) {
      next = next.pushSnapshot(snapshot);
    }

    for (final MemoryRecord record in incoming.tiered.shortTerm) {
      next = next.pushRecord(MemoryTier.shortTerm, record);
    }

    for (final MemoryRecord record in incoming.tiered.midTerm) {
      next = next.pushRecord(MemoryTier.midTerm, record);
    }

    for (final MemoryRecord record in incoming.tiered.longTerm) {
      next = next.pushRecord(MemoryTier.longTerm, record);
    }

    return rebalance(store: next, now: timestamp);
  }

  TieredMemoryUpdate promote({
    required SIMemoryStore store,
    required String contains,
    MemoryTier to = MemoryTier.longTerm,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final String needle = siClean(contains).toLowerCase();
    SIMemoryStore next = SIMemoryStore(
      snapshots: store.snapshots,
      tiered: const SITieredMemory(),
    );

    for (final MemoryRecord record in records(store)) {
      final bool match =
          needle.isNotEmpty &&
          siClean(record.content).toLowerCase().contains(needle);

      next = next.pushRecord(
        match ? to : _tierForScore(record.score(timestamp)),
        record,
      );
    }

    next = next.dedupe().decay(timestamp);

    return TieredMemoryUpdate(
      store: next,
      changed: true,
      summary: 'tiered_memory_promoted|contains=$contains|to=${to.name}',
      stats: stats(next, now: timestamp),
    );
  }

  TieredMemoryStats stats(SIMemoryStore store, {DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<MemoryRecord> all = records(store);
    final double avg = all.isEmpty
        ? 0.0
        : all.fold<double>(
                0,
                (double sum, MemoryRecord record) =>
                    sum + record.score(timestamp),
              ) /
              all.length;

    final Map<MemoryTier, double> tierScores = <MemoryTier, double>{
      MemoryTier.shortTerm: _tierAverage(store.tiered.shortTerm, timestamp),
      MemoryTier.midTerm: _tierAverage(store.tiered.midTerm, timestamp),
      MemoryTier.longTerm: _tierAverage(store.tiered.longTerm, timestamp),
    };

    final MemoryTier strongest =
        (tierScores.entries.toList()..sort(
              (
                MapEntry<MemoryTier, double> a,
                MapEntry<MemoryTier, double> b,
              ) => b.value.compareTo(a.value),
            ))
            .first
            .key;

    return TieredMemoryStats(
      shortTermCount: store.tiered.shortTerm.length,
      midTermCount: store.tiered.midTerm.length,
      longTermCount: store.tiered.longTerm.length,
      totalCount: all.length,
      averageScore: siClamp01(avg),
      strongestTier: strongest,
    );
  }

  Map<String, dynamic> toJson(SIMemoryStore store) => <String, dynamic>{
    'snapshots': store.snapshots.map(_snapshotToJson).toList(),
    'short_term': store.tiered.shortTerm.map(_recordToJson).toList(),
    'mid_term': store.tiered.midTerm.map(_recordToJson).toList(),
    'long_term': store.tiered.longTerm.map(_recordToJson).toList(),
  };

  SIMemoryStore fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) {
      return ((json[key] as List?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> value) => Map<String, dynamic>.from(value),
          )
          .toList(growable: false);
    }

    return SIMemoryStore(
      snapshots: List<SISnapshot>.unmodifiable(
        list('snapshots').map(_snapshotFromJson),
      ),
      tiered: SITieredMemory(
        shortTerm: List<MemoryRecord>.unmodifiable(
          list('short_term').map(_recordFromJson),
        ),
        midTerm: List<MemoryRecord>.unmodifiable(
          list('mid_term').map(_recordFromJson),
        ),
        longTerm: List<MemoryRecord>.unmodifiable(
          list('long_term').map(_recordFromJson),
        ),
      ),
    );
  }

  MemoryRecord _safeRecord(MemoryRecord record) {
    return MemoryRecord(
      content: siClean(record.content, fallback: 'memory_record'),
      timestamp: record.timestamp,
      relevance: siClamp01(record.relevance),
      recency: siClamp01(record.recency, fallback: 1),
      confidence: siClamp01(record.confidence),
      emotionalWeight: siClamp01(record.emotionalWeight),
      reinforcement: record.reinforcement.clamp(0, 20),
    );
  }

  MemoryTier _tierForScore(double score) {
    final double safe = siClamp01(score);
    if (safe >= 0.72) return MemoryTier.longTerm;
    if (safe >= 0.45) return MemoryTier.midTerm;
    return MemoryTier.shortTerm;
  }

  double _tierAverage(List<MemoryRecord> records, DateTime now) {
    if (records.isEmpty) return 0.0;
    return siClamp01(
      records.fold<double>(
            0,
            (double sum, MemoryRecord record) => sum + record.score(now),
          ) /
          records.length,
    );
  }

  Map<String, dynamic> _recordToJson(MemoryRecord record) => <String, dynamic>{
    'content': record.content,
    'timestamp': record.timestamp.toIso8601String(),
    'relevance': siClamp01(record.relevance),
    'recency': siClamp01(record.recency, fallback: 1),
    'confidence': siClamp01(record.confidence),
    'emotional_weight': siClamp01(record.emotionalWeight),
    'reinforcement': record.reinforcement,
  };

  MemoryRecord _recordFromJson(Map<String, dynamic> json) => MemoryRecord(
    content: siClean(json['content']?.toString(), fallback: 'memory_record'),
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.now(),
    relevance: siClamp01(_num(json['relevance'])),
    recency: siClamp01(_num(json['recency']), fallback: 1),
    confidence: siClamp01(_num(json['confidence'])),
    emotionalWeight: siClamp01(_num(json['emotional_weight'])),
    reinforcement: _num(json['reinforcement'])?.toInt() ?? 0,
  );

  Map<String, dynamic> _snapshotToJson(SISnapshot snapshot) =>
      <String, dynamic>{
        'timestamp': snapshot.timestamp.toIso8601String(),
        'energy': siClamp01(snapshot.energy),
        'fatigue': siClamp01(snapshot.fatigue),
        'completed': snapshot.completed,
        'skipped': snapshot.skipped,
        'task_id': snapshot.taskId,
        'reasoning': snapshot.reasoning,
      };

  SISnapshot _snapshotFromJson(Map<String, dynamic> json) => SISnapshot(
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.now(),
    energy: siClamp01(_num(json['energy'])),
    fatigue: siClamp01(_num(json['fatigue'])),
    completed: _num(json['completed'])?.toInt() ?? 0,
    skipped: _num(json['skipped'])?.toInt() ?? 0,
    taskId: json['task_id']?.toString(),
    reasoning: json['reasoning']?.toString(),
  );

  num? _num(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}
