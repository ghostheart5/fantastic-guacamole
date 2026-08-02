import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';

class MemoryAnalyticsResult {
  const MemoryAnalyticsResult({
    required this.total,
    required this.active,
    required this.archived,
    required this.starred,
    required this.recent,
    required this.highImportance,
    required this.linked,
    required this.unlinkedImportant,
    required this.categoryCounts,
    required this.sourceCounts,
    required this.topTags,
    required this.healthScore,
  });

  final int total;
  final int active;
  final int archived;
  final int starred;
  final int recent;
  final int highImportance;
  final int linked;
  final int unlinkedImportant;
  final Map<MemoryCategory, int> categoryCounts;
  final Map<String, int> sourceCounts;
  final List<String> topTags;
  final int healthScore;
}

class ViewMemoryAnalyticsUsecase {
  const ViewMemoryAnalyticsUsecase();

  MemoryAnalyticsResult call(List<MemoryEntity> memories) {
    final Map<MemoryCategory, int> categoryCounts = <MemoryCategory, int>{
      for (final MemoryCategory category in MemoryCategory.values) category: 0,
    };
    final Map<String, int> tagCounts = <String, int>{};
    final Map<String, int> sourceCounts = <String, int>{};

    int archived = 0;
    int starred = 0;
    int recent = 0;
    int highImportance = 0;
    int linked = 0;
    int unlinkedImportant = 0;

    for (final MemoryEntity memory in memories) {
      categoryCounts[memory.category] =
          (categoryCounts[memory.category] ?? 0) + 1;

      if (memory.isArchived) {
        archived++;
      }
      if (memory.starred) {
        starred++;
      }
      if (memory.isRecent) {
        recent++;
      }
      if (memory.importance >= 0.75) {
        highImportance++;
        if (memory.links.isEmpty) {
          unlinkedImportant++;
        }
      }
      if (memory.links.isNotEmpty) {
        linked++;
      }

      final String source = memory.source.trim().isEmpty
          ? 'unknown'
          : memory.source.trim();
      sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;

      for (final String tag in memory.tags) {
        final String normalized = tag.trim();
        if (normalized.isEmpty) {
          continue;
        }
        tagCounts[normalized] = (tagCounts[normalized] ?? 0) + 1;
      }
    }

    final List<MapEntry<String, int>> rankedTags =
        tagCounts.entries.toList(growable: false)
          ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
            final int count = b.value.compareTo(a.value);
            if (count != 0) {
              return count;
            }
            return a.key.compareTo(b.key);
          });

    final int active = memories.length - archived;
    final int categoryCoverage = categoryCounts.values
        .where((int count) => count > 0)
        .length;
    final int healthScore = <int>[
      memories.isEmpty ? 0 : 20,
      active > 0 ? 15 : 0,
      recent > 0 ? 15 : 0,
      starred > 0 ? 10 : 0,
      highImportance > 0 ? 10 : 0,
      linked > 0 ? 10 : 0,
      rankedTags.isNotEmpty ? 10 : 0,
      categoryCoverage >= 3 ? 10 : categoryCoverage * 3,
    ].fold<int>(0, (int total, int value) => total + value).clamp(0, 100);

    return MemoryAnalyticsResult(
      total: memories.length,
      active: active,
      archived: archived,
      starred: starred,
      recent: recent,
      highImportance: highImportance,
      linked: linked,
      unlinkedImportant: unlinkedImportant,
      categoryCounts: categoryCounts,
      sourceCounts: sourceCounts,
      topTags: rankedTags
          .take(6)
          .map((MapEntry<String, int> entry) => entry.key)
          .toList(growable: false),
      healthScore: healthScore,
    );
  }
}
