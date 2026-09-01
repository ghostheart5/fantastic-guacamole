import 'dart:convert';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryPreferences store;
  late KeyedMutationCoordinator coordinator;

  setUp(() {
    store = _MemoryPreferences();
    coordinator = KeyedMutationCoordinator();
  });

  test('serializes concurrent saves across repository instances', () async {
    final NoteRepository first = NoteRepository(
      store,
      mutationCoordinator: coordinator,
    );
    final NoteRepository second = NoteRepository(
      store,
      mutationCoordinator: coordinator,
    );

    await Future.wait(<Future<void>>[
      first.saveNote(_note('note-a')),
      second.saveNote(_note('note-b')),
    ]);

    expect(
      (await first.getNotes()).map((NoteEntity note) => note.id),
      containsAll(<String>['note-a', 'note-b']),
    );
  });

  test('preserves malformed bytes before replacing active Notes', () async {
    const String malformed = '{not-json';
    await store.save('notes_v1', malformed);
    final NoteRepository repository = NoteRepository(
      store,
      mutationCoordinator: coordinator,
    );

    expect(await repository.getNotes(), isEmpty);
    await repository.saveNote(_note('recovered'));

    expect(_recoveryPayloads(store), <String>[malformed]);
    expect((await repository.getNotes()).single.id, 'recovered');
  });

  test(
    'retains a bounded set of distinct corruption recovery copies',
    () async {
      final NoteRepository repository = NoteRepository(
        store,
        mutationCoordinator: coordinator,
      );

      for (int index = 1; index <= 4; index += 1) {
        await store.save('notes_v1', '{corruption-$index');
        await repository.saveNote(_note('recovered-$index'));
      }

      expect(_recoveryPayloads(store), <String>[
        '{corruption-2',
        '{corruption-3',
        '{corruption-4',
      ]);
      expect((await repository.getNotes()).single.id, 'recovered-4');
    },
  );

  test('deletes only the requested note', () async {
    final NoteRepository repository = NoteRepository(
      store,
      mutationCoordinator: coordinator,
    );
    await store.save(
      'notes_v1',
      jsonEncode(<Map<String, dynamic>>[
        _note('keep').toJson(),
        _note('remove').toJson(),
      ]),
    );

    await repository.deleteNote('remove');

    final List<NoteEntity> notes = await repository.getNotes();
    expect(notes.map((NoteEntity note) => note.id), <String>['keep']);
  });
}

NoteEntity _note(String id) {
  return NoteEntity(
    id: id,
    title: 'Note $id',
    createdAt: DateTime.utc(2026, 8, 30, 12),
  );
}

List<String> _recoveryPayloads(_MemoryPreferences store) {
  final Map<String, dynamic> envelope =
      jsonDecode(store.load('notes_v1_corrupt_backup')!)
          as Map<String, dynamic>;
  expect(envelope['schemaVersion'], 1);
  return (envelope['payloads'] as List<dynamic>).cast<String>();
}

class _MemoryPreferences implements SharedPrefsStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    _values[key] = value;
  }

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}
