import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/data/adapters/note_timeline_adapter.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_read_health.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteEntity>>(
  NotesNotifier.new,
);

/// Lets UI distinguish a valid empty collection from a damaged local payload.
/// Readable records stay usable while the recovery warning remains visible.
final noteReadCorruptedProvider = Provider<bool>((Ref ref) {
  ref.watch(notesProvider);
  final repository = ref.watch(domainNoteRepositoryProvider);
  return repository is NoteReadHealth &&
      (repository as NoteReadHealth).lastReadCorrupted;
});

class NotesNotifier extends AsyncNotifier<List<NoteEntity>> {
  @override
  Future<List<NoteEntity>> build() => ref.watch(getNotesUseCaseProvider).call();

  List<NoteEntity> get _current => state is AsyncData<List<NoteEntity>>
      ? (state as AsyncData<List<NoteEntity>>).value
      : const <NoteEntity>[];

  Future<void> createNote({
    required String title,
    String? body,
    NoteKind kind = NoteKind.note,
    String? goalId,
    String? taskId,
    String? habitId,
    String? occurrenceId,
    String? outcomeId,
    String? userId,
  }) async {
    final owner = AccountOperation.capture(ref);
    owner.check();
    // Bind the supporting writer before waiting for canonical persistence.
    final projection = ref.read(noteTimelineAdapterProvider);
    final NoteEntity? note = await ref
        .read(createNoteUseCaseProvider)
        .call(
          title: title,
          body: body,
          kind: kind,
          goalId: goalId,
          taskId: taskId,
          habitId: habitId,
          occurrenceId: occurrenceId,
          outcomeId: outcomeId,
          userId: userId,
        );
    if (note == null || !owner.isCurrent) return;
    state = AsyncData(<NoteEntity>[note, ..._current]);
    try {
      await projection.record(note, NoteTimelineMutation.created);
      if (owner.isCurrent) ref.invalidate(timelineProvider);
    } on Object {
      // The note is already saved in the captured account.
    }
  }

  Future<void> updateNote(NoteEntity note) async {
    final owner = ref.read(accountStorageScopeProvider);
    if (!owner.isWritable) throw StateError('Sign in to edit notes.');
    final generation = ref.read(authSessionBoundaryProvider).generation;
    final repository = ref.read(domainNoteRepositoryProvider);
    final goals = ref.read(domainGoalRepositoryProvider);
    final tasks = ref.read(domainTaskRepositoryProvider);
    final habits = ref.read(domainHabitRepositoryProvider);
    final update = ref.read(updateNoteUseCaseProvider);
    final current = (await repository.getNotes())
        .where((item) => item.id == note.id)
        .firstOrNull;
    if (current == null ||
        current.isArchived ||
        current.updatedAt != note.updatedAt) {
      throw StateError('The note changed; reopen it before editing.');
    }
    if (note.goalId != null &&
        !readAvailableGoals(goals).any((goal) => goal.id == note.goalId)) {
      throw StateError('Linked goal is unavailable.');
    }
    if (note.taskId != null) {
      final task = await tasks.getTaskById(note.taskId!);
      if (task == null ||
          (note.goalId != null &&
              task.goalId != null &&
              note.goalId != task.goalId)) {
        throw StateError(
          'Linked task and goal must refer to the same commitment.',
        );
      }
    }
    if (note.habitId != null &&
        !(await habits.getHabits()).any((habit) => habit.id == note.habitId)) {
      throw StateError('Linked Daily Rhythm is unavailable.');
    }
    if (!ref.mounted ||
        ref.read(authSessionBoundaryProvider).generation != generation ||
        ref.read(accountStorageScopeProvider).v2Namespace !=
            owner.v2Namespace) {
      return;
    }
    final NoteEntity next = await update.call(note);
    if (!ref.mounted ||
        ref.read(authSessionBoundaryProvider).generation != generation ||
        ref.read(accountStorageScopeProvider).v2Namespace !=
            owner.v2Namespace) {
      return;
    }
    state = AsyncData(<NoteEntity>[
      for (final NoteEntity item in _current)
        if (item.id == next.id) next else item,
    ]);
    await _project(next, NoteTimelineMutation.updated);
  }

  Future<void> archiveNote(String id) async {
    final owner = ref.read(accountStorageScopeProvider);
    if (!owner.isWritable) throw StateError('Sign in to archive notes.');
    final generation = ref.read(authSessionBoundaryProvider).generation;
    final NoteEntity? archived = await ref
        .read(archiveNoteUseCaseProvider)
        .call(id);
    if (!ref.mounted ||
        ref.read(authSessionBoundaryProvider).generation != generation ||
        ref.read(accountStorageScopeProvider).v2Namespace !=
            owner.v2Namespace) {
      return;
    }
    state = AsyncData(
      _current.where((NoteEntity note) => note.id != id).toList(),
    );
    if (archived != null) {
      await _project(archived, NoteTimelineMutation.archived);
    }
  }

  Future<void> restoreNote(String id) async {
    final owner = AccountOperation.capture(ref);
    owner.check();
    final repository = ref.read(domainNoteRepositoryProvider);
    final notes = await repository.getNotes();
    final NoteEntity? current = notes
        .where((note) => note.id == id)
        .firstOrNull;
    if (current == null || !current.isArchived || !owner.isCurrent) return;
    final restored = current.copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );
    await repository.saveNote(restored);
    if (!owner.isCurrent) return;
    state = AsyncData(<NoteEntity>[
      restored,
      ..._current.where((note) => note.id != id),
    ]);
    await _project(restored, NoteTimelineMutation.updated);
  }

  Future<void> _project(NoteEntity note, NoteTimelineMutation mutation) async {
    final owner = AccountOperation.capture(ref);
    try {
      await ref.read(noteTimelineAdapterProvider).record(note, mutation);
      if (owner.isCurrent) ref.invalidate(timelineProvider);
    } on Object {
      // Timeline is a best-effort history projection; canonical Note truth has
      // already been stored and must not be rolled back by this failure.
    }
  }
}

final noteTimelineAdapterProvider = Provider<NoteTimelineAdapter>((Ref ref) {
  return NoteTimelineAdapter(ref.watch(timelineRepositoryProvider));
});
