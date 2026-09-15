// CHRONOSPARK-CLASS: SHIPPING | Feature: Notes
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';

abstract interface class NoteReadHealth {
  bool get lastReadCorrupted;
}

class NoteReadUnavailable implements Exception {
  const NoteReadUnavailable();

  @override
  String toString() =>
      'Stored notes are partly or wholly unreadable; existing bytes were preserved.';
}

abstract class INoteRepository {
  Future<List<NoteEntity>> getNotes();
  Future<void> saveNote(NoteEntity note);
  Future<void> deleteNote(String id);
}
