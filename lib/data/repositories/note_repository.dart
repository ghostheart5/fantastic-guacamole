import 'dart:convert';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';

class NoteRepository implements INoteRepository {
  NoteRepository(this._store);
  final SharedPrefsStore _store;
  static const String _key = 'notes_v1';

  @override
  Future<List<NoteEntity>> getNotes() async {
    final raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) return const <NoteEntity>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NoteEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <NoteEntity>[];
    }
  }

  @override
  Future<void> saveNote(NoteEntity note) async {
    final notes = (await getNotes()).toList();
    final index = notes.indexWhere((item) => item.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.insert(0, note);
    }
    await _store.save(
      _key,
      jsonEncode(notes.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    final List<NoteEntity> notes = await getNotes();
    await _store.save(
      _key,
      jsonEncode(
        notes
            .where((NoteEntity note) => note.id != id)
            .map((NoteEntity note) => note.toJson())
            .toList(growable: false),
      ),
    );
  }
}
