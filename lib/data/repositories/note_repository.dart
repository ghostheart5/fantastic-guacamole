import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';

abstract interface class IExactNoteSnapshotRepository {
  Future<void> replaceNoteSnapshot(List<NoteEntity> notes);
}

class NoteRepository implements INoteRepository, IExactNoteSnapshotRepository {
  NoteRepository(
    this._store, {
    this.scope,
    this.legacyOwnership = LegacyScopeOwnership.ambiguous,
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _mutationCoordinator =
           mutationCoordinator ?? KeyedMutationCoordinator.shared;

  final SharedPrefsStore _store;
  final AccountStorageScope? scope;
  final LegacyScopeOwnership legacyOwnership;
  final KeyedMutationCoordinator _mutationCoordinator;

  static const String _key = 'notes_v1';
  static const String _scopedDataMarker = 'scopedV2';
  static const int _maxCorruptBackups = 3;
  bool _lastReadCorrupted = false;

  bool get lastReadCorrupted => _lastReadCorrupted;

  @override
  Future<List<NoteEntity>> getNotes() async {
    await _prepareScopedStorage();
    final _DecodedNotes decoded = _readNotes();
    _lastReadCorrupted = decoded.corruptRaw != null;
    return List<NoteEntity>.unmodifiable(decoded.notes);
  }

  String get _storageKey {
    final AccountStorageScope? activeScope = scope;
    if (activeScope == null) return _key;
    final String? namespace = activeScope.v2Namespace;
    if (!activeScope.isWritable || namespace == null) {
      throw StateError('Notes require authenticated account storage.');
    }
    return '$_key.$namespace';
  }

  String get _corruptStorageKey => '${_storageKey}_corrupt_backup';
  String get _migrationStorageKey => '${_storageKey}_migration_v1';

  Future<void> _prepareScopedStorage() async {
    await _store.init();
    if (scope == null) return;
    final String? migrationMarker = _store.load(_migrationStorageKey);
    if (migrationMarker == LegacyScopeOwnership.provenOwned.name ||
        migrationMarker == _scopedDataMarker) {
      return;
    }
    final String scopedKey = _storageKey;
    if (_store.load(scopedKey) != null) {
      await _store.save(_migrationStorageKey, _scopedDataMarker);
      return;
    }
    if (legacyOwnership != LegacyScopeOwnership.provenOwned) return;

    final String? legacy = _store.load(_key);
    if (legacy != null) await _store.save(scopedKey, legacy);
    // The terminal marker is written only after the proven-owner copy (if
    // present) has completed. It preserves legacy bytes while preventing a
    // later scoped delete from making that fallback silently reappear.
    await _store.save(
      _migrationStorageKey,
      LegacyScopeOwnership.provenOwned.name,
    );
  }

  _DecodedNotes _readNotes() {
    final raw = _store.load(_storageKey);
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
      await _prepareScopedStorage();
      final _DecodedNotes decoded = _readNotes();
      _lastReadCorrupted = decoded.corruptRaw != null;
      if (decoded.corruptRaw case final String raw) {
        await _preserveCorruptPayload(raw);
      }
      final List<NoteEntity> notes = decoded.notes.toList(growable: true);
      mutation(notes);
      await _store.save(
        _storageKey,
        jsonEncode(
          notes.map((NoteEntity note) => note.toJson()).toList(growable: false),
        ),
      );
      _lastReadCorrupted = false;
    }, coordinator: _mutationCoordinator);
  }

  Future<void> _preserveCorruptPayload(String raw) async {
    final String? existing = _store.load(_corruptStorageKey);
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
      _corruptStorageKey,
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

  @override
  Future<void> replaceNoteSnapshot(List<NoteEntity> notes) {
    return runAccountStorageMutation(() async {
      await _prepareScopedStorage();
      final _DecodedNotes decoded = _readNotes();
      if (decoded.corruptRaw case final String raw) {
        await _preserveCorruptPayload(raw);
      }
      await _store.save(
        _storageKey,
        jsonEncode(
          notes.map((NoteEntity note) => note.toJson()).toList(growable: false),
        ),
      );
      _lastReadCorrupted = false;
    }, coordinator: _mutationCoordinator);
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
