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

class TieredMemory {
  const TieredMemory({
    this.shortTerm = const <MemoryRecord>[],
    this.midTerm = const <MemoryRecord>[],
    this.longTerm = const <MemoryRecord>[],
  });

  final List<MemoryRecord> shortTerm;
  final List<MemoryRecord> midTerm;
  final List<MemoryRecord> longTerm;

  TieredMemory push(MemoryTier tier, MemoryRecord record) {
    switch (tier) {
      case MemoryTier.shortTerm:
        final List<MemoryRecord> next = <MemoryRecord>[record, ...shortTerm];
        return TieredMemory(
          shortTerm: next.take(10).toList(),
          midTerm: midTerm,
          longTerm: longTerm,
        );
      case MemoryTier.midTerm:
        return TieredMemory(
          shortTerm: shortTerm,
          midTerm: <MemoryRecord>[record, ...midTerm].take(40).toList(),
          longTerm: longTerm,
        );
      case MemoryTier.longTerm:
        return TieredMemory(
          shortTerm: shortTerm,
          midTerm: midTerm,
          longTerm: <MemoryRecord>[record, ...longTerm].take(200).toList(),
        );
    }
  }

  TieredMemory decay(DateTime now) {
    List<MemoryRecord> filter(List<MemoryRecord> items, double threshold) {
      return items
          .where((MemoryRecord r) => r.score(now) >= threshold)
          .toList();
    }

    return TieredMemory(
      shortTerm: filter(shortTerm, 0.25),
      midTerm: filter(midTerm, 0.2),
      longTerm: filter(longTerm, 0.15),
    );
  }
}
