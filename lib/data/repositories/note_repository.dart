import 'dart:convert';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';

class NoteRepository {
  NoteRepository(this._storage, {this.syncDispatcher});
  NoteRepository.unavailable({this.syncDispatcher})
    : _storage = null;
  final HiveStorage<String>? _storage;
  final SyncMutationDispatcher? syncDispatcher;
  bool _cancelled = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _writeQueue.catchError((Object _) {});
  }

  void dispose() {
    _cancelled = true;
  }

  HiveStorage<String> get _target =>
      _storage ??
      (throw StateError('Note storage is unavailable while signed out.'));
  Future<List<NoteEntity>> getNotes({bool includeArchived = false}) async {
    await _target.open();
    final List<NoteEntity> notes = _target.getAll().values
        .map((String raw) => NoteEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .where((NoteEntity note) => includeArchived || !note.isArchived)
        .toList();
    notes.sort((NoteEntity a, NoteEntity b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<void> save(NoteEntity note) => _serializeWrite(() async {
    await _target.put(note.id, jsonEncode(note.toJson()));
    await syncDispatcher?.enqueueUpsert(
      tableName: 'notes',
      recordId: note.id,
      payload: _syncPayload(note),
    );
  });

  Future<NoteEntity?> archive(String id) async {
    await _target.open();
    final String? raw = _target.get(id);
    if (raw == null) return null;
    final NoteEntity note = NoteEntity.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    final NoteEntity archived = note.copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    await save(archived);
    return archived;
  }

  Future<void> delete(String id) => _serializeWrite(() async {
    await _target.delete(id);
    await syncDispatcher?.enqueueDelete(tableName: 'notes', recordId: id);
  });

  Future<void> _serializeWrite(Future<void> Function() action) {
    if (_cancelled) {
      return Future<void>.error(
        StateError('Note mutation canceled during account transition.'),
      );
    }
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  Map<String, dynamic> _syncPayload(NoteEntity note) => <String, dynamic>{
    'id': note.id,
    'title': note.title,
    'body': note.body,
    'created_at': note.createdAt.toUtc().toIso8601String(),
    'updated_at': note.updatedAt.toUtc().toIso8601String(),
    'is_archived': note.isArchived,
    'goal_id': note.goalId,
    'task_id': note.taskId,
    'habit_id': note.habitId,
    'deleted_at': null,
  };
}
