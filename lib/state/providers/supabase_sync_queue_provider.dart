import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/sync/supabase_sync_executor.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseSyncExecutorProvider = Provider<SupabaseSyncExecutor>((Ref ref) {
  return SupabaseSyncExecutor(
    tasksGateway: ref.read(tasksRemoteGatewayProvider),
    goalsGateway: ref.read(goalsRemoteGatewayProvider),
    habitsGateway: ref.read(habitsRemoteGatewayProvider),
    settingsGateway: ref.read(settingsRemoteGatewayProvider),
  );
});

final supabaseSyncRunnerProvider = Provider<SyncRunner>((Ref ref) {
  final SupabaseSyncExecutor executor = ref.read(supabaseSyncExecutorProvider);
  return SyncRunner(
    queueStore: ref.read(syncQueueStoreProvider),
    applyFn: executor.apply,
  );
});

final supabaseSyncQueueCountProvider = FutureProvider<int>((Ref ref) async {
  final items = await ref.read(syncQueueStoreProvider).readAll();
  return items.length;
});

final flushSupabaseSyncQueueProvider = FutureProvider<int>((Ref ref) async {
  final SyncRunner runner = ref.read(supabaseSyncRunnerProvider);
  await runner.runOnce();
  final items = await ref.read(syncQueueStoreProvider).readAll();
  return items.length;
});
