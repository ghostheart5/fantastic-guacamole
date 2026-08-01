import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum CreatorSavedKind { task, goal, routine, note }

final creatorActionsProvider = Provider<CreatorActions>(
  (ref) => CreatorActions(ref: ref),
);

class CreatorActions {
  const CreatorActions({required this.ref});

  final Ref ref;

  Future<CreatorSavedKind> createTask(CreatorFormData data) {
    return createEntry(data);
  }

  Future<CreatorSavedKind> createEntry(CreatorFormData data) async {
    final String mode = data.creatorMode.trim().toLowerCase();
    final String requestedKind = _kindFor(data, mode);
    final String kind = _normalizeKind(requestedKind);

    final RecurrenceRule recurrence = _recurrenceFor(
      kind: kind,
      requested: data.recurrenceRule,
    );

    if (kind == 'goal') {
      await _createGoal(data: data, recurrence: recurrence);
      await _markFirstItemCreated();
      return CreatorSavedKind.goal;
    }

    final int priority = _priorityFor(kind: kind, requested: data.priority);

    final TaskEntity entity;
    if (kind == 'note') {
      final NoteEntity note = NoteEntity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: data.title,
        body: data.description,
        createdAt: DateTime.now(),
      );
      entity = note.toTaskEntity(
        scheduledFor: data.scheduledFor,
        recurrenceRule: recurrence,
      );
    } else {
      entity = TaskEntity(
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
    }

    await ref
        .read(taskActionsProvider)
        .createTask(entity, actionSource: 'creator');
    await _markFirstItemCreated();
    return _savedKindFor(requestedKind: requestedKind);
  }

  CreatorSavedKind _savedKindFor({required String requestedKind}) {
    return switch (requestedKind.trim().toLowerCase()) {
      'goal' => CreatorSavedKind.goal,
      'routine' => CreatorSavedKind.routine,
      'note' => CreatorSavedKind.note,
      _ => CreatorSavedKind.task,
    };
  }

  Future<void> _createGoal({
    required CreatorFormData data,
    required RecurrenceRule recurrence,
  }) async {
    final String title = data.title.trim();
    final String? description = data.description?.trim().isEmpty ?? true
        ? null
        : data.description?.trim();

    switch (recurrence) {
      case RecurrenceRule.daily:
        await ref
            .read(goalsProvider.notifier)
            .addDaily(title: title, description: description);
        break;
      case RecurrenceRule.weekly:
        await ref
            .read(goalsProvider.notifier)
            .addWeekly(title: title, description: description);
        break;
      case RecurrenceRule.none:
        await ref
            .read(goalsProvider.notifier)
            .add(
              title: title,
              description: description,
              targetDate: data.scheduledFor,
            );
        break;
    }
  }

  Future<void> _markFirstItemCreated() async {
    ref.read(creatorFirstItemCreatedProvider.notifier).set(true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? userId = sb.Supabase.instance.client.auth.currentUser?.id;
      final String key = (userId == null || userId.trim().isEmpty)
          ? creatorFirstItemCreatedStorageKey
          : creatorFirstItemCreatedStorageKeyForUser(userId.trim());
      await prefs.setBool(key, true);
    } on Object {
      // Keep creation success non-blocking even if local persistence is unavailable.
    }
  }

  String _kindFor(CreatorFormData data, String mode) {
    return switch (mode) {
      'goals' => 'goal',
      'milestones' => 'milestone',
      'plan' => 'plan',
      'habits' => 'habit',
      _ => data.type.trim().toLowerCase(),
    };
  }

  String _normalizeKind(String kind) {
    return switch (kind) {
      'routine' => 'habit',
      _ => kind,
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
      'routine' || 'habit' => RecurrenceRule.daily,
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
      'routine' || 'habit' => 2,
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
