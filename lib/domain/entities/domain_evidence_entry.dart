// CHRONOSPARK-CLASS: SHIPPING | Feature: Cross-domain evidence
enum DomainEvidenceKind {
  goal,
  task,
  dailyRhythm,
  note,
  reflection,
  taskOccurrence,
  dailyRhythmOccurrence,
  outcome,
}

enum DomainEvidenceSource {
  tasks,
  goals,
  dailyRhythms,
  notes,
  taskOccurrences,
  dailyRhythmOccurrences,
  outcomes,
}

class DomainEvidenceSnapshot {
  const DomainEvidenceSnapshot({
    required this.entries,
    this.unavailableSources = const <DomainEvidenceSource>{},
  });

  final List<DomainEvidenceEntry> entries;
  final Set<DomainEvidenceSource> unavailableSources;
}

class DomainEvidenceEntry {
  const DomainEvidenceEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.recordedAt,
    this.detail,
    this.relatedIds = const <String>[],
  });

  final DomainEvidenceKind kind;
  final String id;
  final String title;
  final String? detail;
  final DateTime recordedAt;
  final List<String> relatedIds;

  bool matches(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return <String>[
      kind.name,
      title,
      detail ?? '',
      ...relatedIds,
    ].join(' ').toLowerCase().contains(normalizedQuery);
  }
}
