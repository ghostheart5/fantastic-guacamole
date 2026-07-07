import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creatorActionsProvider = Provider<CreatorActions>((ref) => CreatorActions(ref: ref));

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
      'goal' || 'mission' => 5,
      _ => 3,
    };

    final int energyRequired = switch (kind) {
      'goal' => 4,
      'mission' => 3,
      'routine' => 2,
      'note' => 1,
      _ => 3,
    };

    final int priority = switch (kind) {
      'goal' || 'mission' => data.priority < 4 ? 4 : data.priority,
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
  }
}
