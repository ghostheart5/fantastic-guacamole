import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';

class NoteRepository implements INoteRepository {
  NoteRepository(this._store, {KeyedMutationCoordinator? mutationCoordinator})
    : _mutationCoordinator =
          mutationCoordinator ?? KeyedMutationCoordinator.shared;

  final SharedPrefsStore _store;
  final KeyedMutationCoordinator _mutationCoordinator;

  static const String _key = 'notes_v1';
  static const String _corruptBackupKey = 'notes_v1_corrupt_backup';
  static const int _maxCorruptBackups = 3;

  @override
  Future<List<NoteEntity>> getNotes() async {
    return List<NoteEntity>.unmodifiable(_readNotes().notes);
  }

  _DecodedNotes _readNotes() {
    final raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const _DecodedNotes(<NoteEntity>[]);
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Notes payload is not a list.');
      }
      final List<NoteEntity> notes = <NoteEntity>[];
      bool rejectedEntry = false;
      for (final Object? entry in decoded) {
        if (entry is! Map<String, dynamic>) {
          rejectedEntry = true;
          continue;
        }
        try {
          _validateStoredNote(entry);
          notes.add(NoteEntity.fromJson(entry));
        } on Object {
          rejectedEntry = true;
        }
      }
      if (rejectedEntry) {
        Logger.errorCategory(
          'StorageCorruption',
          'Stored Notes contain unreadable records. Valid records remain '
              'available and the original payload will be preserved before '
              'the next mutation.',
        );
        return _DecodedNotes(notes, corruptRaw: raw);
      }
      return _DecodedNotes(notes);
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode stored Notes. The unreadable payload will be '
            'preserved before the next mutation.',
        error,
        stackTrace,
      );
      return _DecodedNotes(const <NoteEntity>[], corruptRaw: raw);
    }
  }

  @override
  Future<void> saveNote(NoteEntity note) {
    return _mutate((List<NoteEntity> notes) {
      final int index = notes.indexWhere(
        (NoteEntity item) => item.id == note.id,
      );
      if (index >= 0) {
        notes[index] = note;
      } else {
        notes.insert(0, note);
      }
    });
  }

  @override
  Future<void> deleteNote(String id) {
    return _mutate(
      (List<NoteEntity> notes) =>
          notes.removeWhere((NoteEntity note) => note.id == id),
    );
  }

  Future<void> _mutate(void Function(List<NoteEntity> notes) mutation) {
    return runAccountStorageMutation(() async {
      final _DecodedNotes decoded = _readNotes();
      if (decoded.corruptRaw case final String raw) {
        await _preserveCorruptPayload(raw);
      }
      final List<NoteEntity> notes = decoded.notes.toList(growable: true);
      mutation(notes);
      await _store.save(
        _key,
        jsonEncode(
          notes.map((NoteEntity note) => note.toJson()).toList(growable: false),
        ),
      );
    }, coordinator: _mutationCoordinator);
  }

  Future<void> _preserveCorruptPayload(String raw) async {
    final String? existing = _store.load(_corruptBackupKey);
    final List<String> payloads = <String>[];
    if (existing != null) {
      try {
        final Object? decoded = jsonDecode(existing);
        if (decoded is! Map<String, dynamic> ||
            decoded['schemaVersion'] != 1 ||
            decoded['payloads'] is! List<dynamic>) {
          throw const FormatException('Unsupported Notes recovery envelope.');
        }
        payloads.addAll(
          (decoded['payloads'] as List<dynamic>).whereType<String>(),
        );
      } on Object {
        // Preserve recovery bytes written by the original single-slot format.
        payloads.add(existing);
      }
    }
    if (!payloads.contains(raw)) payloads.add(raw);
    final int start = payloads.length > _maxCorruptBackups
        ? payloads.length - _maxCorruptBackups
        : 0;
    await _store.save(
      _corruptBackupKey,
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'payloads': payloads.sublist(start),
      }),
    );
    Logger.errorCategory(
      'StorageCorruption',
      'Preserved unreadable Notes before replacing the active payload.',
    );
  }

  void _validateStoredNote(Map<String, dynamic> entry) {
    final Object? id = entry['id'];
    final Object? title = entry['title'];
    final Object? createdAt = entry['createdAt'];
    final Object? updatedAt = entry['updatedAt'];
    final Object? isArchived = entry['isArchived'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null ||
        (updatedAt != null &&
            (updatedAt is! String || DateTime.tryParse(updatedAt) == null)) ||
        (isArchived != null && isArchived is! bool)) {
      throw const FormatException('Stored Note has invalid required fields.');
    }
  }
}

class _DecodedNotes {
  const _DecodedNotes(this.notes, {this.corruptRaw});

  final List<NoteEntity> notes;
  final String? corruptRaw;
}
