import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/state/models/assistant_memory_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siMemoryProvider =
    NotifierProvider<SIMemoryController, AssistantSessionMemory>(
      SIMemoryController.new,
    );

/// Smart Planner has a private in-memory history. It must never read the SI
/// Console snapshots held by [siMemoryProvider].
final smartPlannerMemoryProvider =
    NotifierProvider<SIMemoryController, AssistantSessionMemory>(
      SIMemoryController.new,
    );

// Read model for the latest SI memory snapshot used by assistant-facing UI.
final latestSiSnapshotProvider = Provider<AssistantMemorySnapshot?>((ref) {
  return ref.watch(siMemoryProvider).latest;
});

final latestSmartPlannerSnapshotProvider = Provider<AssistantMemorySnapshot?>((
  ref,
) {
  return ref.watch(smartPlannerMemoryProvider).latest;
});

class SIMemoryController extends Notifier<AssistantSessionMemory>
    implements AssistantMemoryInterface {
  /// Assistant memory interface: captures and serves SI snapshots.
  @override
  AssistantSessionMemory build() => const AssistantSessionMemory();

  @override
  List<AssistantMemorySnapshot> recentSnapshots({int limit = 24}) {
    return state.entries.take(limit).toList(growable: false);
  }

  @override
  void capture(AssistantMemorySnapshot snapshot) {
    state = state.push(snapshot);
  }

  @override
  void clear() {
    state = state.clear();
  }
}
