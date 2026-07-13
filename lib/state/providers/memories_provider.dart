import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemorySummary {
  const MemorySummary({
    required this.total,
    required this.recent,
    required this.starred,
    required this.archived,
    required this.categoryCounts,
    required this.topTags,
  });

  final int total;
  final int recent;
  final int starred;
  final int archived;
  final Map<MemoryCategory, int> categoryCounts;
  final List<String> topTags;
}

final memoriesActionsProvider = Provider<MemoriesActions>((Ref ref) {
  return MemoriesActions(ref);
});

final memoriesProvider = NotifierProvider<MemoriesNotifier, List<MemoryEntity>>(
  MemoriesNotifier.new,
);

final memorySummaryProvider = Provider<MemorySummary>((Ref ref) {
  final List<MemoryEntity> memories = ref.watch(memoriesProvider);
  final Map<MemoryCategory, int> categoryCounts = <MemoryCategory, int>{
    for (final c in MemoryCategory.values) c: 0,
  };
  final Map<String, int> tagCounts = <String, int>{};
  int recent = 0;
  int starred = 0;
  int archived = 0;

  for (final MemoryEntity memory in memories) {
    categoryCounts[memory.category] =
        (categoryCounts[memory.category] ?? 0) + 1;
    if (memory.isRecent) recent++;
    if (memory.starred) starred++;
    if (memory.isArchived) archived++;
    for (final String tag in memory.tags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  final List<MapEntry<String, int>> rankedTags = tagCounts.entries.toList(
    growable: false,
  )..sort((a, b) => b.value.compareTo(a.value));

  return MemorySummary(
    total: memories.length,
    recent: recent,
    starred: starred,
    archived: archived,
    categoryCounts: categoryCounts,
    topTags: rankedTags
        .take(6)
        .map((MapEntry<String, int> entry) => entry.key)
        .toList(growable: false),
  );
});

final memorySearchProvider = Provider.family<List<MemoryEntity>, String>((
  Ref ref,
  String query,
) {
  final String normalized = query.trim().toLowerCase();
  final List<MemoryEntity> memories = ref.watch(memoriesProvider);
  if (normalized.isEmpty) {
    return memories
        .where((MemoryEntity item) => !item.isArchived)
        .toList(growable: false);
  }
  return memories
      .where((MemoryEntity item) {
        if (item.isArchived) return false;
        if (item.contains(normalized)) return true;
        return item.metadata.values.any(
          (String value) => value.toLowerCase().contains(normalized),
        );
      })
      .toList(growable: false);
});

final memoriesByCategoryProvider =
    Provider<Map<MemoryCategory, List<MemoryEntity>>>((Ref ref) {
      final List<MemoryEntity> memories = ref.watch(memoriesProvider);
      final Map<MemoryCategory, List<MemoryEntity>> grouped = {
        for (final MemoryCategory category in MemoryCategory.values)
          category: <MemoryEntity>[],
      };
      for (final MemoryEntity memory in memories) {
        grouped[memory.category]!.add(memory);
      }
      return grouped;
    });

class MemoriesActions {
  const MemoriesActions(this._ref);

  final Ref _ref;

  Future<void> saveMemory(String text) {
    return _ref.read(memoriesProvider.notifier).capture(text);
  }

  Future<void> saveStructuredMemory(
    String text, {
    MemoryCategory? category,
    List<String> tags = const <String>[],
    Map<String, String> metadata = const <String, String>{},
  }) {
    return _ref
        .read(memoriesProvider.notifier)
        .capture(text, category: category, tags: tags, metadata: metadata);
  }

  Future<void> saveMirroredMemory(String text) {
    return _ref
        .read(memoriesProvider.notifier)
        .capture(text, refreshCoach: false, syncSoulMap: false);
  }
}

class MemoriesNotifier extends Notifier<List<MemoryEntity>> {
  static const _maxEntries = 200;

  @override
  List<MemoryEntity> build() {
    return ref.read(getMemoriesUseCaseProvider).call();
  }

  Future<void> capture(
    String text, {
    MemoryCategory? category,
    List<String> tags = const <String>[],
    Map<String, String> metadata = const <String, String>{},
    String source = 'manual',
    bool refreshCoach = true,
    bool syncSoulMap = true,
  }) async {
    final String normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    final MemoryCategory resolvedCategory =
        category ?? _inferCategory(normalizedText, metadata);
    final List<String> resolvedTags = _mergeTags(
      explicitTags: tags,
      inferredTags: _inferTags(normalizedText, resolvedCategory, metadata),
    );
    final double importance = _computeImportance(
      text: normalizedText,
      category: resolvedCategory,
      tags: resolvedTags,
      metadata: metadata,
    );

    final memory = MemoryEntity(
      id: now.microsecondsSinceEpoch.toString(),
      text: normalizedText,
      date: now,
      category: resolvedCategory,
      tags: resolvedTags,
      importance: importance,
      metadata: metadata,
      source: source,
    );

    final List<MemoryEntity> linkedExisting = _linkToRelatedMemories(
      memory,
      state,
    );
    final List<MemoryEntity> updated = [memory, ...linkedExisting];
    state = updated.length > _maxEntries
        ? updated.sublist(0, _maxEntries)
        : updated;
    await ref.read(saveMemoryUseCaseProvider).call(memory);
    for (final MemoryEntity existing in linkedExisting) {
      if (existing.links.any((MemoryLink link) => link.memoryId == memory.id)) {
        await ref.read(saveMemoryUseCaseProvider).call(existing);
      }
    }

    if (syncSoulMap) {
      ref.invalidate(soulStateProvider);
    }
    if (refreshCoach) {
      await _refreshCoachDecision();
    }
    ref
        .read(eventBusProvider)
        .emit(MemoryLifecycleEvent(memoryId: memory.id, text: memory.text));
  }

  Future<void> toggleStar(String id) async {
    MemoryEntity? updatedMemory;
    state = state.map((m) {
      final next = m.id == id ? m.copyWith(starred: !m.starred) : m;
      if (next.id == id) {
        updatedMemory = next;
      }
      return next;
    }).toList();
    if (updatedMemory != null) {
      await ref.read(saveMemoryUseCaseProvider).call(updatedMemory!);
    }
  }

  Future<void> archive(String id) async {
    MemoryEntity? archived;
    state = state
        .map((MemoryEntity item) {
          if (item.id != id) return item;
          archived = item.archive();
          return archived!;
        })
        .toList(growable: false);
    if (archived != null) {
      await ref.read(saveMemoryUseCaseProvider).call(archived!);
    }
  }

  Future<void> updateMemory(
    String id, {
    String? text,
    MemoryCategory? category,
    List<String>? tags,
    Map<String, String>? metadata,
    double? importance,
  }) async {
    MemoryEntity? updatedMemory;
    state = state
        .map((MemoryEntity item) {
          if (item.id != id) {
            return item;
          }
          final String? normalizedText = text?.trim();
          final MemoryCategory nextCategory =
              category ??
              _inferCategory(
                normalizedText ?? item.text,
                metadata ?? item.metadata,
              );
          final List<String> nextTags = _mergeTags(
            explicitTags: tags ?? item.tags,
            inferredTags: _inferTags(
              normalizedText ?? item.text,
              nextCategory,
              metadata ?? item.metadata,
            ),
          );
          updatedMemory = item.copyWith(
            text: normalizedText == null || normalizedText.isEmpty
                ? item.text
                : normalizedText,
            category: nextCategory,
            tags: nextTags,
            metadata: metadata ?? item.metadata,
            importance:
                importance ??
                _computeImportance(
                  text: normalizedText ?? item.text,
                  category: nextCategory,
                  tags: nextTags,
                  metadata: metadata ?? item.metadata,
                ),
          );
          return updatedMemory!;
        })
        .toList(growable: false);
    if (updatedMemory != null) {
      await ref.read(saveMemoryUseCaseProvider).call(updatedMemory!);
    }
  }

  Future<void> remove(String id) async {
    await ref.read(deleteMemoryUseCaseProvider).call(id);
    state = state.where((m) => m.id != id).toList(growable: false);
  }

  MemoryCategory _inferCategory(String text, Map<String, String> metadata) {
    final String lowered = text.toLowerCase();
    final String type = metadata['type']?.toLowerCase() ?? '';
    if (type.contains('goal')) return MemoryCategory.goal;
    if (type.contains('habit')) return MemoryCategory.habit;
    if (type.contains('task')) return MemoryCategory.task;
    if (type.contains('journal')) return MemoryCategory.journal;
    if (type.contains('preference')) return MemoryCategory.userPreference;
    if (type.contains('date')) return MemoryCategory.importantDate;
    if (type.contains('value')) return MemoryCategory.value;
    if (lowered.contains('goal') || lowered.contains('target')) {
      return MemoryCategory.goal;
    }
    if (lowered.contains('habit') || lowered.contains('streak')) {
      return MemoryCategory.habit;
    }
    if (lowered.contains('task') || lowered.contains('todo')) {
      return MemoryCategory.task;
    }
    if (lowered.contains('journal') || lowered.contains('reflection')) {
      return MemoryCategory.journal;
    }
    if (lowered.contains('prefer') || lowered.contains('like to')) {
      return MemoryCategory.userPreference;
    }
    if (lowered.contains('coach') && lowered.contains('style')) {
      return MemoryCategory.coachingPreference;
    }
    if (lowered.contains('value') || lowered.contains('belief')) {
      return MemoryCategory.value;
    }
    if (lowered.contains('birthday') || lowered.contains('anniversary')) {
      return MemoryCategory.importantDate;
    }
    if (lowered.contains('win') || lowered.contains('completed')) {
      return MemoryCategory.achievement;
    }
    return MemoryCategory.other;
  }

  List<String> _inferTags(
    String text,
    MemoryCategory category,
    Map<String, String> metadata,
  ) {
    final Set<String> tags = <String>{category.name};
    final String lowered = text.toLowerCase();
    if (lowered.contains('morning')) tags.add('morning');
    if (lowered.contains('evening')) tags.add('evening');
    if (lowered.contains('work')) tags.add('work');
    if (lowered.contains('health') || lowered.contains('workout')) {
      tags.add('health');
    }
    if (lowered.contains('stress') || lowered.contains('anxious')) {
      tags.add('stress');
    }
    metadata.forEach((String key, String value) {
      if (key.trim().isNotEmpty && value.trim().isNotEmpty) {
        tags.add(key.toLowerCase());
        tags.add(value.toLowerCase());
      }
    });
    return tags
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .take(8)
        .toList(growable: false);
  }

  List<String> _mergeTags({
    required List<String> explicitTags,
    required List<String> inferredTags,
  }) {
    final Set<String> merged = <String>{};
    for (final String tag in <String>[...explicitTags, ...inferredTags]) {
      final String normalized = tag.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        merged.add(normalized);
      }
    }
    return merged.take(10).toList(growable: false);
  }

  double _computeImportance({
    required String text,
    required MemoryCategory category,
    required List<String> tags,
    required Map<String, String> metadata,
  }) {
    double score = 0.45;
    if (text.length >= 80) score += 0.08;
    if (text.length >= 140) score += 0.05;
    if (tags.isNotEmpty) score += 0.05;
    if (metadata.isNotEmpty) score += 0.05;
    if (category == MemoryCategory.goal ||
        category == MemoryCategory.value ||
        category == MemoryCategory.importantDate) {
      score += 0.12;
    }
    final String lowered = text.toLowerCase();
    if (lowered.contains('must') || lowered.contains('important')) {
      score += 0.10;
    }
    if (lowered.contains('deadline') || lowered.contains('due')) {
      score += 0.08;
    }
    return score.clamp(0.0, 1.0);
  }

  List<MemoryEntity> _linkToRelatedMemories(
    MemoryEntity incoming,
    List<MemoryEntity> existing,
  ) {
    final Set<String> incomingTags = incoming.tags.toSet();
    return existing
        .map((MemoryEntity item) {
          if (item.id == incoming.id || item.isArchived) {
            return item;
          }
          final bool sameCategory = item.category == incoming.category;
          final bool sharedTag = item.tags.any(incomingTags.contains);
          final bool closeInTime =
              incoming.date.difference(item.date).abs().inDays <= 14;
          if ((sameCategory && sharedTag) || (sharedTag && closeInTime)) {
            return item.addLink(
              incoming.id,
              relation: sameCategory ? 'same_category' : 'related_tag',
            );
          }
          return item;
        })
        .toList(growable: false);
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking memory saves if coach refresh fails.
    }
  }
}
