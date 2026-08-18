import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
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
    final RecurrenceRule recurrence = data.recurrenceRule != RecurrenceRule.none
        ? data.recurrenceRule
        : switch (kind) {
            'routine' => RecurrenceRule.daily,
            _ => RecurrenceRule.none,
          };

    final int difficulty = switch (kind) {
      'goal' => 5,
      _ => 3,
    };

    final int energyRequired = switch (kind) {
      'goal' => 4,
      'routine' => 2,
      'note' => 1,
      _ => 3,
    };

    final int priority = switch (kind) {
      'goal' => data.priority < 4 ? 4 : data.priority,
      'note' => 1,
      _ => data.priority,
    };

    final entity = TaskEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: data.title,
      description: data.description,
      createdAt: DateTime.now(),
      priority: priority,
      difficulty: difficulty,
      energyRequired: energyRequired,
      scheduledFor: data.scheduledFor,
      recurrenceRule: recurrence,
    );
    await ref.read(taskActionsProvider).createTask(entity);
    await ref
        .read(latestCreatorReceiptProvider.notifier)
        .record(
          CreatorCreationReceipt(
            id: entity.id,
            kind: switch (kind) {
              'goal' => CreatorSavedKind.goal,
              'routine' => CreatorSavedKind.routine,
              'note' => CreatorSavedKind.note,
              'plan' => CreatorSavedKind.plan,
              _ => CreatorSavedKind.task,
            },
            title: entity.title,
            createdAt: entity.createdAt,
            whyItMatters: switch (kind) {
              'goal' => 'It gives planning a measurable outcome to protect.',
              'routine' => 'It adds a recurring commitment to daily planning.',
              'note' => 'It preserves decision context for later review.',
              'plan' => 'It turns intent into a schedulable planning input.',
              _ => 'It gives Smart Planner a concrete action to rank.',
            },
            nextAction: switch (kind) {
              'note' => 'Review the context in Smart Planner.',
              'plan' => 'Review timing and conflicts in Timeline.',
              _ => 'Review its priority in Smart Planner.',
            },
          ),
        );
  }
}
