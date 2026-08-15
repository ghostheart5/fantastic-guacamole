import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/note_si_context_provider.dart';
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

ProviderContainer _container(AccountStorageScope scope) => ProviderContainer(overrides: [
  accountStorageScopeProvider.overrideWithValue(scope),
  hiveStoreProvider.overrideWithValue(const _HiveStore()),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('note-si-context-').path));

  test('SI Note context is read-only, account-local, and excludes archived Notes', () async {
    final ProviderContainer a = _container(AccountStorageScope.authenticated('note-si-a'));
    addTearDown(a.dispose);
    final ProviderSubscription<AsyncValue<List<dynamic>>> aNotes = a.listen(notesProvider, (_, _) {}, fireImmediately: true);
    addTearDown(aNotes.close);
    await a.read(notesProvider.future);
    await a.read(notesProvider.notifier).createNote(title: 'A_CONTEXT_NOTE', body: 'A_BODY');
    final AsyncValue<List<SINoteContext>> aContext = a.read(siNoteContextProvider);
    expect(aContext.value, hasLength(1));
    expect(aContext.value!.single.type, SIContextEntityType.note);
    expect(aContext.value!.single.title, 'A_CONTEXT_NOTE');
    expect(aContext.value!.single.body, 'A_BODY');

    final ProviderContainer b = _container(AccountStorageScope.authenticated('note-si-b'));
    addTearDown(b.dispose);
    final ProviderSubscription<AsyncValue<List<dynamic>>> bNotes = b.listen(notesProvider, (_, _) {}, fireImmediately: true);
    addTearDown(bNotes.close);
    await b.read(notesProvider.future);
    expect(b.read(siNoteContextProvider).value, isEmpty);
    await b.read(notesProvider.notifier).createNote(title: 'B_CONTEXT_NOTE', body: 'B_BODY');
    expect(b.read(siNoteContextProvider).value!.single.title, 'B_CONTEXT_NOTE');
    expect(b.read(siNoteContextProvider).value!.single.title, isNot('A_CONTEXT_NOTE'));

    final String aId = a.read(notesProvider).value!.single.id;
    await a.read(notesProvider.notifier).archiveNote(aId);
    expect(a.read(siNoteContextProvider).value, isEmpty);

    final ProviderContainer signedOut = _container(const AccountStorageScope.signedOut());
    addTearDown(signedOut.dispose);
    final ProviderSubscription<AsyncValue<List<dynamic>>> signedOutNotes = signedOut.listen(notesProvider, (_, _) {}, fireImmediately: true);
    addTearDown(signedOutNotes.close);
    await expectLater(signedOut.read(notesProvider.future), throwsStateError);
    expect(signedOut.read(siNoteContextProvider).value, isNull);
  });
}
