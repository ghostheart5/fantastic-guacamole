class AssistantMemorySnapshot {
  const AssistantMemorySnapshot({
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

class AssistantSessionMemory {
  const AssistantSessionMemory({
    this.entries = const <AssistantMemorySnapshot>[],
  });

  final List<AssistantMemorySnapshot> entries;

  AssistantMemorySnapshot? get latest => entries.isEmpty ? null : entries.first;

  AssistantSessionMemory push(
    AssistantMemorySnapshot snapshot, {
    int maxEntries = 24,
  }) {
    final List<AssistantMemorySnapshot> next = <AssistantMemorySnapshot>[
      snapshot,
      ...entries,
    ];
    return AssistantSessionMemory(
      entries: next.length > maxEntries ? next.take(maxEntries).toList() : next,
    );
  }

  AssistantSessionMemory clear() => const AssistantSessionMemory();
}
