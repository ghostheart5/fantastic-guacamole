import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siMemoryProvider = NotifierProvider<SIMemoryController, SIMemory>(
  SIMemoryController.new,
);

// Read model for the latest SI memory snapshot used by assistant-facing UI.
final latestSiSnapshotProvider = Provider<SISnapshot?>((ref) {
  return ref.watch(siMemoryProvider).latest;
});

class SIMemoryController extends Notifier<SIMemory> {
  /// Assistant memory interface: captures and serves SI snapshots.
  @override
  SIMemory build() => const SIMemory();

  void capture(SISnapshot snapshot) {
    state = state.push(snapshot);
  }

  void clear() {
    state = state.clear();
  }
}
