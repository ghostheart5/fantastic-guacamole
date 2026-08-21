import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/policies/memory_governance_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
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

/// The only public write entrypoint for governed durable memory.
final memoryGovernanceControllerProvider = Provider<MemoryGovernanceController>(
  (Ref ref) => MemoryGovernanceController(ref),
);

final memoriesProvider = NotifierProvider<MemoriesNotifier, List<MemoryEntity>>(
  MemoriesNotifier.new,
);

/// Assistant recall is exact-surface. SI returns no durable interpretive
/// memory by policy even if a malformed record exists in storage.
final memoryRecallProvider = Provider.family<List<MemoryEntity>, MemorySurface>(
  (Ref ref, MemorySurface surface) {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    if (!scope.isAuthenticated) return const <MemoryEntity>[];
    return ref
        .watch(domainMemoryRepositoryProvider)
        .getMemoriesForSurface(surface);
  },
);

final memorySummaryProvider = Provider<MemorySummary>((Ref ref) {
  final List<MemoryEntity> memories = ref.watch(memoriesProvider);
  final Map<MemoryCategory, int> categoryCounts = <MemoryCategory, int>{
    for (final MemoryCategory category in MemoryCategory.values) category: 0,
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

class MemoryGovernanceController {
  const MemoryGovernanceController(this._ref);

  final Ref _ref;

  Future<MemoryReceipt> rememberPreference({
    required String text,
    required MemorySurface sourceSurface,
    required DateTime expiresAt,
    required bool consentConfirmed,
    required String whyStored,
    required String provenance,
  }) {
    return _ref
        .read(memoriesProvider.notifier)
        .rememberPreference(
          text: text,
          sourceSurface: sourceSurface,
          expiresAt: expiresAt,
          consentConfirmed: consentConfirmed,
          whyStored: whyStored,
          provenance: provenance,
        );
  }

  Future<MemoryReceipt> correctPreference({
    required String id,
    required String text,
  }) {
    return _ref
        .read(memoriesProvider.notifier)
        .correctPreference(id: id, text: text);
  }

  Future<void> deleteMemory(String id) {
    return _ref.read(memoriesProvider.notifier).remove(id);
  }

  Future<void> deleteAll() {
    return _ref.read(memoriesProvider.notifier).deleteAll();
  }

  Map<String, dynamic> exportReceipts() {
    return _ref.read(memoriesProvider.notifier).exportReceipts();
  }
}

class MemoriesNotifier extends Notifier<List<MemoryEntity>> {
  static const int _maxEntries = 200;

  @override
  List<MemoryEntity> build() {
    ref.watch(accountStorageScopeProvider);
    return ref.watch(getMemoriesUseCaseProvider).call();
  }

  Future<MemoryReceipt> rememberPreference({
    required String text,
    required MemorySurface sourceSurface,
    required DateTime expiresAt,
    required bool consentConfirmed,
    required String whyStored,
    required String provenance,
  }) async {
    if (!consentConfirmed) {
      throw const MemoryGovernanceException(
        'consent_required',
        'Memory was not saved because explicit consent was not confirmed.',
      );
    }
    if (sourceSurface == MemorySurface.siConsole ||
        sourceSurface == MemorySurface.unknown) {
      throw const MemoryGovernanceException(
        'surface_not_allowed',
        'SI durable interpretive memory is disabled. Nothing was saved.',
      );
    }
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    final String? accountScopeId = scope.v2Namespace;
    if (!scope.isAuthenticated || accountScopeId == null) {
      throw const MemoryGovernanceException(
        'account_scope_required',
        'Sign in with a verified account before saving a preference.',
      );
    }
    await requireAssistantReleaseCapability(
      ref,
      AssistantReleaseCapability.governedMemory,
    );
    final String normalized = MemoryGovernancePolicy.validatePreferenceText(
      text,
    );
    final DateTime now = DateTime.now().toUtc();
    final DateTime expiry = MemoryGovernancePolicy.validateExpiry(
      createdAt: now,
      expiresAt: expiresAt,
    );
    if (whyStored.trim().isEmpty || provenance.trim().isEmpty) {
      throw const MemoryGovernanceException(
        'receipt_required',
        'Memory needs a visible reason and provenance receipt.',
      );
    }

    final MemoryEntity memory = MemoryEntity(
      id: 'memory-${now.microsecondsSinceEpoch}',
      text: normalized,
      date: now,
      category: MemoryCategory.planningGuidancePreference,
      tags: const <String>['explicit-preference'],
      importance: 0.6,
      metadata: const <String, String>{'type': 'explicit_preference'},
      source: 'explicit_user_consent',
      accountScopeId: accountScopeId,
      sourceSurface: sourceSurface,
      purpose: MemoryPurpose.guidancePreference,
      sensitivity: MemoryGovernancePolicy.classify(normalized),
      consentStatus: MemoryConsentStatus.granted,
      consentedAt: now,
      expiresAt: expiry,
      provenance: provenance.trim(),
      whyStored: whyStored.trim(),
    );
    memory.validateForDurableStorage();
    await ref.read(saveMemoryUseCaseProvider).call(memory);
    state = <MemoryEntity>[
      memory,
      ...state,
    ].take(_maxEntries).toList(growable: false);
    ref
        .read(eventBusProvider)
        .emit(MemoryLifecycleEvent(memoryId: memory.id, text: memory.text));
    return memory.toReceipt();
  }

  Future<MemoryReceipt> correctPreference({
    required String id,
    required String text,
  }) async {
    final String normalized = MemoryGovernancePolicy.validatePreferenceText(
      text,
    );
    final int index = state.indexWhere((MemoryEntity item) => item.id == id);
    if (index < 0) {
      throw const MemoryGovernanceException(
        'memory_not_found',
        'That memory no longer exists.',
      );
    }
    final MemoryEntity updated = state[index].copyWith(
      text: normalized,
      sensitivity: MemoryGovernancePolicy.classify(normalized),
    );
    updated.validateForDurableStorage();
    await ref.read(saveMemoryUseCaseProvider).call(updated);
    state = <MemoryEntity>[
      for (final MemoryEntity memory in state)
        if (memory.id == id) updated else memory,
    ];
    return updated.toReceipt();
  }

  Future<void> toggleStar(String id) async {
    final MemoryEntity? current = _find(id);
    if (current == null) return;
    final MemoryEntity updated = current.copyWith(starred: !current.starred);
    await ref.read(saveMemoryUseCaseProvider).call(updated);
    _replace(updated);
  }

  Future<void> archive(String id) async {
    final MemoryEntity? current = _find(id);
    if (current == null) return;
    final MemoryEntity updated = current.archive();
    await ref.read(saveMemoryUseCaseProvider).call(updated);
    _replace(updated);
  }

  Future<void> remove(String id) async {
    await ref.read(deleteMemoryUseCaseProvider).call(id);
    state = state
        .where((MemoryEntity memory) => memory.id != id)
        .toList(growable: false);
  }

  Future<void> deleteAll() async {
    await ref.read(domainMemoryRepositoryProvider).deleteAllMemories();
    state = const <MemoryEntity>[];
  }

  Map<String, dynamic> exportReceipts() {
    return <String, dynamic>{
      'schemaVersion': 1,
      'exportType': 'chronospark_memory_receipts',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'memoryReceipts': state
          .map((MemoryEntity memory) => memory.toReceipt().toJson())
          .toList(growable: false),
    };
  }

  MemoryEntity? _find(String id) {
    for (final MemoryEntity memory in state) {
      if (memory.id == id) return memory;
    }
    return null;
  }

  void _replace(MemoryEntity updated) {
    state = <MemoryEntity>[
      for (final MemoryEntity memory in state)
        if (memory.id == updated.id) updated else memory,
    ];
  }
}
