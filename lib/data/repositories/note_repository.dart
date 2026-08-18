import 'dart:convert';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';

class NoteRepository {
  NoteRepository(this._store);
  final SharedPrefsStore _store;
  static const String _key = 'notes_v1';

  Future<List<NoteEntity>> getNotes() async {
    final raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) return const <NoteEntity>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().map(NoteEntity.fromJson).toList(growable: false);
    } catch (_) {
      return const <NoteEntity>[];
    }
  }

  Future<void> save(NoteEntity note) async {
    final notes = (await getNotes()).toList();
    final index = notes.indexWhere((item) => item.id == note.id);
    if (index >= 0) { notes[index] = note; } else { notes.insert(0, note); }
    await _store.save(_key, jsonEncode(notes.map((item) => item.toJson()).toList()));
  }

  Future<NoteEntity?> archive(String id) async {
    final notes = await getNotes();
    final index = notes.indexWhere((item) => item.id == id);
    if (index < 0) return null;
    final archived = notes[index].copyWith(isArchived: true, updatedAt: DateTime.now());
    await save(archived);
    return archived;
  }
}
