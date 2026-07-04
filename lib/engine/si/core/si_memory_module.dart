// Module 8 — Memory
// Pipeline step: SIContext + SIDecision + SIResponse → SIMemoryUpdate
// Merges: si_memory + si_tiered_memory + si_snapshot (and all memory layers)

// ─── Data contracts ───────────────────────────────────────────────────────────

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
  MemoryRecord({
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
    final double decay = (1 - (ageHours / 240)).clamp(0.15, 1.0);
    return ((relevance * 0.35) +
            (recency * 0.25) +
            (confidence * 0.2) +
            (emotionalWeight * 0.2)) *
        decay *
        (1 + reinforcement * 0.05);
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
          shortTerm: <MemoryRecord>[record, ...shortTerm].take(10).toList(),
          midTerm: midTerm,
          longTerm: longTerm,
        );
      case MemoryTier.midTerm:
        return SITieredMemory(
          shortTerm: shortTerm,
          midTerm: <MemoryRecord>[record, ...midTerm].take(40).toList(),
          longTerm: longTerm,
        );
      case MemoryTier.longTerm:
        return SITieredMemory(
          shortTerm: shortTerm,
          midTerm: midTerm,
          longTerm: <MemoryRecord>[record, ...longTerm].take(200).toList(),
        );
    }
  }

  SITieredMemory decay(DateTime now) {
    List<MemoryRecord> filter(List<MemoryRecord> items, double threshold) =>
        items.where((MemoryRecord r) => r.score(now) >= threshold).toList();

    return SITieredMemory(
      shortTerm: filter(shortTerm, 0.25),
      midTerm: filter(midTerm, 0.2),
      longTerm: filter(longTerm, 0.15),
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
      snapshots: next.length > max ? next.take(max).toList() : next,
      tiered: tiered,
    );
  }

  SIMemoryStore pushRecord(MemoryTier tier, MemoryRecord record) {
    return SIMemoryStore(
      snapshots: snapshots,
      tiered: tiered.push(tier, record),
    );
  }

  SIMemoryStore decay() {
    return SIMemoryStore(
      snapshots: snapshots,
      tiered: tiered.decay(DateTime.now()),
    );
  }

  SIMemoryStore clear() => const SIMemoryStore();
}

class SIMemoryUpdate {
  const SIMemoryUpdate({required this.store, required this.addedSnapshot});

  final SIMemoryStore store;
  final SISnapshot addedSnapshot;
}

// ─── Module ───────────────────────────────────────────────────────────────────

class SIMemoryModule {
  const SIMemoryModule();

  SIMemoryUpdate update({
    required SIMemoryStore current,
    required double energy,
    required double fatigue,
    required int completed,
    required int skipped,
    String? taskId,
    String? reasoning,
  }) {
    final SISnapshot snapshot = SISnapshot(
      timestamp: DateTime.now(),
      energy: energy,
      fatigue: fatigue,
      completed: completed,
      skipped: skipped,
      taskId: taskId,
      reasoning: reasoning,
    );

    final MemoryRecord record = MemoryRecord(
      content: reasoning ?? 'session_update',
      timestamp: snapshot.timestamp,
      relevance: energy,
      recency: 1.0,
      confidence: 0.7,
      emotionalWeight: fatigue,
    );

    final SIMemoryStore updated = current
        .pushSnapshot(snapshot)
        .pushRecord(MemoryTier.shortTerm, record)
        .decay();

    return SIMemoryUpdate(store: updated, addedSnapshot: snapshot);
  }
}
