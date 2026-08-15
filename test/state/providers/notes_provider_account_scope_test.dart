import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

const HiveStore _hive = _HiveStore();

ProviderContainer _container(AccountStorageScope scope) => ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(scope),
        hiveStoreProvider.overrideWithValue(_hive),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('notes-provider-').path));

  test('notesProvider is reactive, account-scoped, and fails closed signed-out', () async {
    final ProviderContainer a = _container(AccountStorageScope.authenticated('notes-a'));
    addTearDown(a.dispose);
    final ProviderSubscription<AsyncValue<List<NoteEntity>>> aListener = a.listen(
      notesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(aListener.close);
    expect(await a.read(notesProvider.future), isEmpty);
    await a.read(notesProvider.notifier).createNote(title: 'A_NOTE', body: 'A body');
    final NoteEntity aNote = a.read(notesProvider).value!.single;
    await a.read(notesProvider.notifier).updateNote(aNote.copyWith(title: 'A_EDITED'));
    expect(a.read(notesProvider).value!.single.title, 'A_EDITED');
    await a.read(notesProvider.notifier).archiveNote(aNote.id);
    expect(a.read(notesProvider).value, isEmpty);

    final ProviderContainer b = _container(AccountStorageScope.authenticated('notes-b'));
    addTearDown(b.dispose);
    final ProviderSubscription<AsyncValue<List<NoteEntity>>> bListener = b.listen(
      notesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(bListener.close);
    expect(await b.read(notesProvider.future), isEmpty);

    final ProviderContainer signedOut = _container(const AccountStorageScope.signedOut());
    addTearDown(signedOut.dispose);
    final ProviderSubscription<AsyncValue<List<NoteEntity>>> signedOutListener = signedOut.listen(
      notesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(signedOutListener.close);
    await expectLater(signedOut.read(notesProvider.future), throwsStateError);
  });
}
