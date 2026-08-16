import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/neural_history_provider.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_downstream_adapters.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_projection_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sole UI-command authority for complete, skip, and reschedule actions.
final taskOccurrenceCoordinatorProvider = Provider<TaskOccurrenceCoordinator>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final TaskOccurrenceCoordinator coordinator = TaskOccurrenceCoordinator(
    scope: scope,
    taskRepository: ref.read(domainTaskRepositoryProvider),
    occurrenceRepository: ref.read(taskOccurrenceRepositoryProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final taskOccurrenceProjectionCoordinatorProvider =
    Provider<TaskOccurrenceProjectionCoordinator>((Ref ref) {
      // This coordinator owns Account A's durable projection tail until the
      // auth lifecycle drains it and explicitly invalidates the provider.
      // Watching the live auth scope here would replace it with a signed-out
      // coordinator before that barrier can capture and drain Account A.
      final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
      final learningController = ref.read(learningProvider.notifier);
      final addLogEntry = ref.read(addLogEntryProvider);
      final neuralHistoryStore = ref.read(neuralHistoryStoreProvider);
      final TaskOccurrenceProjectionCoordinator coordinator =
          TaskOccurrenceProjectionCoordinator(
            scope: scope,
            timeline: ref.read(taskOccurrenceTimelineAdapterProvider),
            completion: ref.read(taskOccurrenceCompletionAdapterProvider),
            sync: ref.read(taskOccurrenceSyncAdapterProvider),
            workRepository: ref.read(
              taskOccurrenceProjectionWorkRepositoryProvider,
            ),
            occurrenceRepository: ref.read(taskOccurrenceRepositoryProvider),
            learning: TaskOccurrenceLearningAdapter(
              ({required bool success, required int difficulty}) =>
                  learningController.update(
                    success: success,
                    difficulty: difficulty,
                  ),
            ),
            log: TaskOccurrenceLogAdapter(addLogEntry.call),
            neural: TaskOccurrenceNeuralAdapter(neuralHistoryStore),
          );
      unawaited(coordinator.reconcile());
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
