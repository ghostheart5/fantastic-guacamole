import 'package:fantastic_guacamole/engine/si/si_memory.dart';
import 'package:fantastic_guacamole/engine/si/si_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siMemoryProvider = NotifierProvider<SIMemoryController, SIMemory>(
  SIMemoryController.new,
);

final latestSiSnapshotProvider = Provider<SISnapshot?>((ref) {
  return ref.watch(siMemoryProvider).latest;
});

class SIMemoryController extends Notifier<SIMemory> {
  @override
  SIMemory build() => const SIMemory();

  void capture(SISnapshot snapshot) {
    state = state.push(snapshot);
  }

  void clear() {
    state = state.clear();
  }
}
