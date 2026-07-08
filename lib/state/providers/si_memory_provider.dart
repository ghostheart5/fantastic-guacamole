import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siMemoryProvider = NotifierProvider<SIMemoryController, SIMemory>(SIMemoryController.new);

// Read model for the latest SI memory snapshot used by assistant-facing UI.
final latestSiSnapshotProvider = Provider<SISnapshot?>((ref) {
  return ref.watch(siMemoryProvider).latest;
});

class SIMemoryController extends Notifier<SIMemory> implements AssistantMemoryInterface {
  /// Assistant memory interface: captures and serves SI snapshots.
  @override
  SIMemory build() => const SIMemory();

  @override
  List<SISnapshot> recentSnapshots({int limit = 24}) {
    return state.entries.take(limit).toList(growable: false);
  }

  @override
  void capture(SISnapshot snapshot) {
    state = state.push(snapshot);
  }

  @override
  void clear() {
    state = state.clear();
  }
}
