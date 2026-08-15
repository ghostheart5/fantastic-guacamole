import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class _HiveStore implements HiveStore {
  const _HiveStore();
  @override Box<T> box<T>(String key) => Hive.box<T>(key);
  @override Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();
  @override Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();
  @override Future<void> init() async {}
  @override bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

class _FailingHiveStore implements HiveStore {
  const _FailingHiveStore();
  @override Box<T> box<T>(String key) => throw StateError('injected note read failure');
  @override Future<void> clearBox(String key) async {}
  @override Future<void> closeBox(String key) async {}
  @override Future<void> init() async {}
  @override bool isBoxOpen(String key) => false;
  @override Future<Box<T>> openBox<T>(String key) =>
      Future<Box<T>>.error(StateError('injected note write failure'));
}

const HiveStore _hive = _HiveStore();
final AccountStorageScope _a = AccountStorageScope.authenticated('note-a');
final AccountStorageScope _b = AccountStorageScope.authenticated('note-b');

NoteRepository _notes(AccountStorageScope scope, {HiveStore store = _hive}) =>
    NoteRepository(HiveStorage<String>(
      HiveBoxes.accountScoped(HiveBoxes.notes, scope),
      hive: store,
    ));

NoteEntity _note(String id, String title, {bool archived = false}) => NoteEntity(
      id: id,
      title: title,
      body: '$title body',
      createdAt: DateTime.utc(2026, 8, 15, 10),
      updatedAt: DateTime.utc(2026, 8, 15, 11),
      isArchived: archived,
      goalId: 'goal-$id',
      taskId: 'task-$id',
      habitId: 'habit-$id',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('note-scope-').path));

  group('NoteRepository account-scoped authority', () {
    test('persists, updates, archives, deletes, and restores only its V2 scope', () async {
      final NoteRepository repository = _notes(_a);
      expect(await repository.getNotes(), isEmpty);
      await repository.save(_note('a-1', 'A original'));
      await repository.save(_note('a-1', 'A updated'));
      expect((await repository.getNotes()).single.title, 'A updated');
      await repository.archive('a-1');
      expect(await repository.getNotes(), isEmpty);
      expect((await repository.getNotes(includeArchived: true)).single.isArchived, isTrue);
      await repository.delete('a-1');
      expect(await repository.getNotes(includeArchived: true), isEmpty);
      expect(HiveBoxes.accountScoped(HiveBoxes.notes, _a), 'notes_v2.${_a.v2Namespace}');
    });

    test('isolates identical IDs and retains stale repositories in their original scope', () async {
      final NoteRepository aRepository = _notes(_a);
      final NoteRepository bRepository = _notes(_b);
      await aRepository.save(_note('same-id', 'A_NOTE'));
      expect(await bRepository.getNotes(), isEmpty);
      await bRepository.save(_note('same-id', 'B_NOTE'));
      await aRepository.save(_note('a-only', 'A_ONLY'));
      expect((await aRepository.getNotes()).map((NoteEntity n) => n.title), containsAll(<String>['A_NOTE', 'A_ONLY']));
      expect((await bRepository.getNotes()).single.title, 'B_NOTE');
      await aRepository.delete('same-id');
      expect((await bRepository.getNotes()).single.title, 'B_NOTE');
      expect((await _notes(_a).getNotes()).single.title, 'A_ONLY');
    });

    test('signed-out provider fails closed and never hydrates its derived namespace', () async {
      const AccountStorageScope signedOut = AccountStorageScope.signedOut();
      final HiveStorage<String> derivedStorage = HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.notes, signedOut),
        hive: _hive,
      );
      await derivedStorage.put('forbidden', jsonEncode(_note('forbidden', 'FORBIDDEN')));
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(signedOut),
          hiveStoreProvider.overrideWithValue(_hive),
        ],
      );
      addTearDown(container.dispose);
      final NoteRepository repository = container.read(noteRepositoryProvider);
      await expectLater(
        Future<List<NoteEntity>>.sync(() => repository.getNotes()),
        throwsStateError,
      );
      expect(
        () => repository.save(_note('blocked', 'blocked')),
        throwsStateError,
      );
      expect(derivedStorage.get('forbidden'), contains('FORBIDDEN'));
    });

    test('same-owner reauthentication restores A exactly once without signed-out state', () async {
      final NoteRepository aRepository = _notes(_a);
      await aRepository.save(_note('reauth', 'A_REAUTH_NOTE'));
      await expectLater(
        Future<List<NoteEntity>>.sync(() => NoteRepository.unavailable().getNotes()),
        throwsStateError,
      );
      final List<NoteEntity> restored = await _notes(_a).getNotes();
      expect(restored.where((NoteEntity note) => note.id == 'reauth'), hasLength(1));
      expect(restored.singleWhere((NoteEntity note) => note.id == 'reauth').title, 'A_REAUTH_NOTE');
    });

    test('legacy task-backed note sentinel stays unread and unclaimed', () async {
      final HiveStorage<String> legacyTasks = HiveStorage<String>(HiveBoxes.tasks, hive: _hive);
      await legacyTasks.put('legacy-note', jsonEncode(<String, Object>{
        'id': 'legacy-note', 'title': 'LEGACY_PRIVATE_TASK_NOTE', 'kind': 'note',
      }));
      expect(await _notes(_a).getNotes(includeArchived: true), isNot(contains(predicate<NoteEntity>((NoteEntity n) => n.title == 'LEGACY_PRIVATE_TASK_NOTE'))));
      expect(legacyTasks.get('legacy-note'), contains('LEGACY_PRIVATE_TASK_NOTE'));
    });

    test('read and write failures never fall back to task or legacy state', () async {
      final HiveStorage<String> legacyTasks = HiveStorage<String>(HiveBoxes.tasks, hive: _hive);
      await legacyTasks.put('legacy-failure', '{"title":"LEGACY_PRIVATE_TASK_NOTE"}');
      final NoteRepository failing = _notes(_a, store: const _FailingHiveStore());
      await expectLater(failing.getNotes(), throwsStateError);
      await expectLater(failing.save(_note('write-failure', 'write failure')), throwsStateError);
      expect(legacyTasks.get('legacy-failure'), contains('LEGACY_PRIVATE_TASK_NOTE'));
      final NoteRepository retry = _notes(_a);
      await retry.save(_note('retry', 'retry succeeds'));
      expect((await retry.getNotes()).any((NoteEntity n) => n.id == 'retry'), isTrue);
    });
  });
}
