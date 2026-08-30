import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/models/creator_creation_receipt.dart';
import 'package:fantastic_guacamole/state/providers/creator_receipt_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fantastic_guacamole/state/models/creator_creation_receipt.dart';

final creatorActionsProvider = Provider<CreatorActions>(
  (ref) => CreatorActions(ref: ref),
);

class CreatorActions {
  const CreatorActions({required this.ref});

  final Ref ref;

  Future<void> createTask(CreatorFormData data) async {
    final String kind = data.type.trim().toLowerCase();
    if (kind != 'task') {
      throw ArgumentError.value(
        data.type,
        'data.type',
        'CreatorActions.createTask only creates Task objects. Use the typed '
            'Creator handshake for Goal, Daily Rhythm, Note, or Reflection.',
      );
    }

    final entity = TaskEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: data.title,
      description: data.description,
      createdAt: DateTime.now(),
      priority: data.priority,
      difficulty: 3,
      energyRequired: 3,
      scheduledFor: data.scheduledFor,
      dueDate: data.dueDate,
      estimatedDuration: data.estimatedDuration,
      goalId: data.goalId,
      recurrenceRule: data.recurrenceRule,
    );
    await ref.read(taskActionsProvider).createTask(entity);
    // Creator persists directly through the task repository. Refresh the
    // canonical planning projection so Nexus receives the new real block
    // immediately instead of retaining its pre-save aggregation snapshot.
    ref.invalidate(siStateAggregationProvider);
    try {
      await ref
          .read(latestCreatorReceiptProvider.notifier)
          .record(
            CreatorCreationReceipt(
              id: entity.id,
              kind: CreatorSavedKind.task,
              title: entity.title,
              createdAt: entity.createdAt,
              whyItMatters: 'It gives Smart Planner a concrete action to rank.',
              nextAction: 'Review its priority in Smart Planner.',
            ),
          );
    } on Object catch (error, stackTrace) {
      // The task is already durable. A secondary receipt failure must not tell
      // the user that the task write failed or encourage a duplicate retry.
      Logger.errorCategory(
        'CreatorReceipt',
        'Task saved, but its Creator receipt could not be recorded.',
        error,
        stackTrace,
      );
    }
  }
}
