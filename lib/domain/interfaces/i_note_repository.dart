// CHRONOSPARK-CLASS: SHIPPING | Feature: Notes
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';

abstract class INoteRepository {
  Future<List<NoteEntity>> getNotes();
  Future<void> saveNote(NoteEntity note);
  Future<void> deleteNote(String id);
}
