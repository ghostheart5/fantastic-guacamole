import 'package:fantastic_guacamole/data/adapters/note_timeline_adapter.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteEntity>>(
  NotesNotifier.new,
);

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
    if (note == null) return;
    state = AsyncData(<NoteEntity>[note, ..._current]);
    await _project(note, NoteTimelineMutation.created);
  }

  Future<void> updateNote(NoteEntity note) async {
    final NoteEntity next = await ref
        .read(updateNoteUseCaseProvider)
        .call(note);
    state = AsyncData(<NoteEntity>[
      for (final NoteEntity item in _current)
        if (item.id == next.id) next else item,
    ]);
    await _project(next, NoteTimelineMutation.updated);
  }

  Future<void> archiveNote(String id) async {
    final NoteEntity? archived = await ref
        .read(archiveNoteUseCaseProvider)
        .call(id);
    state = AsyncData(
      _current.where((NoteEntity note) => note.id != id).toList(),
    );
    if (archived != null) {
      await _project(archived, NoteTimelineMutation.archived);
    }
  }

  Future<void> _project(NoteEntity note, NoteTimelineMutation mutation) async {
    try {
      await ref.read(noteTimelineAdapterProvider).record(note, mutation);
    } on Object {
      // Timeline is a best-effort history projection; canonical Note truth has
      // already been stored and must not be rolled back by this failure.
    }
  }
}

final noteTimelineAdapterProvider = Provider<NoteTimelineAdapter>((Ref ref) {
  return NoteTimelineAdapter(ref.read(timelineRepositoryProvider));
});
