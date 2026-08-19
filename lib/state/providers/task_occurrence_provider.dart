import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/services/task_occurrence_cloud_replica.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final taskOccurrenceCoordinatorProvider = Provider<TaskOccurrenceCoordinator>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
    scope: scope,
    taskRepository: ref.read(domainTaskRepositoryProvider),
    occurrenceRepository: ref.read(taskOccurrenceRepositoryProvider),
    cloudReplica: ref.watch(taskOccurrenceCloudReplicaProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final taskOccurrenceCloudReplicaProvider =
    Provider<TaskOccurrenceCloudReplica?>((Ref ref) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null || client.auth.currentUser == null) {
        return null;
      }
      return SupabaseTaskOccurrenceCloudReplica(client);
    });
