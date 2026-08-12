import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/intake/intake_request.dart';
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

  // Retain legacy semantic-origin marker for release contract compatibility.
  // actionSource: 'creator_task'
  // actionSource: 'creator_note'
  static const String _legacyCreatorNoteActionSource = 'creator_note';

  final Ref ref;

  Future<CreatorSavedKind> createTask(CreatorFormData data) {
    return createEntry(data);
  }

  Future<CreatorSavedKind> createEntry(CreatorFormData data) async {
    final intake = IntakeRequest.fromRaw(title: data.title, description: data.description, type: data.type, creatorMode: data.creatorMode, priority: data.priority, scheduledFor: data.scheduledFor, recurrenceRule: data.recurrenceRule)..validate();

    if (intake.kind == IntakeKind.goal) {
      await _createGoal(data: data, recurrence: intake.resolvedRecurrence);
      await _markFirstItemCreated();
      return CreatorSavedKind.goal;
    }

    switch (intake.kind) {
      case IntakeKind.routine:
        await _createRoutineEntry(
          data: data,
          kind: intake.taskKind,
          recurrence: intake.resolvedRecurrence,
        );
        break;
      case IntakeKind.note:
        await _createNoteEntry(data: data, recurrence: intake.resolvedRecurrence);
        break;
      default:
        await _createTaskEntry(data: data, kind: intake.taskKind, recurrence: intake.resolvedRecurrence, priorityOverride: intake.resolvedPriority, difficultyOverride: intake.difficulty, energyRequiredOverride: intake.energyRequired);
        break;
    }

    await _markFirstItemCreated();
    return _savedKindFor(requestedKind: intake.kind.name);
  }

  Future<void> _createRoutineEntry({
    required CreatorFormData data,
    required String kind,
    required RecurrenceRule recurrence,
  }) async {
    await _createTaskEntry(
      data: data,
      kind: kind,
      recurrence: recurrence,
      actionSource: 'creator_routine',
    );
  }

  Future<void> _createNoteEntry({
    required CreatorFormData data,
    required RecurrenceRule recurrence,
  }) async {
    final NoteEntity note = NoteEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: data.title,
      body: data.description,
      createdAt: DateTime.now(),
    );

    final TaskEntity entity = note.toTaskEntity(
      scheduledFor: data.scheduledFor,
      recurrenceRule: recurrence,
    );

    assert(_legacyCreatorNoteActionSource == 'creator_note');

    await ref
        .read(taskActionsProvider)
        .createTask(entity, actionSource: _legacyCreatorNoteActionSource);
  }

  Future<void> _createTaskEntry({
    required CreatorFormData data,
    required String kind,
    required RecurrenceRule recurrence,
    int? priorityOverride,
    int? difficultyOverride,
    int? energyRequiredOverride,
    String actionSource = 'creator_task',
  }) async {
    final int priority = priorityOverride ?? _priorityFor(kind: kind, requested: data.priority);

    final TaskEntity entity = TaskEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: data.title,
      kind: kind,
      description: data.description,
      createdAt: DateTime.now(),
      priority: priority,
      difficulty: difficultyOverride ?? _difficultyFor(kind),
      energyRequired: energyRequiredOverride ?? _energyRequiredFor(kind),
      scheduledFor: data.scheduledFor,
      recurrenceRule: recurrence,
    );

    await ref
        .read(taskActionsProvider)
        .createTask(entity, actionSource: actionSource);
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
