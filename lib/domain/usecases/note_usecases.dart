import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';

class GetNotes {
  const GetNotes(this._repository);

  final INoteRepository _repository;

  Future<List<NoteEntity>> call() => _repository.getNotes();
}

class CreateNote {
  const CreateNote(this._repository);

  final INoteRepository _repository;

  Future<NoteEntity?> call({
    required String title,
    String? body,
    String? id,
    DateTime? now,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final DateTime timestamp = now ?? DateTime.now();
    final NoteEntity note = NoteEntity(
      id: id ?? timestamp.microsecondsSinceEpoch.toString(),
      title: trimmed,
      body: body?.trim(),
      createdAt: timestamp,
    );
    await _repository.saveNote(note);
    return note;
  }
}

class UpdateNote {
  const UpdateNote(this._repository);

  final INoteRepository _repository;

  Future<NoteEntity> call(NoteEntity note, {DateTime? now}) async {
    final NoteEntity updated = note.copyWith(updatedAt: now ?? DateTime.now());
    await _repository.saveNote(updated);
    return updated;
  }
}

class ArchiveNote {
  const ArchiveNote(this._repository);

  final INoteRepository _repository;

  Future<NoteEntity?> call(String id, {DateTime? now}) async {
    final List<NoteEntity> notes = await _repository.getNotes();
    final int index = notes.indexWhere((NoteEntity note) => note.id == id);
    if (index < 0) return null;
    final NoteEntity archived = notes[index].copyWith(
      isArchived: true,
      updatedAt: now ?? DateTime.now(),
    );
    await _repository.saveNote(archived);
    return archived;
  }
}

class DeleteNote {
  const DeleteNote(this._repository);

  final INoteRepository _repository;

  Future<void> call(String id) {
    if (id.trim().isEmpty) return Future<void>.value();
    return _repository.deleteNote(id);
  }
}
