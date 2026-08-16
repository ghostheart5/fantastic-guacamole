import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/sync/supabase_sync_executor.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseSyncExecutorProvider = Provider<SupabaseSyncExecutor>((Ref ref) {
  return SupabaseSyncExecutor(
    tasksGateway: ref.read(tasksRemoteGatewayProvider),
    goalsGateway: ref.read(goalsRemoteGatewayProvider),
    habitsGateway: ref.read(habitsRemoteGatewayProvider),
    habitOccurrencesGateway: ref.read(habitOccurrencesRemoteGatewayProvider),
    taskOccurrencesGateway: ref.read(taskOccurrencesRemoteGatewayProvider),
    settingsGateway: ref.read(settingsRemoteGatewayProvider),
    notesGateway: ref.read(notesRemoteGatewayProvider),
  );
});

/// The transport boundary used by the queue runner. Production resolves the
/// existing executor; tests may override only this function to control remote
/// completion without replacing queue selection or runner semantics.
final supabaseSyncApplyProvider = Provider<SyncApplyFn>((Ref ref) {
  return ref.watch(supabaseSyncExecutorProvider).apply;
});

final supabaseSyncRunnerProvider = Provider<SyncRunner>((Ref ref) {
  return SyncRunner(
    queueStore: ref.watch(syncQueueStoreProvider),
    applyFn: ref.watch(supabaseSyncApplyProvider),
  );
});

final supabaseSyncQueueCountProvider = FutureProvider<int>((Ref ref) async {
  final items = await ref.watch(syncQueueStoreProvider).readAll();
  return items.length;
});

final flushSupabaseSyncQueueProvider = FutureProvider<int>((Ref ref) async {
  final SyncRunner runner = ref.watch(supabaseSyncRunnerProvider);
  await runner.runOnce();
  final items = await ref.watch(syncQueueStoreProvider).readAll();
  return items.length;
});
