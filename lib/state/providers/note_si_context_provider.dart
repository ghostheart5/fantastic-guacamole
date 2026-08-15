import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SIContextEntityType { note }

/// Read-only contextual Note shape for SI consumers. This is intentionally
/// separate from actionable planner inputs and from Note persistence.
class SINoteContext {
  const SINoteContext({
    required this.id,
    required this.title,
    required this.body,
    required this.goalId,
    required this.taskId,
    required this.habitId,
  });

  final String id;
  final String title;
  final String? body;
  final String? goalId;
  final String? taskId;
  final String? habitId;
  SIContextEntityType get type => SIContextEntityType.note;

  factory SINoteContext.fromNote(NoteEntity note) => SINoteContext(
    id: note.id,
    title: note.title,
    body: note.body,
    goalId: note.goalId,
    taskId: note.taskId,
    habitId: note.habitId,
  );
}

/// Active Notes only. Archived Notes are historical and excluded from active
/// SI context. Consumers may read this provider but cannot mutate Notes here.
final siNoteContextProvider = Provider<AsyncValue<List<SINoteContext>>>((Ref ref) {
  return ref.watch(notesProvider).whenData(
    (List<NoteEntity> notes) => notes
        .where((NoteEntity note) => !note.isArchived)
        .map(SINoteContext.fromNote)
        .toList(growable: false),
  );
});
