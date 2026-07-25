import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creatorActionsProvider = Provider<CreatorActions>(
  (ref) => CreatorActions(ref: ref),
);

class CreatorActions {
  const CreatorActions({required this.ref});

  final Ref ref;

  Future<void> createTask(CreatorFormData data) {
    return createEntry(data);
  }

  Future<void> createEntry(CreatorFormData data) async {
    final String mode = data.creatorMode.trim().toLowerCase();
    final String kind = _kindFor(data, mode);

    final RecurrenceRule recurrence = _recurrenceFor(
      kind: kind,
      requested: data.recurrenceRule,
    );

    final int priority = _priorityFor(kind: kind, requested: data.priority);

    final entity = TaskEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: data.title,
      kind: kind,
      description: data.description,
      createdAt: DateTime.now(),
      priority: priority,
      difficulty: _difficultyFor(kind),
      energyRequired: _energyRequiredFor(kind),
      scheduledFor: data.scheduledFor,
      recurrenceRule: recurrence,
    );

    await ref.read(taskActionsProvider).createTask(entity);
  }

  String _kindFor(CreatorFormData data, String mode) {
    return switch (mode) {
      'goals' => 'goal',
      'milestones' => 'milestone',
      'plan' => 'plan',
      _ => data.type.trim().toLowerCase(),
    };
  }

  RecurrenceRule _recurrenceFor({
    required String kind,
    required RecurrenceRule requested,
  }) {
    if (requested != RecurrenceRule.none) {
      return requested;
    }

    return switch (kind) {
      'routine' => RecurrenceRule.daily,
      _ => RecurrenceRule.none,
    };
  }

  int _difficultyFor(String kind) {
    return switch (kind) {
      'goal' => 5,
      'mission' => 5,
      'milestone' => 4,
      'plan' => 3,
      _ => 3,
    };
  }

  int _energyRequiredFor(String kind) {
    return switch (kind) {
      'goal' => 4,
      'mission' => 3,
      'milestone' => 3,
      'plan' => 2,
      'routine' => 2,
      'note' => 1,
      _ => 3,
    };
  }

  int _priorityFor({required String kind, required int requested}) {
    return switch (kind) {
      'goal' => requested < 4 ? 4 : requested,
      'mission' => requested < 4 ? 4 : requested,
      'milestone' => requested < 3 ? 3 : requested,
      'plan' => requested < 2 ? 2 : requested,
      'note' => 1,
      _ => requested,
    };
  }
}
