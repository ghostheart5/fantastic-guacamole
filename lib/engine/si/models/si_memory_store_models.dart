part of 'si_state.dart';

class SISnapshot {
  const SISnapshot({
    required this.timestamp,
    required this.energy,
    required this.fatigue,
    required this.completed,
    required this.skipped,
    this.taskId,
    this.reasoning,
  });

  final DateTime timestamp;
  final double energy;
  final double fatigue;
  final int completed;
  final int skipped;
  final String? taskId;
  final String? reasoning;
}

enum MemoryTier { shortTerm, midTerm, longTerm }

class MemoryRecord {
  const MemoryRecord({
    required this.content,
    required this.timestamp,
    this.relevance = 0.5,
    this.recency = 1.0,
    this.confidence = 0.5,
    this.emotionalWeight = 0.5,
    this.reinforcement = 0,
  });

  final String content;
  final DateTime timestamp;
  final double relevance;
  final double recency;
  final double confidence;
  final double emotionalWeight;
  final int reinforcement;

  double score(DateTime now) {
    final int ageHours = now.difference(timestamp).inHours;
    final double decay = siClamp01(
      1 - (ageHours / 240),
      fallback: 1.0,
    ).clamp(0.15, 1.0).toDouble();

    final double base =
        (siClamp01(relevance) * 0.35) +
        (siClamp01(recency) * 0.25) +
        (siClamp01(confidence) * 0.2) +
        (siClamp01(emotionalWeight) * 0.2);

    return base * decay * (1 + reinforcement.clamp(0, 20) * 0.05);
  }
}

class SITieredMemory {
  const SITieredMemory({
    this.shortTerm = const <MemoryRecord>[],
    this.midTerm = const <MemoryRecord>[],
    this.longTerm = const <MemoryRecord>[],
  });

  final List<MemoryRecord> shortTerm;
  final List<MemoryRecord> midTerm;
  final List<MemoryRecord> longTerm;

  SITieredMemory push(MemoryTier tier, MemoryRecord record) {
    switch (tier) {
      case MemoryTier.shortTerm:
        return SITieredMemory(
          shortTerm: List<MemoryRecord>.unmodifiable(
            <MemoryRecord>[record, ...shortTerm].take(10),
          ),
          midTerm: midTerm,
          longTerm: longTerm,
        );
      case MemoryTier.midTerm:
        return SITieredMemory(
          shortTerm: shortTerm,
          midTerm: List<MemoryRecord>.unmodifiable(
            <MemoryRecord>[record, ...midTerm].take(40),
          ),
          longTerm: longTerm,
        );
      case MemoryTier.longTerm:
        return SITieredMemory(
          shortTerm: shortTerm,
          midTerm: midTerm,
          longTerm: List<MemoryRecord>.unmodifiable(
            <MemoryRecord>[record, ...longTerm].take(200),
          ),
        );
    }
  }

  SITieredMemory decay(DateTime now) {
    List<MemoryRecord> filter(List<MemoryRecord> items, double threshold) {
      return List<MemoryRecord>.unmodifiable(
        items.where((MemoryRecord r) => r.score(now) >= threshold),
      );
    }

    return SITieredMemory(
      shortTerm: filter(shortTerm, 0.25),
      midTerm: filter(midTerm, 0.2),
      longTerm: filter(longTerm, 0.15),
    );
  }

  SITieredMemory dedupe() {
    List<MemoryRecord> dedupeList(List<MemoryRecord> items) {
      final Set<String> seen = <String>{};
      return List<MemoryRecord>.unmodifiable(
        items.where((MemoryRecord r) {
          final String key = siClean(r.content).toLowerCase();
          if (key.isEmpty || seen.contains(key)) return false;
          seen.add(key);
          return true;
        }),
      );
    }

    return SITieredMemory(
      shortTerm: dedupeList(shortTerm),
      midTerm: dedupeList(midTerm),
      longTerm: dedupeList(longTerm),
    );
  }
}

class SIMemoryStore {
  const SIMemoryStore({
    this.snapshots = const <SISnapshot>[],
    this.tiered = const SITieredMemory(),
  });

  final List<SISnapshot> snapshots;
  final SITieredMemory tiered;

  SISnapshot? get latest => snapshots.isEmpty ? null : snapshots.first;

  SIMemoryStore pushSnapshot(SISnapshot snapshot, {int max = 24}) {
    final List<SISnapshot> next = <SISnapshot>[snapshot, ...snapshots];
    return SIMemoryStore(
      snapshots: List<SISnapshot>.unmodifiable(next.take(max.clamp(1, 500))),
      tiered: tiered,
    );
  }

  SIMemoryStore pushRecord(MemoryTier tier, MemoryRecord record) {
    return SIMemoryStore(
      snapshots: snapshots,
      tiered: tiered.push(tier, record),
    );
  }

  SIMemoryStore decay([DateTime? now]) {
    return SIMemoryStore(
      snapshots: snapshots,
      tiered: tiered.decay(now ?? DateTime.now()),
    );
  }

  SIMemoryStore dedupe() {
    return SIMemoryStore(snapshots: snapshots, tiered: tiered.dedupe());
  }

  SIMemoryStore clear() => const SIMemoryStore();
}

class SIMemoryUpdate {
  const SIMemoryUpdate({required this.store, required this.addedSnapshot});

  final SIMemoryStore store;
  final SISnapshot addedSnapshot;
}
