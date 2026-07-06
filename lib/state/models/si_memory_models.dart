class SISnapshot {
  const SISnapshot({
    required this.timestamp,
    required this.energy,
    required this.fatigue,
    required this.completed,
    required this.skipped,
    this.taskId,
    this.reasoning,
    this.responseHash,
    this.responseSummary,
    this.actionKey,
  });

  final DateTime timestamp;
  final double energy;
  final double fatigue;
  final int completed;
  final int skipped;
  final String? taskId;
  final String? reasoning;
  final String? responseHash;
  final String? responseSummary;
  final String? actionKey;
}

class SIMemory {
  const SIMemory({this.entries = const <SISnapshot>[]});

  final List<SISnapshot> entries;

  SISnapshot? get latest => entries.isEmpty ? null : entries.first;

  SIMemory push(SISnapshot snapshot, {int maxEntries = 24}) {
    final List<SISnapshot> next = <SISnapshot>[snapshot, ...entries];
    return SIMemory(
      entries: next.length > maxEntries ? next.take(maxEntries).toList() : next,
    );
  }

  SIMemory clear() => const SIMemory();
}
