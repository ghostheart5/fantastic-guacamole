import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final memoriesActionsProvider = Provider<MemoriesActions>((Ref ref) {
  return MemoriesActions(ref);
});

final memoriesProvider = NotifierProvider<MemoriesNotifier, List<MemoryEntity>>(
  MemoriesNotifier.new,
);

class MemoriesActions {
  const MemoriesActions(this._ref);

  final Ref _ref;

  Future<void> saveMemory(String text) {
    return _ref.read(memoriesProvider.notifier).capture(text);
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
    bool refreshCoach = true,
    bool syncSoulMap = true,
  }) async {
    final String normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }
    final memory = MemoryEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: normalizedText,
      date: DateTime.now(),
    );
    final updated = [memory, ...state];
    state = updated.length > _maxEntries
        ? updated.sublist(0, _maxEntries)
        : updated;
    await ref.read(saveMemoryUseCaseProvider).call(memory);

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

  Future<void> remove(String id) async {
    await ref.read(deleteMemoryUseCaseProvider).call(id);
    state = state.where((m) => m.id != id).toList(growable: false);
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
